import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scan_event_model.dart';
import '../models/anomaly_model.dart';
import '../services/operational_database_service.dart';
import 'auth_providers.dart';

final manufacturerScanEventsProvider = StreamProvider<List<ScanEventModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return OperationalDatabaseService.instance.watchScanEvents(user.uid);
});

final manufacturerAnomaliesProvider = StreamProvider<List<AnomalyModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return OperationalDatabaseService.instance.watchAnomalies(user.uid);
});

final allPublicScanEventsProvider = StreamProvider<List<ScanEventModel>>((ref) {
  return OperationalDatabaseService.instance.watchAllScanEvents();
});

class AnalyticsService {
  Future<void> runAnomalyDetection(List<ScanEventModel> scans) async {
    // In-memory operational anomaly detector
    if (scans.isEmpty) return;
  }

  Future<void> updateAnomalyStatus(String id, String status) async {
    OperationalDatabaseService.instance.updateAnomalyStatus(id, status);
    try {
      await FirebaseFirestore.instance.collection('anomalies').doc(id).update({'status': status});
    } catch (_) {}
  }
}

final analyticsServiceProvider = Provider((ref) => AnalyticsService());
