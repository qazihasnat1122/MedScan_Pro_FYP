import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../models/suspicious_report_model.dart';
import '../models/medicine_reaction_report_model.dart';
import '../models/verification_record_model.dart';
import '../models/emergency_profile_model.dart';
import 'auth_providers.dart';

// ALERTS
final alertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('alerts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => AlertModel(
                id: d.id,
                title: d['title'] ?? '',
                message: d['message'] ?? '',
                level: d['level'] ?? 'INFO',
                createdAt: d['createdAt'] != null
                    ? DateTime.parse(d['createdAt'])
                    : DateTime.now(),
              ),
            )
            .toList(),
      )
      .handleError((_) => <AlertModel>[]);
});

// HISTORY
final verificationHistoryProvider =
    StreamProvider<List<VerificationRecordModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection('verificationRecords')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => VerificationRecordModel(
                    id: d.id,
                    userId: d['userId'] ?? '',
                    medicineName: d['medicineName'] ?? '',
                    riskLevel: d['riskLevel'] ?? 'UNKNOWN',
                    verifiedAt: d['verifiedAt'] != null
                        ? DateTime.parse(d['verifiedAt'])
                        : DateTime.now(),
                  ),
                )
                .toList(),
          );
    });

// USER SUSPICIOUS PACKAGING REPORTS
final userReportsProvider = StreamProvider<List<SuspiciousReportModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('suspiciousReports')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map(
        (s) => s.docs.map((d) {
          final data = d.data();
          return SuspiciousReportModel(
            id: d.id,
            userId: data['userId'] ?? '',
            medicineName: data['medicineName'] ?? '',
            batchNumber: data['batchNumber'] ?? '',
            localPhotoPaths: List<String>.from(data['localPhotoPaths'] ?? []),
            reason: data['reason'] ?? '',
            purchaseInfo: data['purchaseInfo'] ?? '',
            status: data['status'] ?? 'Submitted',
            submittedAt: data['submittedAt'] != null
                ? DateTime.parse(data['submittedAt'])
                : DateTime.now(),
          );
        }).toList(),
      );
});

// USER ADVERSE REACTION REPORTS
final userReactionReportsProvider =
    StreamProvider<List<MedicineReactionReportModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection('reactionReports')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => MedicineReactionReportModel.fromMap(d.data(), d.id))
                .toList(),
          )
          .handleError((_) => <MedicineReactionReportModel>[]);
    });

// EMERGENCY PROFILE
final emergencyProfileProvider =
    StreamProvider<EmergencyProfileModel?>((ref) async* {
  final user = ref.watch(authStateProvider).value;
  final safetyService = ref.watch(safetyServiceProvider);

  // 1. Instantly yield local cached profile if available (offline-first & instant startup)
  final localCached = await safetyService.getLocalEmergencyProfile(user?.uid);
  if (localCached != null) {
    yield localCached;
  }

  if (user == null) {
    if (localCached == null) {
      yield null;
    }
    return;
  }

  // 2. Stream from Firestore if available, auto-updating local cache
  try {
    final stream = FirebaseFirestore.instance
        .collection('emergencyProfiles')
        .doc(user.uid)
        .snapshots()
        .map((d) {
          if (!d.exists || d.data() == null) return null;
          final model = EmergencyProfileModel.fromMap(d.data()!);
          safetyService.saveLocalCacheOnly(model);
          return model;
        });

    await for (final remoteModel in stream) {
      yield remoteModel ?? localCached;
    }
  } catch (_) {
    if (localCached != null) {
      yield localCached;
    }
  }
});

class SafetyService {
  final FirebaseFirestore? _customFirestore;
  SafetyService([this._customFirestore]);
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  static const String _prefKeyPrefix = 'emergency_profile_cache_';
  static const String _lastProfileKey = 'emergency_profile_cache_last';

  Future<void> submitReport(SuspiciousReportModel report) async {
    await _firestore.collection('suspiciousReports').add(report.toMap());
  }

  Future<void> submitReactionReport(MedicineReactionReportModel report) async {
    await _firestore.collection('reactionReports').add(report.toMap());
  }

  Future<void> updateReactionReport(MedicineReactionReportModel report) async {
    await _firestore
        .collection('reactionReports')
        .doc(report.id)
        .update(report.toMap());
  }

  Future<void> deleteReactionReport(String reportId) async {
    await _firestore.collection('reactionReports').doc(reportId).delete();
  }

  /// Spam & Duplicate Protection: Checks whether a user already submitted a reaction report
  /// for the same medicine in the last 24 hours.
  Future<bool> hasRecentReactionReport({
    required String userId,
    required String medicineName,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('reactionReports')
          .where('userId', isEqualTo: userId)
          .where('medicineName', isEqualTo: medicineName.trim())
          .get()
          .timeout(const Duration(seconds: 4));

      for (final doc in snapshot.docs) {
        final submittedAtStr = doc.data()['submittedAt'] as String?;
        if (submittedAtStr != null) {
          final dt = DateTime.tryParse(submittedAtStr);
          if (dt != null && dt.isAfter(cutoff)) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Saves the emergency profile with immediate local persistence for reliable
  /// offline availability, followed by remote Firestore synchronization.
  Future<void> saveEmergencyProfile(EmergencyProfileModel profile) async {
    await saveLocalCacheOnly(profile);
    try {
      await _firestore
          .collection('emergencyProfiles')
          .doc(profile.userId)
          .set(profile.toMap());
    } catch (_) {
      // Local copy is preserved safely
    }
  }

  /// Persists profile strictly to local SharedPreferences.
  Future<void> saveLocalCacheOnly(EmergencyProfileModel profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(profile.toMap());
      await prefs.setString('$_prefKeyPrefix${profile.userId}', jsonStr);
      await prefs.setString(_lastProfileKey, jsonStr);
    } catch (_) {}
  }

  /// Retrieves cached emergency profile locally for offline reliability.
  Future<EmergencyProfileModel?> getLocalEmergencyProfile([String? userId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr;
      if (userId != null && userId.isNotEmpty) {
        jsonStr = prefs.getString('$_prefKeyPrefix$userId');
      }
      jsonStr ??= prefs.getString(_lastProfileKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return EmergencyProfileModel.fromMap(data);
      }
    } catch (_) {}
    return null;
  }
}

final safetyServiceProvider = Provider((ref) => SafetyService());
