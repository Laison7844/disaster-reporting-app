import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendToControlRoomAndContacts(String message) async {
    try {
      // 1️⃣ Send to Control Room collection
      await _firestore.collection('control_room_messages').add({
        'message': message,
        'timestamp': Timestamp.now(),
      });

      // 2️⃣ Get emergency contacts
      final contactsSnapshot = await _firestore
          .collection('emergency_contacts')
          .get();

      for (var doc in contactsSnapshot.docs) {
        await _firestore.collection('contact_messages').add({
          'contact1': doc['contact1'],
          'contact2': doc['contact2'],
          'contact3': doc['contact3'],
          'message': message,
          'timestamp': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Error sending emergency messages: $e');
      rethrow;
    }
  }

  Future<void> triggerSos() async {
    try {
      await _firestore.collection('sos_alerts').add({
        'message': 'SOS Triggered',
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error triggering SOS: $e');
      rethrow;
    }
  }
}
