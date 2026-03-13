import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.fcmToken,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String fcmToken;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final dynamic created = map['createdAt'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : (created is DateTime ? created : DateTime.now());

    return AppUser(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      fcmToken: map['fcmToken'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}
