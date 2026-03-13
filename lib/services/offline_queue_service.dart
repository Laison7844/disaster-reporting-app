import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/queued_action.dart';

class OfflineQueueService {
  OfflineQueueService._();

  static final OfflineQueueService instance = OfflineQueueService._();

  static const String _queueKey = 'offline_report_queue';

  Future<List<QueuedAction>> loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? <String>[];

    return raw
        .map(
          (item) =>
              QueuedAction.fromMap(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> enqueue(QueuedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_queueKey) ?? <String>[];
    existing.add(jsonEncode(action.toMap()));
    await prefs.setStringList(_queueKey, existing);
  }

  Future<void> removeAction(String id) async {
    final queue = await loadQueue();
    queue.removeWhere((item) => item.id == id);
    await _saveQueue(queue);
  }

  Future<void> _saveQueue(List<QueuedAction> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final data = queue.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList(_queueKey, data);
  }
}
