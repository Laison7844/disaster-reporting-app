import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyReport {
  const EmergencyReport({
    required this.id,
    required this.userId,
    required this.reporterName,
    required this.description,
    required this.imageUrl,
    required this.audioUrl,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String userId;
  final String reporterName;
  final String description;
  final String imageUrl;
  final String audioUrl;
  final double latitude;
  final double longitude;
  final String severity;
  final String status;
  final DateTime createdAt;
  final String type;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'reporterName': reporterName,
      'description': description,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
    };
  }

  factory EmergencyReport.fromMap(Map<String, dynamic> map) {
    final dynamic created = map['createdAt'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : (created is DateTime ? created : DateTime.now());

    return EmergencyReport(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      severity: map['severity'] as String? ?? 'GREEN',
      status: map['status'] as String? ?? 'submitted',
      createdAt: createdAt,
      type: map['type'] as String? ?? 'INCIDENT',
    );
  }
}
