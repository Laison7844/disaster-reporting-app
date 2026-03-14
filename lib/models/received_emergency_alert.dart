import 'package:cloud_firestore/cloud_firestore.dart';

class ReceivedEmergencyAlert {
  const ReceivedEmergencyAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.navigationTarget,
    required this.createdAt,
    this.reportId = '',
    this.reporterName = '',
    this.severity = '',
    this.imageUrl = '',
    this.audioUrl = '',
    this.latitude,
    this.longitude,
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
  final double? latitude;
  final double? longitude;
  final String navigationTarget;
  final DateTime createdAt;

  bool get hasLocation => latitude != null && longitude != null;

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
      'latitude': latitude,
      'longitude': longitude,
      'navigationTarget': navigationTarget,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReceivedEmergencyAlert.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    final rawCreatedAt = map['createdAt'];

    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else {
      createdAt =
          DateTime.tryParse((rawCreatedAt ?? '').toString()) ?? DateTime.now();
    }

    return ReceivedEmergencyAlert(
      id: (map['id'] ?? '').toString(),
      reportId: (map['reportId'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      reporterName: (map['reporterName'] ?? '').toString(),
      severity: (map['severity'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      audioUrl: (map['audioUrl'] ?? '').toString(),
      latitude: _asDoubleOrNull(map['latitude']),
      longitude: _asDoubleOrNull(map['longitude']),
      navigationTarget: (map['navigationTarget'] ?? 'emergency_alert')
          .toString(),
      createdAt: createdAt,
    );
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse((value ?? '').toString());
    return parsed;
  }
}
