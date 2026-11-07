import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_medication_model.dart';
import '../models/prescription_model.dart';
import '../models/reminder_model.dart';
import '../services/notification_service.dart';
import '../services/clinical_service.dart';
import '../services/storage_service.dart';
import 'auth_providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.init();
  return service;
});

final clinicalServiceProvider = Provider((ref) => ClinicalService());

final myMedicationsProvider = StreamProvider<List<UserMedicationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('userMedications')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => UserMedicationModel.fromMap(doc.data(), doc.id))
            .toList(),
      );
});

final userPrescriptionsProvider = StreamProvider<List<PrescriptionModel>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('prescriptions')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        return list;
      });
});

class MedicationRepository {
  final FirebaseFirestore? _firestoreInstance;
  final Set<String> _savedPrescriptionIds = <String>{};

  MedicationRepository([FirebaseFirestore? firestore])
    : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  Future<String> addMedication(UserMedicationModel med, {String? docId}) async {
    if (med.userId.trim().isEmpty) {
      throw StateError('Authenticated userId is required to save medications.');
    }
    if (docId != null && docId.trim().isNotEmpty) {
      await _firestore
          .collection('userMedications')
          .doc(docId.trim())
          .set(med.toMap());
      return docId.trim();
    }
    final ref = await _firestore.collection('userMedications').add(med.toMap());
    return ref.id;
  }

  /// Saves a user-confirmed prescription record to the authenticated user's history.
  /// - Rejects unconfirmed records (`isConfirmedByUser == false`).
  /// - Prevents duplicate saves on repeated taps/retries via deterministic `p.id`.
  Future<bool> addPrescription(PrescriptionModel p) async {
    if (p.userId.trim().isEmpty) {
      throw StateError(
        'Authenticated userId is required to save a prescription.',
      );
    }
    if (!p.isConfirmedByUser) {
      throw StateError(
        'Raw or unconfirmed prescription output cannot be saved to history.',
      );
    }

    final docId = p.id.trim();
    if (docId.isNotEmpty) {
      if (_savedPrescriptionIds.contains(docId)) {
        return false; // Already saved in this session; prevent duplicate write
      }
      await _firestore.collection('prescriptions').doc(docId).set(p.toMap());
      _savedPrescriptionIds.add(docId);
      return true;
    } else {
      await _firestore.collection('prescriptions').add(p.toMap());
      return true;
    }
  }

  /// Deletes a saved prescription record (and its stored original image/PDF) for the owner user.
  Future<void> deletePrescription(
    PrescriptionModel p, {
    required String currentUserId,
    StorageService? storageService,
  }) async {
    if (currentUserId.trim().isEmpty || p.userId != currentUserId) {
      throw StateError(
        'Unauthorized: Cannot delete another user\'s prescription.',
      );
    }
    if (p.imagePath.trim().isNotEmpty) {
      await (storageService ?? StorageService()).deletePrescriptionFile(
        p.imagePath,
      );
    }
    await _firestore.collection('prescriptions').doc(p.id).delete();
    _savedPrescriptionIds.remove(p.id);
  }

  /// Removes only the stored prescription image/PDF while keeping the confirmed text record.
  Future<void> removePrescriptionOriginalFile(
    PrescriptionModel p, {
    required String currentUserId,
    StorageService? storageService,
  }) async {
    if (currentUserId.trim().isEmpty || p.userId != currentUserId) {
      throw StateError(
        'Unauthorized: Cannot modify another user\'s prescription.',
      );
    }
    if (p.imagePath.trim().isNotEmpty) {
      await (storageService ?? StorageService()).deletePrescriptionFile(
        p.imagePath,
      );
    }
    await _firestore.collection('prescriptions').doc(p.id).update({
      'imagePath': '',
    });
  }

  Future<void> addReminder(ReminderModel r, {String? docId}) async {
    if (r.userId.trim().isEmpty) {
      throw StateError('Authenticated userId is required to save a reminder.');
    }
    if (docId != null && docId.trim().isNotEmpty) {
      await _firestore.collection('reminders').doc(docId.trim()).set(r.toMap());
      return;
    }
    await _firestore.collection('reminders').add(r.toMap());
  }

  Future<void> updateMedicationReminders(
    String medId,
    List<String> reminderTimes,
  ) async {
    await _firestore.collection('userMedications').doc(medId).update({
      'reminderTimes': reminderTimes,
    });
  }

  Future<void> deleteMedication(String medId) async {
    await _firestore.collection('userMedications').doc(medId).delete();
  }
}

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => MedicationRepository(),
);
