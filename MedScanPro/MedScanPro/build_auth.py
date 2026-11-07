import os

def create_files(base_path, file_map):
    for filepath, content in file_map.items():
        full_path = os.path.join(base_path, filepath)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content.strip() + '\n')

auth_files = {
    "models/user_model.dart": """
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'consumer',
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
""",
    "core/exceptions/auth_exceptions.dart": """
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'invalid-email':
        return AuthException('The email address is badly formatted.');
      case 'user-disabled':
        return AuthException('Your account has been disabled. Please contact support.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException('Invalid email or password.');
      case 'email-already-in-use':
        return AuthException('An account already exists for that email.');
      case 'operation-not-allowed':
        return AuthException('Email/password accounts are not enabled.');
      case 'weak-password':
        return AuthException('The password provided is too weak.');
      case 'network-request-failed':
        return AuthException('Network error. Please check your connection.');
      case 'permission-denied':
        return AuthException('You do not have permission to perform this action.');
      default:
        return AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  String toString() => message;
}
""",
    "services/auth_service.dart": """
import 'package:firebase_auth/firebase_auth.dart';
import '../core/exceptions/auth_exceptions.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      if (credential.user != null && !credential.user!.emailVerified) {
        throw AuthException('Please verify your email address before logging in.');
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } catch (e) {
      throw AuthException('An unexpected error occurred.');
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } catch (e) {
      throw AuthException('An unexpected error occurred.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } catch (e) {
      throw AuthException('An unexpected error occurred.');
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
""",
    "repositories/user_repository.dart": """
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
""",
    "repositories/auth_repository.dart": """
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
    final credential = await _authService.signInWithEmailAndPassword(email, password);
    final userProfile = await _userRepository.getUserProfile(credential.user!.uid);
    
    if (userProfile == null) {
      throw Exception('User profile not found.');
    }
    
    if (userProfile.status == 'disabled') {
      await _authService.signOut();
      throw Exception('Your account has been disabled. Please contact support.');
    }
    
    return userProfile;
  }

  Future<void> register(String name, String email, String password, String role) async {
    final credential = await _authService.registerWithEmailAndPassword(email, password);
    
    final userModel = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _userRepository.createUserProfile(userModel);
    // Optionally log out if you require email verification before proceeding
    await _authService.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    await _authService.signOut();
  }
}
""",
    "providers/auth_providers.dart": """
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../repositories/user_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthRepository(authService, userRepository);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return await ref.watch(userRepositoryProvider).getUserProfile(user.uid);
});

final roleProvider = Provider<AsyncValue<String?>>((ref) {
  final userProfile = ref.watch(currentUserProvider);
  return userProfile.whenData((user) => user?.role);
});
"""
}

# Apply to Mobile
mobile_base = r"d:\medscan\MedScanPro\medscan_mobile\lib"
create_files(mobile_base, auth_files)

# Apply to Web
web_base = r"d:\medscan\MedScanPro\medscan_web\lib"
create_files(web_base, auth_files)

print("Auth Core generated successfully.")
