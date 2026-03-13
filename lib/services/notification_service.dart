import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase/firebase_constants.dart';
import '../screens/emergency_details_page.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _sosChannelId = 'sos_alerts_alarm_channel';
  static const String _sosChannelName = 'SOS Alerts';
  static const String _sosChannelDescription =
      'Emergency SOS alerts from trusted contacts.';
  static const String _incidentChannelId = 'incident_alerts_channel';
  static const String _incidentChannelName = 'Incident Alerts';
  static const String _incidentChannelDescription =
      'Normal incident report notifications.';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;

  GlobalKey<NavigatorState>? _navigatorKey;
  _EmergencyNavigationData? _pendingNavigation;

  bool _initialized = false;
  bool _navigationConfigured = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Permission.notification.request();
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _initializeLocalNotifications();

    _initialized = true;
  }

  Future<void> configureNotificationNavigation({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    await initialize();

    _navigatorKey = navigatorKey;

    if (!_navigationConfigured) {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      _navigationConfigured = true;
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _flushPendingNavigation();
  }

  Future<String?> getFcmToken() async {
    await initialize();
    return _messaging.getToken();
  }

  Future<void> subscribeToAdminAlerts() async {
    await initialize();
    await _messaging.subscribeToTopic(FirebaseTopics.adminAlerts);
  }

  Future<void> unsubscribeFromAdminAlerts() async {
    await initialize();
    await _messaging.unsubscribeFromTopic(FirebaseTopics.adminAlerts);
  }

  Future<void> watchTokenRefresh(String userId) async {
    await initialize();
    await cancelTokenRefresh();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _firestore.collection(FirebaseCollections.users).doc(userId).set({
        'id': userId,
        'fcmToken': token,
      }, SetOptions(merge: true));
    });
  }

  Future<void> cancelTokenRefresh() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  void _handleForegroundMessage(RemoteMessage remoteMessage) {
    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      unawaited(
        _showAndroidForegroundNotification(
          remoteMessage: remoteMessage,
          navigationData: navigationData,
        ),
      );
      return;
    }

    _pushEmergencyPage(navigationData);
  }

  void _handleNotificationTap(RemoteMessage remoteMessage) {
    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    _pushEmergencyPage(navigationData);
  }

  void _pushEmergencyPage(_EmergencyNavigationData navigationData) {
    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      _pendingNavigation = navigationData;
      return;
    }

    navigatorState.push(
      MaterialPageRoute(
        builder: (_) => EmergencyDetailsPage(
          message: navigationData.message,
          reporterName: navigationData.reporterName,
          severity: navigationData.severity,
          lat: navigationData.lat,
          lng: navigationData.lng,
          imageUrl: navigationData.imageUrl,
          audioUrl: navigationData.audioUrl,
        ),
      ),
    );
  }

  void _flushPendingNavigation() {
    final pending = _pendingNavigation;
    if (pending == null) {
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushPendingNavigation();
      });
      return;
    }

    _pendingNavigation = null;
    _pushEmergencyPage(pending);
  }

  _EmergencyNavigationData? _extractNavigationData(
    RemoteMessage remoteMessage,
  ) {
    final data = remoteMessage.data;
    if (data.isEmpty) {
      return null;
    }

    final type = (data['type'] ?? '').toString().toLowerCase();
    if (type.isNotEmpty &&
        type != 'emergency' &&
        type != 'sos' &&
        type != 'incident') {
      return null;
    }

    final message =
        (data['message'] ??
                remoteMessage.notification?.body ??
                'Emergency reported')
            .toString();
    final latValue = data['lat'] ?? data['latitude'];
    final lngValue = data['lng'] ?? data['longitude'];
    final lat = double.tryParse((latValue ?? '').toString());
    final lng = double.tryParse((lngValue ?? '').toString());

    if (lat == null || lng == null) {
      return null;
    }

    return _EmergencyNavigationData(
      type: type.isEmpty ? 'sos' : type,
      message: message,
      lat: lat,
      lng: lng,
      reporterName: (data['reporterName'] ?? '').toString(),
      severity: (data['severity'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
    );
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundLocalNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _sosChannelId,
        _sosChannelName,
        description: _sosChannelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('emergency_alarm'),
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _incidentChannelId,
        _incidentChannelName,
        description: _incidentChannelDescription,
        importance: Importance.max,
      ),
    );
  }

  Future<void> _showAndroidForegroundNotification({
    required RemoteMessage remoteMessage,
    required _EmergencyNavigationData navigationData,
  }) async {
    final notification = remoteMessage.notification;
    final isSos = navigationData.type == 'sos';
    final fallbackTitle = isSos
        ? '🚨 Emergency SOS Alert'
        : 'Incident Report Alert';

    await _localNotifications.show(
      navigationData.hashCode,
      notification?.title ?? fallbackTitle,
      navigationData.message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isSos ? _sosChannelId : _incidentChannelId,
          isSos ? _sosChannelName : _incidentChannelName,
          channelDescription: isSos
              ? _sosChannelDescription
              : _incidentChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: isSos
              ? const RawResourceAndroidNotificationSound('emergency_alarm')
              : null,
        ),
      ),
      payload: jsonEncode(<String, dynamic>{
        'type': navigationData.type,
        'message': navigationData.message,
        'lat': navigationData.lat,
        'lng': navigationData.lng,
        'reporterName': navigationData.reporterName,
        'severity': navigationData.severity,
        'imageUrl': navigationData.imageUrl,
        'audioUrl': navigationData.audioUrl,
      }),
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final navigationData = _extractNavigationDataFromPayload(payload);
    if (navigationData == null) {
      return;
    }

    _pushEmergencyPage(navigationData);
  }

  _EmergencyNavigationData? _extractNavigationDataFromPayload(String payload) {
    final decodedPayload = jsonDecode(payload);
    if (decodedPayload is! Map) {
      return null;
    }

    final message = (decodedPayload['message'] ?? '').toString();
    final lat = double.tryParse((decodedPayload['lat'] ?? '').toString());
    final lng = double.tryParse((decodedPayload['lng'] ?? '').toString());
    if (message.isEmpty || lat == null || lng == null) {
      return null;
    }

    return _EmergencyNavigationData(
      type: (decodedPayload['type'] ?? '').toString(),
      message: message,
      lat: lat,
      lng: lng,
      reporterName: (decodedPayload['reporterName'] ?? '').toString(),
      severity: (decodedPayload['severity'] ?? '').toString(),
      imageUrl: (decodedPayload['imageUrl'] ?? '').toString(),
      audioUrl: (decodedPayload['audioUrl'] ?? '').toString(),
    );
  }
}

@pragma('vm:entry-point')
void _handleBackgroundLocalNotificationResponse(NotificationResponse response) {
  NotificationService.instance._handleLocalNotificationResponse(response);
}

class _EmergencyNavigationData {
  const _EmergencyNavigationData({
    required this.type,
    required this.message,
    required this.lat,
    required this.lng,
    this.reporterName = '',
    this.severity = '',
    this.imageUrl = '',
    this.audioUrl = '',
  });

  final String type;
  final String message;
  final double lat;
  final double lng;
  final String reporterName;
  final String severity;
  final String imageUrl;
  final String audioUrl;
}
