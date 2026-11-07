import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/exceptions/auth_exceptions.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException('You do not have permission to perform this action.');
      }
      throw AuthException('Failed to create user profile.');
    } catch (e) {
      throw AuthException('An unexpected error occurred.');
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException('You do not have permission to perform this action.');
      }
      throw AuthException('Failed to fetch user profile.');
    } catch (e) {
      throw AuthException('An unexpected error occurred.');
    }
  }
}
