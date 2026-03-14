import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/received_emergency_alert.dart';

class EmergencyAlertsService {
  EmergencyAlertsService._();

  static final EmergencyAlertsService instance = EmergencyAlertsService._();

  static const String _storageKey = 'received_emergency_alerts';
  static const int _maxStoredAlerts = 100;

  final ValueNotifier<List<ReceivedEmergencyAlert>> alertsNotifier =
      ValueNotifier<List<ReceivedEmergencyAlert>>(<ReceivedEmergencyAlert>[]);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);
    if (rawValue == null || rawValue.isEmpty) {
      _initialized = true;
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        final alerts =
            decoded
                .whereType<Map>()
                .map(
                  (item) => ReceivedEmergencyAlert.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        alertsNotifier.value = List<ReceivedEmergencyAlert>.unmodifiable(
          alerts,
        );
      }
    } catch (_) {
      alertsNotifier.value = const <ReceivedEmergencyAlert>[];
    }

    _initialized = true;
  }

  Future<void> saveAlert(ReceivedEmergencyAlert alert) async {
    await initialize();

    final alerts = <ReceivedEmergencyAlert>[...alertsNotifier.value];
    final existingIndex = alerts.indexWhere((item) => item.id == alert.id);
    if (existingIndex >= 0) {
      alerts[existingIndex] = alert;
    } else {
      alerts.insert(0, alert);
    }

    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = alerts.take(_maxStoredAlerts).toList();
    alertsNotifier.value = List<ReceivedEmergencyAlert>.unmodifiable(trimmed);
    await _persist(trimmed);
  }

  Future<void> clearAlerts() async {
    await initialize();
    alertsNotifier.value = const <ReceivedEmergencyAlert>[];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persist(List<ReceivedEmergencyAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(alerts.map((alert) => alert.toMap()).toList()),
    );
  }
}
