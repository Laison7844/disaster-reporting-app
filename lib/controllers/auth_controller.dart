import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser(UserModel user) async {
    try {
      await _firestore.collection('users').add(user.toMap());
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }
}
