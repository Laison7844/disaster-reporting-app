enum QueuedActionType { sos, incident }

class QueuedAction {
  const QueuedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final QueuedActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QueuedAction.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? QueuedActionType.incident.name;
    final matchedType = QueuedActionType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => QueuedActionType.incident,
    );

    return QueuedAction(
      id: map['id'] as String? ?? '',
      type: matchedType,
      payload: Map<String, dynamic>.from(
        map['payload'] as Map? ?? <String, dynamic>{},
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
