import os

base_path = r'd:\medscan\MedScanPro\medscan_web\lib'

files = {
    'models/scan_event_model.dart': '''
class ScanEventModel {
  final String id;
  final String identifier;
  final String medicineId;
  final String manufacturerId;
  final String batchNumber;
  final DateTime timestamp;
  final String verificationResult;
  final String? approximateLocation;

  ScanEventModel({
    required this.id,
    required this.identifier,
    required this.medicineId,
    required this.manufacturerId,
    required this.batchNumber,
    required this.timestamp,
    required this.verificationResult,
    this.approximateLocation,
  });
}
''',
    'models/anomaly_model.dart': '''
class AnomalyModel {
  final String id;
  final String identifier;
  final String medicineId;
  final String manufacturerId;
  final String anomalyType; // e.g., "Repeated scans", "Rapid scans"
  final String description; // MUST use "Unusual scan activity detected"
  final DateTime detectedAt;
  final String status; // "New", "Under Review", "Resolved"

  AnomalyModel({
    required this.id,
    required this.identifier,
    required this.medicineId,
    required this.manufacturerId,
    required this.anomalyType,
    required this.description,
    required this.detectedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'anomalyType': anomalyType,
      'description': description,
      'detectedAt': detectedAt.toIso8601String(),
      'status': status,
    };
  }
}
''',
    'providers/analytics_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scan_event_model.dart';
import '../models/anomaly_model.dart';
import 'auth_providers.dart';

final _firestore = FirebaseFirestore.instance;

final manufacturerScanEventsProvider = StreamProvider<List<ScanEventModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return _firestore.collection('scanEvents')
      .where('manufacturerId', isEqualTo: user.uid)
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) {
        final data = d.data();
        return ScanEventModel(
          id: d.id,
          identifier: data['identifier'] ?? '',
          medicineId: data['medicineId'] ?? '',
          manufacturerId: data['manufacturerId'] ?? '',
          batchNumber: data['batchNumber'] ?? '',
          timestamp: data['timestamp'] != null ? DateTime.parse(data['timestamp']) : DateTime.now(),
          verificationResult: data['verificationResult'] ?? 'Unknown',
          approximateLocation: data['approximateLocation'],
        );
      }).toList());
});

final manufacturerAnomaliesProvider = StreamProvider<List<AnomalyModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return _firestore.collection('anomalies')
      .where('manufacturerId', isEqualTo: user.uid)
      .orderBy('detectedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) {
        final data = d.data();
        return AnomalyModel(
          id: d.id,
          identifier: data['identifier'] ?? '',
          medicineId: data['medicineId'] ?? '',
          manufacturerId: data['manufacturerId'] ?? '',
          anomalyType: data['anomalyType'] ?? '',
          description: data['description'] ?? 'Unusual scan activity detected',
          detectedAt: DateTime.parse(data['detectedAt']),
          status: data['status'] ?? 'New',
        );
      }).toList());
});

class AnalyticsService {
  // Simulates a background job or periodic check to detect anomalies.
  // In a real app, this would be a Firebase Cloud Function.
  Future<void> runAnomalyDetection(List<ScanEventModel> scans) async {
    if (scans.isEmpty) return;
    
    // Group by identifier
    final map = <String, List<ScanEventModel>>{};
    for (var scan in scans) {
      if (scan.identifier.isEmpty) continue;
      map.putIfAbsent(scan.identifier, () => []).add(scan);
    }
    
    for (var entry in map.entries) {
      final identifierScans = entry.value;
      if (identifierScans.length > 3) {
        // Repeated scans anomaly
        await _createAnomalyIfNotExists(
          identifier: entry.key,
          medicineId: identifierScans.first.medicineId,
          manufacturerId: identifierScans.first.manufacturerId,
          type: 'Repeated identifier scans',
        );
      }
    }
  }

  Future<void> _createAnomalyIfNotExists({
    required String identifier,
    required String medicineId,
    required String manufacturerId,
    required String type,
  }) async {
    final existing = await _firestore.collection('anomalies')
        .where('identifier', isEqualTo: identifier)
        .where('anomalyType', isEqualTo: type)
        .get();
        
    if (existing.docs.isEmpty) {
      final anomaly = AnomalyModel(
        id: '',
        identifier: identifier,
        medicineId: medicineId,
        manufacturerId: manufacturerId,
        anomalyType: type,
        description: 'Unusual scan activity detected',
        detectedAt: DateTime.now(),
        status: 'New',
      );
      await _firestore.collection('anomalies').add(anomaly.toMap());
    }
  }

  Future<void> updateAnomalyStatus(String id, String status) async {
    await _firestore.collection('anomalies').doc(id).update({'status': status});
  }
}

final analyticsServiceProvider = Provider((ref) => AnalyticsService());
''',
    'features/analytics/anomalies_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analytics_providers.dart';

class AnomaliesScreen extends ConsumerWidget {
  const AnomaliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomaliesAsync = ref.watch(manufacturerAnomaliesProvider);
    final scanEventsAsync = ref.watch(manufacturerScanEventsProvider);
    
    // Auto-trigger detection logic for MVP simulation
    scanEventsAsync.whenData((scans) {
      ref.read(analyticsServiceProvider).runAnomalyDetection(scans);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Anomalies Review')),
      body: anomaliesAsync.when(
        data: (anomalies) {
          if (anomalies.isEmpty) return const Center(child: Text('No anomalies detected.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: anomalies.length,
            itemBuilder: (context, index) {
              final a = anomalies[index];
              return Card(
                color: Colors.red.shade50,
                child: ListTile(
                  title: Text('\${a.anomalyType} (Medicine: \${a.medicineId})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.description),
                      Text('Identifier: \${a.identifier}'),
                      Text('Detected: \${a.detectedAt}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: a.status,
                            items: ['New', 'Under Review', 'Resolved'].map((s) {
                              return DropdownMenuItem(value: s, child: Text(s));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(analyticsServiceProvider).updateAnomalyStatus(a.id, val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
''',
    'features/analytics/scan_activity_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analytics_providers.dart';

class ScanActivityScreen extends ConsumerWidget {
  const ScanActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanEventsAsync = ref.watch(manufacturerScanEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Activity')),
      body: scanEventsAsync.when(
        data: (scans) {
          if (scans.isEmpty) return const Center(child: Text('No recent scans for your products.'));
          return ListView.builder(
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final s = scans[index];
              return ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: Text('Identifier: \${s.identifier.isNotEmpty ? s.identifier : "N/A"}'),
                subtitle: Text('Batch: \${s.batchNumber} | Location: \${s.approximateLocation ?? "Private"} | Result: \${s.verificationResult}'),
                trailing: Text(s.timestamp.toString().split('.')[0]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
'''
}

for filepath, content in files.items():
    full_path = os.path.join(base_path, filepath)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + '\\n')

print("Files generated for Module 9")
