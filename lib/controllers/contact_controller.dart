import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact_model.dart';

class ContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveEmergencyContacts(EmergencyContactModel contacts) async {
    try {
      await _firestore.collection('emergency_contacts').add(contacts.toMap());
    } catch (e) {
      print('Error saving emergency contacts: $e');
      rethrow;
    }
  }
}
