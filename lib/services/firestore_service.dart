import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_constants.dart';
import 'notification_service.dart';

class FirestoreAuthException implements Exception {
  const FirestoreAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  static const String _sessionUserIdKey = 'session_user_id';
  static const String _sessionNameKey = 'session_name';
  static const String _sessionEmailKey = 'session_email';
  static const String _sessionMobileKey = 'session_mobile';
  static const String _sessionAdminKey = 'session_is_admin';

  static const String adminUsername = 'admin';
  static const String adminPassword = 'qwerty123';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _currentName;
  String? _currentEmail;
  String? _currentMobile;
  bool _isAdminLoggedIn = false;

  String? get currentUserId => _currentUserId;
  String? get currentName => _currentName;
  String? get currentEmail => _currentEmail;
  String? get currentMobile => _currentMobile;
  bool get isLoggedIn => _currentUserId != null;
  bool get isAdminLoggedIn => _isAdminLoggedIn;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_sessionUserIdKey);
    _currentName = prefs.getString(_sessionNameKey);
    _currentEmail = prefs.getString(_sessionEmailKey);
    _currentMobile = prefs.getString(_sessionMobileKey);
    _isAdminLoggedIn = prefs.getBool(_sessionAdminKey) ?? false;

    if (_currentUserId != null && !_isAdminLoggedIn) {
      await NotificationService.instance.unsubscribeFromAdminAlerts();
      final token = await NotificationService.instance.getFcmToken();
      if (token != null) {
        await _firestore
            .collection(FirebaseCollections.users)
            .doc(_currentUserId)
            .set({
              'id': _currentUserId,
              'fcmToken': token,
            }, SetOptions(merge: true));
      }

      await NotificationService.instance.watchTokenRefresh(_currentUserId!);
    } else {
      await NotificationService.instance.cancelTokenRefresh();
      if (_isAdminLoggedIn) {
        await NotificationService.instance.subscribeToAdminAlerts();
      }
    }
  }

  Future<void> registerUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw const FirestoreAuthException(
        'Account already exists with this email',
      );
    }

    final userRef = _firestore.collection('users').doc();
    final token = await NotificationService.instance.getFcmToken();

    await userRef.set({
      'id': userRef.id,
      'name': name.trim(),
      'email': normalizedEmail,
      'mobile': mobile.trim(),
      'password': password,
      'emergencyContacts': {'contact1': '', 'contact2': '', 'contact3': ''},
      'fcmToken': token ?? '',
      'createdAt': Timestamp.now(),
    });

    _currentUserId = userRef.id;
    _currentName = name.trim();
    _currentEmail = normalizedEmail;
    _currentMobile = mobile.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, _currentUserId!);
    await prefs.setString(_sessionNameKey, _currentName ?? '');
    await prefs.setString(_sessionEmailKey, _currentEmail ?? '');
    await prefs.setString(_sessionMobileKey, _currentMobile ?? '');
    await prefs.setBool(_sessionAdminKey, false);
    _isAdminLoggedIn = false;

    await NotificationService.instance.unsubscribeFromAdminAlerts();
    await NotificationService.instance.watchTokenRefresh(_currentUserId!);
  }

  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw const FirestoreAuthException('No account found with this email');
    }

    final userData = snapshot.docs.first.data();
    final storedPassword = (userData['password'] ?? '').toString();

    if (storedPassword != password) {
      throw const FirestoreAuthException('Incorrect password');
    }

    _currentUserId = (userData['id'] ?? snapshot.docs.first.id).toString();
    _currentName = (userData['name'] ?? '').toString();
    _currentEmail = (userData['email'] ?? '').toString();
    _currentMobile = (userData['mobile'] ?? '').toString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, _currentUserId!);
    await prefs.setString(_sessionNameKey, _currentName ?? '');
    await prefs.setString(_sessionEmailKey, _currentEmail ?? '');
    await prefs.setString(_sessionMobileKey, _currentMobile ?? '');
    await prefs.setBool(_sessionAdminKey, false);
    _isAdminLoggedIn = false;

    await NotificationService.instance.unsubscribeFromAdminAlerts();
    final token = await NotificationService.instance.getFcmToken();
    if (token != null) {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(_currentUserId)
          .set({
            'id': _currentUserId,
            'fcmToken': token,
          }, SetOptions(merge: true));
    }

    await NotificationService.instance.watchTokenRefresh(_currentUserId!);
  }

  Future<void> loginAdmin({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (normalizedUsername != adminUsername || password != adminPassword) {
      throw const FirestoreAuthException('Invalid admin credentials');
    }

    await NotificationService.instance.cancelTokenRefresh();
    await NotificationService.instance.subscribeToAdminAlerts();

    _currentUserId = null;
    _currentName = 'Admin';
    _currentEmail = adminUsername;
    _currentMobile = null;
    _isAdminLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionMobileKey);
    await prefs.setString(_sessionNameKey, _currentName!);
    await prefs.setString(_sessionEmailKey, _currentEmail!);
    await prefs.setBool(_sessionAdminKey, true);
  }

  Future<void> logout() async {
    await NotificationService.instance.cancelTokenRefresh();
    await NotificationService.instance.unsubscribeFromAdminAlerts();

    _currentUserId = null;
    _currentName = null;
    _currentEmail = null;
    _currentMobile = null;
    _isAdminLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionNameKey);
    await prefs.remove(_sessionEmailKey);
    await prefs.remove(_sessionMobileKey);
    await prefs.remove(_sessionAdminKey);
  }

  Future<List<String>> getEmergencyContacts() async {
    final userId = _currentUserId;
    if (userId == null) {
      return <String>[];
    }

    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();
    if (data == null) {
      return <String>[];
    }

    final emergencyContacts = data['emergencyContacts'];
    if (emergencyContacts is! Map) {
      return <String>[];
    }

    final contact1 = (emergencyContacts['contact1'] ?? '').toString().trim();
    final contact2 = (emergencyContacts['contact2'] ?? '').toString().trim();
    final contact3 = (emergencyContacts['contact3'] ?? '').toString().trim();

    return <String>[
      if (contact1.isNotEmpty) contact1,
      if (contact2.isNotEmpty) contact2,
      if (contact3.isNotEmpty) contact3,
    ];
  }

  Future<void> saveEmergencyContacts({
    String? contact1,
    String? contact2,
    String? contact3,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw const FirestoreAuthException('Please login first');
    }

    final first = (contact1 ?? '').trim();
    final second = (contact2 ?? '').trim();
    final third = (contact3 ?? '').trim();

    final contacts = <String>[
      if (first.isNotEmpty) first,
      if (second.isNotEmpty) second,
      if (third.isNotEmpty) third,
    ];

    if (contacts.isEmpty) {
      throw const FirestoreAuthException(
        'Please add at least one emergency contact number.',
      );
    }

    for (final mobile in contacts) {
      if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
        throw const FirestoreAuthException(
          'Enter a valid 10 digit mobile number',
        );
      }
    }

    for (final mobile in contacts) {
      final isRegistered = await _isRegisteredUserMobile(mobile);
      if (!isRegistered) {
        throw const FirestoreAuthException(
          'This number is not registered in the app.',
        );
      }
    }

    await _firestore.collection('users').doc(userId).set({
      'emergencyContacts': {
        'contact1': first,
        'contact2': second,
        'contact3': third,
      },
    }, SetOptions(merge: true));
  }

  Future<bool> _isRegisteredUserMobile(String mobile) async {
    final snapshot = await _firestore
        .collection('users')
        .where('mobile', isEqualTo: mobile)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
