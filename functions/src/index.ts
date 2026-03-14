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
const EMERGENCY_CHANNEL_ID = 'emergency_channel';
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
    const adminTokens = await getAdminFcmTokens();
    const filteredContactTokens = contactTokens.filter(
      (token) => !adminTokens.includes(token),
    );
    const contactPayload = buildContactPayload(reportId, report, reporter, type);
    const adminPayload = buildAdminPayload(reportId, report, reporter, type);

    let contactResponse:
      | admin.messaging.BatchResponse
      | { successCount: number; failureCount: number; responses: Array<{ success: boolean }> } = {
          successCount: 0,
          failureCount: 0,
          responses: [],
        };

    if (filteredContactTokens.length > 0) {
      contactResponse = await messaging.sendEachForMulticast({
        tokens: filteredContactTokens,
        data: contactPayload.data,
        android: buildAndroidConfig(),
        apns: buildApnsConfig(),
      });
    } else {
      logger.info('No matching contact tokens found for report.', {
        reportId,
        userId,
        type,
        contactMobiles,
      });
    }

    await messaging.send({
      topic: ADMIN_ALERTS_TOPIC,
      data: adminPayload.data,
      android: buildAndroidConfig(),
      apns: buildApnsConfig(),
    });

    const failedTokens = filteredContactTokens.filter(
      (_, index) => !contactResponse.responses[index]?.success,
    );

    await firestore.collection(NOTIFICATION_LOGS_COLLECTION).add({
      reportId,
      userId,
      reportType: type,
      contactMobiles,
      tokens: filteredContactTokens,
      failedTokens,
      successCount: contactResponse.successCount,
      failureCount: contactResponse.failureCount,
      adminAlertSent: true,
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

async function getAdminFcmTokens(): Promise<string[]> {
  const adminSnapshot = await firestore
    .collection(USERS_COLLECTION)
    .where('role', '==', 'admin')
    .get();

  const tokens = new Set<string>();
  for (const doc of adminSnapshot.docs) {
    const token = (doc.get('fcmToken') ?? '').toString().trim();
    if (token.length > 0) {
      tokens.add(token);
    }
  }

  return Array.from(tokens);
}

function buildContactPayload(
  reportId: string,
  report: FirestoreMap,
  reporter: FirestoreMap,
  type: ReportType,
): {
  title: string;
  body: string;
  data: Record<string, string>;
} {
  const reporterName = resolveReporterName(report, reporter);
  const description = resolveDescription(report, type);
  const severity = (report.severity ?? '').toString().trim();
  const tag = (report.tag ?? '').toString().trim();
  const lat = stringifyValue(report.latitude);
  const lng = stringifyValue(report.longitude);
  const imageUrl = (report.imageUrl ?? '').toString();
  const audioUrl = (report.audioUrl ?? '').toString();
  const createdAt = new Date().toISOString();

  const title = type === 'SOS' ? '🚨 Emergency SOS Alert' : '🚨 Incident Report Alert';
  const body =
    type === 'SOS'
      ? 'Your contact has triggered an SOS alert. Tap to view location.'
      : 'Your contact has submitted an incident report. Tap to view details.';

  return {
    title,
    body,
    data: {
      alertId: reportId,
      reportId,
      type: type === 'SOS' ? 'sos' : 'incident',
      navigationTarget: 'emergency_alert',
      title,
      message: description,
      description,
      reporterName,
      severity,
      tag,
      lat,
      lng,
      imageUrl,
      audioUrl,
      createdAt,
    },
  };
}

function buildAdminPayload(
  reportId: string,
  report: FirestoreMap,
  reporter: FirestoreMap,
  type: ReportType,
): {
  title: string;
  body: string;
  data: Record<string, string>;
} {
  const reporterName = resolveReporterName(report, reporter);
  const description = resolveDescription(report, type);
  const severity = (report.severity ?? '').toString().trim();
  const tag = (report.tag ?? '').toString().trim();
  const lat = stringifyValue(report.latitude);
  const lng = stringifyValue(report.longitude);
  const imageUrl = (report.imageUrl ?? '').toString();
  const audioUrl = (report.audioUrl ?? '').toString();
  const createdAt = new Date().toISOString();

  const title = type === 'SOS' ? '🚨 Emergency SOS Alert' : '🚨 Incident Report Alert';
  const body =
    type === 'SOS'
      ? `${reporterName} triggered an SOS alert. Tap to review the report.`
      : `${reporterName} submitted an incident report. Tap to review details.`;

  return {
    title,
    body,
    data: {
      alertId: `admin_${reportId}`,
      reportId,
      type: type === 'SOS' ? 'sos' : 'incident',
      navigationTarget: 'admin_report',
      title,
      message: description,
      description,
      reporterName,
      severity,
      tag,
      lat,
      lng,
      imageUrl,
      audioUrl,
      createdAt,
    },
  };
}

function resolveReporterName(report: FirestoreMap, reporter: FirestoreMap): string {
  return (
    (report.reporterName ?? reporter.name ?? 'Your contact').toString().trim() ||
    'Your contact'
  );
}

function resolveDescription(report: FirestoreMap, type: ReportType): string {
  const description = (report.description ?? report.message ?? '').toString().trim();
  if (description.length > 0) {
    return description;
  }

  return type === 'SOS'
    ? 'Your contact has triggered an SOS alert.'
    : 'A new incident report has been submitted.';
}

function buildAndroidConfig(): admin.messaging.AndroidConfig {
  return {
    priority: 'high',
    ttl: 60 * 60 * 1000,
    // notification: {
    //   channelId: EMERGENCY_CHANNEL_ID,
    //   sound: 'emergency_alarm',
    //   defaultVibrateTimings: true,
    // },
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

function buildApnsConfig(): admin.messaging.ApnsConfig {
  return {
    payload: {
      aps: {
        sound: 'emergency_alarm.mp3',
      },
    },
  };
}
