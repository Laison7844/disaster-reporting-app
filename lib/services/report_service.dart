import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_constants.dart';
import '../models/emergency_report.dart';
import '../models/queued_action.dart';
import '../models/submission_result.dart';
import 'firestore_service.dart';
import 'location_service.dart';
import 'offline_queue_service.dart';
import 'storage_service.dart';

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  Timer? _syncTimer;
  bool _isSyncInProgress = false;

  void startAutoSync() {
    _syncTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => syncPendingQueue(),
    );
  }

  Future<SubmissionResult> createSosReport() async {
    final userId = FirestoreService.instance.currentUserId;
    if (userId == null) {
      throw Exception('Please log in before triggering SOS.');
    }

    await _ensureEmergencyContactsExist(userId);

    final position = await _locationService.getCurrentPosition();
    final reportId = _firestore
        .collection(FirebaseCollections.reports)
        .doc()
        .id;
    final payload = <String, dynamic>{
      'reportId': reportId,
      'userId': userId,
      'message': 'SOS triggered. Immediate assistance needed.',
      'description': 'SOS emergency triggered from quick emergency bell.',
      'severity': 'RED',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'sos_triggered',
      'type': 'SOS',
      'imagePath': '',
      'audioPath': '',
    };

    final online = await _hasInternetConnection();
    if (!online) {
      await _queueAction(type: QueuedActionType.sos, payload: payload);
      return const SubmissionResult(
        wasQueued: true,
        message:
            'Internet unavailable. Report will be sent when connection returns.',
      );
    }

    try {
      await _submitSos(payload);
      return const SubmissionResult(
        wasQueued: false,
        message: 'SOS report submitted successfully.',
      );
    } catch (_) {
      await _queueAction(type: QueuedActionType.sos, payload: payload);
      return const SubmissionResult(
        wasQueued: true,
        message:
            'Internet unavailable. Report will be sent when connection returns.',
      );
    }
  }

  Future<SubmissionResult> createIncidentReport({
    required String description,
    required String severity,
    File? imageFile,
    File? audioFile,
  }) async {
    final userId = FirestoreService.instance.currentUserId;
    if (userId == null) {
      throw Exception('Please log in before reporting an incident.');
    }

    await _ensureEmergencyContactsExist(userId);

    // ignore: avoid_print
    print('STEP 1: Getting location');
    final position = await (() async {
      try {
        return await _locationService.getCurrentPosition().timeout(
          const Duration(seconds: 10),
        );
      } on TimeoutException {
        throw Exception('Location request timed out. Please try again.');
      }
    })();
    final payload = <String, dynamic>{
      'userId': userId,
      'description': description.trim(),
      'severity': severity,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'submitted',
      'type': 'INCIDENT',
      'imagePath': imageFile?.path ?? '',
      'audioPath': audioFile?.path ?? '',
    };

    final online = await _hasInternetConnection();
    if (!online) {
      await _queueAction(type: QueuedActionType.incident, payload: payload);
      return const SubmissionResult(
        wasQueued: true,
        message:
            'Internet unavailable. Report will be sent when connection returns.',
      );
    }

    await _submitIncident(payload);
    return const SubmissionResult(
      wasQueued: false,
      message: 'Incident report submitted successfully.',
    );
  }

  Stream<List<EmergencyReport>> watchCurrentUserReports() {
    final userId = FirestoreService.instance.currentUserId;
    if (userId == null) {
      return const Stream<List<EmergencyReport>>.empty();
    }

    return _firestore
        .collection(FirebaseCollections.reports)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map((doc) => EmergencyReport.fromMap(doc.data()))
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        });
  }

  Future<void> syncPendingQueue() async {
    if (_isSyncInProgress) {
      return;
    }

    final online = await _hasInternetConnection();
    if (!online) {
      return;
    }

    _isSyncInProgress = true;

    try {
      final queuedActions = await OfflineQueueService.instance.loadQueue();
      for (final action in queuedActions) {
        try {
          if (action.type == QueuedActionType.sos) {
            await _submitSos(action.payload);
          } else {
            await _submitIncident(action.payload);
          }
          await OfflineQueueService.instance.removeAction(action.id);
        } catch (_) {
          // Keep failed item in queue and continue with others.
        }
      }
    } finally {
      _isSyncInProgress = false;
    }
  }

  Future<void> _queueAction({
    required QueuedActionType type,
    required Map<String, dynamic> payload,
  }) async {
    final action = QueuedAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.name}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await OfflineQueueService.instance.enqueue(action);
  }

  Future<void> _submitSos(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as String? ?? '';
    if (userId.isEmpty) {
      throw Exception('Missing user id for SOS report.');
    }

    final latitude = _asDouble(payload['latitude']);
    final longitude = _asDouble(payload['longitude']);
    final message = (payload['message'] as String? ?? '').trim().isEmpty
        ? 'SOS triggered. Immediate assistance needed.'
        : (payload['message'] as String? ?? '').trim();
    final reporterName = await _getReporterName(userId);

    final reportId = payload['reportId'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
        DateTime.now();
    final resolvedReportId = reportId.isEmpty
        ? _firestore.collection(FirebaseCollections.reports).doc().id
        : reportId;

    await _firestore
        .collection(FirebaseCollections.reports)
        .doc(resolvedReportId)
        .set({
          'id': resolvedReportId,
          'userId': userId,
          'reporterName': reporterName,
          'type': 'SOS',
          'latitude': latitude,
          'longitude': longitude,
          'message': message,
          // Keep existing fields for compatibility with the report list UI.
          'description': payload['description'] as String? ?? message,
          'imageUrl': '',
          'audioUrl': '',
          'severity': payload['severity'] as String? ?? 'RED',
          'status': payload['status'] as String? ?? 'sos_triggered',
          'createdAt': Timestamp.fromDate(createdAt),
        });
  }

  Future<void> _submitIncident(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as String? ?? '';
    if (userId.isEmpty) {
      throw Exception('Missing user id for incident report.');
    }

    String imageUrl = '';
    String audioUrl = '';

    final imagePath = payload['imagePath'] as String? ?? '';
    final audioPath = payload['audioPath'] as String? ?? '';

    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        imageUrl = imagePath;
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          try {
            // ignore: avoid_print
            print('STEP 2: Uploading image');
            imageUrl = await StorageService.instance
                .uploadFile(
                  file: file,
                  folder: 'reports/images',
                  userId: userId,
                  compressImage: true,
                )
                .timeout(const Duration(seconds: 20));
          } on TimeoutException {
            throw Exception('Image upload timed out. Please try again.');
          } on FirebaseException catch (error) {
            throw Exception(_mapUploadError(error));
          } on FileSystemException {
            throw Exception('Upload failure. Please try again.');
          }
        }
      }
    }

    if (audioPath.isNotEmpty) {
      if (audioPath.startsWith('http')) {
        audioUrl = audioPath;
      } else {
        final file = File(audioPath);
        if (await file.exists()) {
          try {
            // ignore: avoid_print
            print('STEP 3: Uploading audio');
            audioUrl = await StorageService.instance
                .uploadFile(file: file, folder: 'reports/audio', userId: userId)
                .timeout(const Duration(seconds: 20));
          } on TimeoutException {
            throw Exception('Audio upload timed out. Please try again.');
          } on FirebaseException catch (error) {
            throw Exception(_mapUploadError(error));
          } on FileSystemException {
            throw Exception('Upload failure. Please try again.');
          }
        }
      }
    }

    final reportId = _firestore
        .collection(FirebaseCollections.reports)
        .doc()
        .id;
    final createdAt =
        DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
        DateTime.now();
    final reporterName = await _getReporterName(userId);

    final report = EmergencyReport(
      id: reportId,
      userId: userId,
      reporterName: reporterName,
      description: payload['description'] as String? ?? '',
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      latitude: _asDouble(payload['latitude']),
      longitude: _asDouble(payload['longitude']),
      severity: payload['severity'] as String? ?? 'GREEN',
      status: payload['status'] as String? ?? 'submitted',
      createdAt: createdAt,
      type: payload['type'] as String? ?? 'INCIDENT',
    );

    try {
      // ignore: avoid_print
      print('STEP 4: Saving report');
      await _firestore
          .collection(FirebaseCollections.reports)
          .doc(report.id)
          .set(report.toMap());
    } on FirebaseException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('network') || code.contains('unavailable')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      }
      throw Exception('Firestore save failure. Please try again.');
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'firebase.google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<List<String>> _getEmergencyContactMobiles(String userId) async {
    final snapshot = await _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .get();
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

    return <String>{
      if (contact1.isNotEmpty) contact1,
      if (contact2.isNotEmpty) contact2,
      if (contact3.isNotEmpty) contact3,
    }.toList();
  }

  Future<void> _ensureEmergencyContactsExist(String userId) async {
    final contactMobiles = await _getEmergencyContactMobiles(userId);
    if (contactMobiles.isEmpty) {
      throw Exception(
        'You must add at least one emergency contact before using emergency features.',
      );
    }
  }

  Future<String> _getReporterName(String userId) async {
    final cachedName = FirestoreService.instance.currentName?.trim() ?? '';
    if (cachedName.isNotEmpty) {
      return cachedName;
    }

    final snapshot = await _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .get();
    return (snapshot.data()?['name'] ?? '').toString().trim();
  }

  String _mapUploadError(FirebaseException error) {
    final code = error.code.toLowerCase();
    if (code.contains('network') || code.contains('unavailable')) {
      return 'Network error. Please check your internet connection.';
    }
    return 'Upload failure. Please try again.';
  }
}
