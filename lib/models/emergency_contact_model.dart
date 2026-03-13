import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContactModel {
  final String contact1;
  final String contact2;
  final String contact3;
  final Timestamp createdAt;

  EmergencyContactModel({
    required this.contact1,
    required this.contact2,
    required this.contact3,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'contact1': contact1,
      'contact2': contact2,
      'contact3': contact3,
      'createdAt': createdAt,
    };
  }

  factory EmergencyContactModel.fromMap(Map<String, dynamic> map) {
    return EmergencyContactModel(
      contact1: map['contact1'] ?? '',
      contact2: map['contact2'] ?? '',
      contact3: map['contact3'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }
}
