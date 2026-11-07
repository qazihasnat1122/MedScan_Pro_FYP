import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../repositories/user_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

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
  return await ref.read(userRepositoryProvider).getUserProfile(user.uid);
});

final roleProvider = Provider<String?>((ref) {
  final userProfile = ref.watch(currentUserProvider);
  return userProfile.value?.role;
});
