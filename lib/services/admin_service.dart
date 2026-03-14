import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_constants.dart';

class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> deleteReport(String reportId) async {
    await _firestore
        .collection(FirebaseCollections.reports)
        .doc(reportId)
        .delete();
  }
}
