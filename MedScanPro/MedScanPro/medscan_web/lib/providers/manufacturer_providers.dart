import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/manufacturer_repository.dart';
import '../services/cloudinary_service.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_model.dart';
import '../services/operational_database_service.dart';
import 'auth_providers.dart';

final manufacturerRepositoryProvider = Provider<ManufacturerRepository>((ref) => ManufacturerRepository());
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());

// Strict isolated stream: ONLY the current manufacturer's medicines
final medicinesProvider = StreamProvider<List<MedicineModel>>((ref) {
  final fbUser = ref.watch(authStateProvider).value;
  final uid = OperationalDatabaseService.instance.currentSession?.uid ?? fbUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(manufacturerRepositoryProvider).getMedicines(uid);
});

// Strict isolated stream: ONLY the current manufacturer's batches
final batchesProvider = StreamProvider<List<BatchModel>>((ref) {
  final fbUser = ref.watch(authStateProvider).value;
  final uid = OperationalDatabaseService.instance.currentSession?.uid ?? fbUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(manufacturerRepositoryProvider).getBatches(uid);
});

// Strict isolated stream: ONLY the current manufacturer's packaging references
final packagingReferencesProvider = StreamProvider<List<PackagingModel>>((ref) {
  final fbUser = ref.watch(authStateProvider).value;
  final uid = OperationalDatabaseService.instance.currentSession?.uid ?? fbUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(manufacturerRepositoryProvider).getPackagingReferences(uid);
});

// Public Consumer Streams: All approved medicines & batches across all pharmaceutical companies
final allPublicMedicinesProvider = StreamProvider<List<MedicineModel>>((ref) {
  return ref.watch(manufacturerRepositoryProvider).getAllPublicMedicines();
});

final allPublicBatchesProvider = StreamProvider<List<BatchModel>>((ref) {
  return ref.watch(manufacturerRepositoryProvider).getAllPublicBatches();
});
