import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

const firestore = admin.firestore();
const messaging = admin.messaging();

const USERS_COLLECTION = 'users';
const REPORTS_COLLECTION = 'reports';
const NOTIFICATION_LOGS_COLLECTION = 'notification_logs';
const ADMIN_ALERTS_TOPIC = 'admin_alerts';
const SOS_CHANNEL_ID = 'sos_alerts_alarm_channel';
const INCIDENT_CHANNEL_ID = 'incident_alerts_channel';
const MAX_WHERE_IN_VALUES = 10;

type FirestoreMap = Record<string, unknown>;
type ReportType = 'SOS' | 'INCIDENT';

export const sendReportNotifications = onDocumentCreated(
  `${REPORTS_COLLECTION}/{reportId}`,
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('Missing Firestore snapshot for report trigger.', {
        reportId: event.params.reportId,
      });
      return;
    }

    const report = snapshot.data() as FirestoreMap;
    const type = normalizeReportType(report.type);
    if (!type) {
      return;
    }

    const reportId = event.params.reportId;
    const userId = (report.userId ?? '').toString().trim();
    if (userId.length === 0) {
      logger.warn('Report missing userId.', { reportId, type });
      return;
    }

    const userSnapshot = await firestore.collection(USERS_COLLECTION).doc(userId).get();
    if (!userSnapshot.exists) {
      logger.warn('Reporter not found.', { reportId, userId, type });
      return;
    }

    const reporter = userSnapshot.data() as FirestoreMap;
    const contactMobiles = extractEmergencyContactMobiles(reporter);
    const contactTokens = await getFcmTokensForMobiles(contactMobiles);
    const payload = buildNotificationPayload(report, reporter, type);

    let multicastResponse:
      | admin.messaging.BatchResponse
      | { successCount: number; failureCount: number; responses: Array<{ success: boolean }> } = {
          successCount: 0,
          failureCount: 0,
          responses: [],
        };

    if (contactTokens.length > 0) {
      multicastResponse = await messaging.sendEachForMulticast({
        tokens: contactTokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: buildAndroidConfig(type),
        apns: buildApnsConfig(type),
      });
    } else {
      logger.info('No matching contact tokens found for report.', {
        reportId,
        userId,
        type,
        contactMobiles,
      });
    }

    let adminAlertSent = false;
    if (type === 'SOS') {
      await messaging.send({
        topic: ADMIN_ALERTS_TOPIC,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: buildAndroidConfig(type),
        apns: buildApnsConfig(type),
      });
      adminAlertSent = true;
    }

    const failedTokens = contactTokens.filter(
      (_, index) => !multicastResponse.responses[index]?.success,
    );

    await firestore.collection(NOTIFICATION_LOGS_COLLECTION).add({
      reportId,
      userId,
      reportType: type,
      contactMobiles,
      tokens: contactTokens,
      failedTokens,
      successCount: multicastResponse.successCount,
      failureCount: multicastResponse.failureCount,
      adminAlertSent,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

function normalizeReportType(value: unknown): ReportType | null {
  const normalized = (value ?? '').toString().trim().toUpperCase();
  if (normalized === 'SOS' || normalized === 'INCIDENT') {
    return normalized;
  }
  return null;
}

function extractEmergencyContactMobiles(userData: FirestoreMap | undefined): string[] {
  if (!userData) {
    return [];
  }

  const emergencyContacts = userData.emergencyContacts;
  if (!emergencyContacts || typeof emergencyContacts !== 'object') {
    return [];
  }

  const contacts = emergencyContacts as FirestoreMap;
  return Array.from(
    new Set(
      ['contact1', 'contact2', 'contact3']
        .map((key) => (contacts[key] ?? '').toString().trim())
        .filter((mobile) => mobile.length > 0),
    ),
  );
}

async function getFcmTokensForMobiles(mobiles: string[]): Promise<string[]> {
  if (mobiles.length === 0) {
    return [];
  }

  const uniqueTokens = new Set<string>();
  for (let index = 0; index < mobiles.length; index += MAX_WHERE_IN_VALUES) {
    const chunk = mobiles.slice(index, index + MAX_WHERE_IN_VALUES);
    const usersSnapshot = await firestore
      .collection(USERS_COLLECTION)
      .where('mobile', 'in', chunk)
      .get();

    for (const userDocument of usersSnapshot.docs) {
      const token = (userDocument.get('fcmToken') ?? '').toString().trim();
      if (token.length > 0) {
        uniqueTokens.add(token);
      }
    }
  }

  return Array.from(uniqueTokens);
}

function buildNotificationPayload(
  report: FirestoreMap,
  reporter: FirestoreMap,
  type: ReportType,
): {
  title: string;
  body: string;
  data: Record<string, string>;
} {
  const reporterName =
    (report.reporterName ?? reporter.name ?? 'Your contact').toString().trim() ||
    'Your contact';
  const description = (report.description ?? report.message ?? '').toString().trim();
  const severity = (report.severity ?? '').toString().trim();
  const lat = stringifyValue(report.latitude);
  const lng = stringifyValue(report.longitude);
  const imageUrl = (report.imageUrl ?? '').toString();
  const audioUrl = (report.audioUrl ?? '').toString();

  if (type === 'SOS') {
    return {
      title: '🚨 Emergency SOS Alert',
      body: `${reporterName} has triggered an SOS alert. Tap to view location.`,
      data: {
        type: 'sos',
        message: `${reporterName} needs immediate help.`,
        reporterName,
        lat,
        lng,
        description,
        imageUrl,
        audioUrl,
      },
    };
  }

  return {
    title: 'Incident Report Alert',
    body: `${reporterName} submitted a ${severity.toLowerCase()} incident report.`,
    data: {
      type: 'incident',
      message: description.length === 0 ? 'A new incident has been reported.' : description,
      reporterName,
      lat,
      lng,
      description,
      severity,
      imageUrl,
      audioUrl,
    },
  };
}

function buildAndroidConfig(type: ReportType): admin.messaging.AndroidConfig {
  if (type === 'SOS') {
    return {
      priority: 'high',
      notification: {
        channelId: SOS_CHANNEL_ID,
        sound: 'emergency_alarm',
      },
    };
  }

  return {
    priority: 'high',
    notification: {
      channelId: INCIDENT_CHANNEL_ID,
    },
  };
}

function buildApnsConfig(type: ReportType): admin.messaging.ApnsConfig | undefined {
  if (type !== 'SOS') {
    return undefined;
  }

  return {
    payload: {
      aps: {
        sound: 'emergency_alarm.wav',
      },
    },
  };
}

function stringifyValue(value: unknown): string {
  if (typeof value === 'number') {
    return value.toString();
  }

  if (typeof value === 'string') {
    return value;
  }

  return '';
}
