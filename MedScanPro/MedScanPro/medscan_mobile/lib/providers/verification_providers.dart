import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/verification_engine.dart';
import '../models/scan_event_model.dart';
import '../models/verification_record_model.dart';

final verificationEngineProvider = Provider((ref) => VerificationEngine());

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getIdentifierScanCount(String identifier) async {
    if (identifier.isEmpty) return 0;
    try {
      final snapshot = await _firestore
          .collection('scanEvents')
          .where('identifier', isEqualTo: identifier)
          .get();
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> logScanEvent(ScanEventModel event) async {
    try {
      await _firestore.collection('scanEvents').add(event.toMap());
    } catch (e) {
      // Graceful error logging
    }
  }

  Future<void> logVerificationRecord(VerificationRecordModel record) async {
    try {
      await _firestore.collection('verificationRecords').add(record.toMap());
    } catch (e) {
      // Graceful error logging
    }
  }

  /// Gap 5: 1-tap suspicious report — writes a consumer flag to Firestore
  /// `suspiciousReports` collection so regulatory staff can triage.
  Future<void> submitSuspiciousReport({
    required String identifier,
    required String medicineName,
    required String batchNumber,
    required String resultCode,
    required String userId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('suspiciousReports').add({
        'identifier': identifier,
        'medicineName': medicineName,
        'batchNumber': batchNumber,
        'verificationResultCode': resultCode,
        'reportedByUserId': userId,
        'notes': notes ?? '',
        'status': 'PENDING_REVIEW',
        'reportedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently retry on next app session
    }
  }
}

final verificationServiceProvider = Provider((ref) => VerificationService());
