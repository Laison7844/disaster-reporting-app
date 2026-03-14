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
import '../models/received_emergency_alert.dart';
import '../screens/emergency_details_page.dart';
import '../screens/report_details_screen.dart';
import 'emergency_alerts_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _emergencyChannelId = 'emergency_channel_v3';
  static const String _emergencyChannelName = 'Emergency Alerts';
  static const String _emergencyChannelDescription =
      'High-priority emergency alerts with alarm sound.';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;

  GlobalKey<NavigatorState>? _navigatorKey;
  _NotificationRouteData? _pendingNavigation;

  bool _initialized = false;
  bool _navigationConfigured = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _messaging.setAutoInitEnabled(true);
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
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('FCM TOKEN: $token');
    }
    await EmergencyAlertsService.instance.initialize();
    await _initializeLocalNotifications();

    _initialized = true;
  }

  Future<void> configureNotificationNavigation({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    await initialize();
    _navigatorKey = navigatorKey;

    if (!_navigationConfigured) {
      FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_handleForegroundMessage(message)),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_handleNotificationTap(message)),
      );
      _navigationConfigured = true;
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage, preferPending: true);
    }

    flushPendingNavigation();
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
      await subscribeToAdminAlerts();
    });
  }

  Future<void> cancelTokenRefresh() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> persistIncomingAlert(RemoteMessage remoteMessage) async {
    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    await _persistAlertIfNeeded(navigationData);
  }

  Future<void> handleBackgroundMessage(RemoteMessage remoteMessage) async {
    await persistIncomingAlert(remoteMessage);
    await _showAndroidBackgroundNotification(remoteMessage);
  }

  void flushPendingNavigation() {
    final pending = _pendingNavigation;
    if (pending == null) {
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        flushPendingNavigation();
      });
      return;
    }

    _pendingNavigation = null;
    _pushDestination(pending);
  }

  Future<void> _handleForegroundMessage(RemoteMessage remoteMessage) async {
    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    await _persistAlertIfNeeded(navigationData);

    if (!kIsWeb && Platform.isAndroid) {
      await _showAndroidForegroundNotification(
        remoteMessage: remoteMessage,
        navigationData: navigationData,
      );
      return;
    }

    _pushDestination(navigationData);
  }

  Future<void> _handleNotificationTap(
    RemoteMessage remoteMessage, {
    bool preferPending = false,
  }) async {
    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    await _persistAlertIfNeeded(navigationData);
    _queueOrPush(navigationData, preferPending: preferPending);
  }

  void _queueOrPush(
    _NotificationRouteData navigationData, {
    bool preferPending = false,
  }) {
    final navigatorState = _navigatorKey?.currentState;
    if (preferPending || navigatorState == null) {
      _pendingNavigation = navigationData;
      return;
    }

    _pushDestination(navigationData);
  }

  void _pushDestination(_NotificationRouteData navigationData) {
    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      _pendingNavigation = navigationData;
      return;
    }

    if (navigationData.navigationTarget == 'admin_report' &&
        navigationData.reportId.isNotEmpty) {
      navigatorState.push(
        MaterialPageRoute(
          builder: (_) => ReportDetailsScreen.fromReportId(
            reportId: navigationData.reportId,
            title: 'Admin Report Details',
          ),
        ),
      );
      return;
    }

    navigatorState.push(
      MaterialPageRoute(
        builder: (_) => EmergencyDetailsPage(
          message: navigationData.description,
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

  _NotificationRouteData? _extractNavigationData(RemoteMessage remoteMessage) {
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

    final title =
        (data['title'] ??
                remoteMessage.notification?.title ??
                'Emergency Alert')
            .toString();
    final description =
        (data['description'] ??
                data['message'] ??
                remoteMessage.notification?.body ??
                'Emergency reported')
            .toString();

    return _NotificationRouteData(
      id: _resolveAlertId(data),
      reportId: (data['reportId'] ?? '').toString(),
      type: type.isEmpty ? 'sos' : type,
      title: title,
      description: description,
      reporterName: (data['reporterName'] ?? '').toString(),
      severity: (data['severity'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      lat: _parseDoubleOrNull(data['lat'] ?? data['latitude']),
      lng: _parseDoubleOrNull(data['lng'] ?? data['longitude']),
      navigationTarget: (data['navigationTarget'] ?? 'emergency_alert')
          .toString(),
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  String _resolveAlertId(Map<String, dynamic> data) {
    final explicitId = (data['alertId'] ?? '').toString().trim();
    if (explicitId.isNotEmpty) {
      return explicitId;
    }

    final reportId = (data['reportId'] ?? '').toString().trim();
    if (reportId.isNotEmpty) {
      return reportId;
    }

    final type = (data['type'] ?? '').toString().trim();
    final message = (data['message'] ?? data['description'] ?? '')
        .toString()
        .trim();
    final createdAt = (data['createdAt'] ?? '').toString().trim();
    return '${type}_${message.hashCode}_$createdAt';
  }

  double? _parseDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse((value ?? '').toString());
  }

  Future<void> _persistAlertIfNeeded(
    _NotificationRouteData navigationData,
  ) async {
    if (navigationData.navigationTarget == 'admin_report') {
      return;
    }

    await EmergencyAlertsService.instance.saveAlert(
      ReceivedEmergencyAlert(
        id: navigationData.id,
        reportId: navigationData.reportId,
        type: navigationData.type,
        title: navigationData.title,
        description: navigationData.description,
        reporterName: navigationData.reporterName,
        severity: navigationData.severity,
        imageUrl: navigationData.imageUrl,
        audioUrl: navigationData.audioUrl,
        latitude: navigationData.lat,
        longitude: navigationData.lng,
        navigationTarget: navigationData.navigationTarget,
        createdAt: navigationData.createdAt,
      ),
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

    await _createAndroidChannel(_localNotifications);
  }

  Future<void> _showAndroidForegroundNotification({
    required RemoteMessage remoteMessage,
    required _NotificationRouteData navigationData,
  }) async {
    final notification = remoteMessage.notification;

    await _createAndroidChannel(_localNotifications);
    await _localNotifications.show(
      navigationData.id.hashCode,
      notification?.title ?? navigationData.title,
      notification?.body ?? navigationData.description,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _emergencyChannelId,
          _emergencyChannelName,
          channelDescription: _emergencyChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      payload: jsonEncode(navigationData.toMap()),
    );
  }

  Future<void> _showAndroidBackgroundNotification(
    RemoteMessage remoteMessage,
  ) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    if (remoteMessage.notification != null) {
      return;
    }

    final navigationData = _extractNavigationData(remoteMessage);
    if (navigationData == null) {
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundLocalNotificationResponse,
    );

    await _createAndroidChannel(plugin);

    await plugin.show(
      navigationData.id.hashCode,
      navigationData.title,
      navigationData.description,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _emergencyChannelId,
          _emergencyChannelName,
          channelDescription: _emergencyChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      payload: jsonEncode(navigationData.toMap()),
    );
  }

  Future<void> _createAndroidChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        description: _emergencyChannelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('emergency_alarm'),
      ),
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

    unawaited(_persistAlertIfNeeded(navigationData));
    _pushDestination(navigationData);
  }

  _NotificationRouteData? _extractNavigationDataFromPayload(String payload) {
    final decodedPayload = jsonDecode(payload);
    if (decodedPayload is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(decodedPayload);
    return _NotificationRouteData(
      id: (data['id'] ?? '').toString(),
      reportId: (data['reportId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      reporterName: (data['reporterName'] ?? '').toString(),
      severity: (data['severity'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      lat: _parseDoubleOrNull(data['lat']),
      lng: _parseDoubleOrNull(data['lng']),
      navigationTarget: (data['navigationTarget'] ?? 'emergency_alert')
          .toString(),
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

@pragma('vm:entry-point')
void _handleBackgroundLocalNotificationResponse(NotificationResponse response) {
  NotificationService.instance._handleLocalNotificationResponse(response);
}

class _NotificationRouteData {
  const _NotificationRouteData({
    required this.id,
    required this.reportId,
    required this.type,
    required this.title,
    required this.description,
    required this.reporterName,
    required this.severity,
    required this.imageUrl,
    required this.audioUrl,
    required this.navigationTarget,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  final String id;
  final String reportId;
  final String type;
  final String title;
  final String description;
  final String reporterName;
  final String severity;
  final String imageUrl;
  final String audioUrl;
  final double? lat;
  final double? lng;
  final String navigationTarget;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'type': type,
      'title': title,
      'description': description,
      'reporterName': reporterName,
      'severity': severity,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'lat': lat,
      'lng': lng,
      'navigationTarget': navigationTarget,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
