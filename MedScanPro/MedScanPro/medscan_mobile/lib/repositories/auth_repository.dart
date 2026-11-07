import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'user_repository.dart';

class AuthRepository {
  final AuthService _authService;
  final UserRepository _userRepository;

  AuthRepository(this._authService, this._userRepository);

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<UserModel> login(String email, String password) async {
    final credential = await _authService.signInWithEmailAndPassword(
      email,
      password,
    );
    final uid = credential.user!.uid;
    var userProfile = await _userRepository.getUserProfile(uid);

    // Auto-create profile if missing
    if (userProfile == null) {
      userProfile = UserModel(
        uid: uid,
        name: credential.user!.displayName ?? email.split('@').first,
        email: email,
        role: 'consumer',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _userRepository.createUserProfile(userProfile);
    }

    if (userProfile.status == 'disabled') {
      await _authService.signOut();
      throw Exception(
        'Your account has been disabled. Please contact support.',
      );
    }

    return userProfile;
  }

  Future<UserModel> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final credential = await _authService.registerWithEmailAndPassword(
      email,
      password,
    );
    final uid = credential.user!.uid;

    final userModel = UserModel(
      uid: uid,
      name: name.isNotEmpty ? name : email.split('@').first,
      email: email,
      role: role.isNotEmpty ? role : 'consumer',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userRepository.createUserProfile(userModel);
    return userModel;
  }

  Future<UserModel> demoLogin() async {
    final credential = await _authService.signInAnonymously();
    final uid = credential.user!.uid;
    var profile = await _userRepository.getUserProfile(uid);
    if (profile == null) {
      profile = UserModel(
        uid: uid,
        name: 'Demo Consumer',
        email: 'demo@medscan.app',
        role: 'consumer',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _userRepository.createUserProfile(profile);
    }
    return profile;
  }

  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    await _authService.signOut();
  }
}
