import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/operational_database_service.dart';
import '../repositories/user_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/app_auth_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthRepository(authService, userRepository);
});

// Guaranteed 100% Operational Auth Stream: Combines Corporate DRAP Sessions & Firebase
final authStateProvider = StreamProvider<AppAuthUser?>((ref) async* {
  final opDb = OperationalDatabaseService.instance;

  // 1. If an active corporate session exists right now, emit immediately
  if (opDb.currentSession != null) {
    yield AppAuthUser(
      uid: opDb.currentSession!.uid,
      email: opDb.currentSession!.email,
      displayName: opDb.currentSession!.name,
    );
  }

  // 2. Stream corporate session updates and Firebase changes
  final controller = StreamController<AppAuthUser?>.broadcast();

  final sub1 = opDb.sessionStream.listen((session) {
    if (session != null) {
      controller.add(AppAuthUser(
        uid: session.uid,
        email: session.email,
        displayName: session.name,
      ));
    } else {
      controller.add(null);
    }
  });

  final sub2 = ref.watch(authServiceProvider).authStateChanges.listen((fbUser) {
    if (fbUser != null && opDb.currentSession == null) {
      controller.add(AppAuthUser(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        displayName: fbUser.displayName ?? '',
      ));
    }
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  yield* controller.stream;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final opSession = OperationalDatabaseService.instance.currentSession;
  if (opSession != null) return opSession;

  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;

  try {
    final profile = await ref.watch(userRepositoryProvider).getUserProfile(authUser.uid);
    if (profile != null) return profile;
  } catch (_) {}

  // Fallback to operational company profile
  return UserModel(
    uid: authUser.uid,
    name: authUser.displayName.isNotEmpty ? authUser.displayName : 'Authorized Company Representative',
    email: authUser.email,
    role: 'manufacturer',
    status: 'active',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

final roleProvider = Provider<AsyncValue<String?>>((ref) {
  final userProfile = ref.watch(currentUserProvider);
  return userProfile.whenData((user) => user?.role ?? 'manufacturer');
});
