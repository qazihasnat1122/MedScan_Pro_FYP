import os

base_path = r'd:\medscan\MedScanPro\medscan_mobile\lib'

files = {
    'models/scan_event_model.dart': '''
class ScanEventModel {
  final String eventId;
  final String userId;
  final String identifier;
  final String medicineId;
  final String manufacturerId;
  final String batchNumber;
  final DateTime timestamp;
  final String resultCode;
  final List<String> reasons;

  ScanEventModel({
    required this.eventId,
    required this.userId,
    required this.identifier,
    required this.medicineId,
    required this.manufacturerId,
    required this.batchNumber,
    required this.timestamp,
    required this.resultCode,
    required this.reasons,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'identifier': identifier,
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'batchNumber': batchNumber,
      'timestamp': timestamp.toIso8601String(),
      'resultCode': resultCode,
      'reasons': reasons,
    };
  }
}
''',
    'services/verification_engine.dart': '''
import '../providers/scan_providers.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';

class VerificationResult {
  final String riskLevel; // GREEN, YELLOW, RED, UNKNOWN
  final String title;
  final List<String> reasons;

  VerificationResult(this.riskLevel, this.title, this.reasons);
}

class VerificationEngine {
  VerificationResult verify({
    required ScanData scanData,
    required List<MedicineModel> matchedMedicines,
    required List<BatchModel> matchedBatches,
    required int previousScanCount,
  }) {
    if (matchedMedicines.isEmpty) {
      return VerificationResult(
        'UNKNOWN',
        'Unable to fully verify this medicine',
        ['No matching approved medicine found in the reference database.'],
      );
    }

    final medicine = matchedMedicines.first;
    List<String> reasons = [];
    int riskScore = 0; // 0 = Green, 1-2 = Yellow, 3+ = Red

    // 1. Batch Check
    if (matchedBatches.isEmpty) {
      riskScore += 2;
      reasons.add('Batch information needs checking or is missing.');
    } else {
      final batch = matchedBatches.first;
      if (batch.status != 'active') {
        riskScore += 3;
        reasons.add('Batch is marked as ${batch.status}.');
      }
      if (batch.expiryDate.isBefore(DateTime.now())) {
        riskScore += 2;
        reasons.add('Medicine is expired.');
      }
      
      // Identifier Check
      if (scanData.extractedBarcode.isNotEmpty && batch.identifiers.isNotEmpty) {
        if (!batch.identifiers.contains(scanData.extractedBarcode)) {
          riskScore += 2;
          reasons.add('Barcode/Identifier does not match trusted records.');
        }
      }
    }

    // 2. Packaging Text Comparison (Basic simulation)
    if (scanData.extractedManufacturer.isNotEmpty && 
        !scanData.extractedManufacturer.toLowerCase().contains(medicine.manufacturerId.toLowerCase()) && 
        !medicine.medicineName.toLowerCase().contains(scanData.extractedManufacturer.toLowerCase())) {
        riskScore += 1;
        reasons.add('Packaging text (Manufacturer) differs from reference.');
    }

    // 3. Anomaly Detection
    if (previousScanCount > 5) {
      riskScore += 3;
      reasons.add('Unusual scan activity: This exact identifier has been scanned many times globally.');
    } else if (previousScanCount > 1) {
      riskScore += 1;
      reasons.add('This identifier has been scanned previously.');
    }

    // Determine Final Risk
    if (riskScore == 0) {
      return VerificationResult('GREEN', 'No major suspicious indicators found', ['Matches reference data.']);
    } else if (riskScore < 3) {
      return VerificationResult('YELLOW', 'Further verification recommended', reasons);
    } else {
      return VerificationResult('RED', 'Multiple suspicious indicators detected', reasons);
    }
  }
}
''',
    'providers/verification_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/verification_engine.dart';
import '../models/scan_event_model.dart';

final verificationEngineProvider = Provider((ref) => VerificationEngine());

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getIdentifierScanCount(String identifier) async {
    if (identifier.isEmpty) return 0;
    final snapshot = await _firestore.collection('scanEvents').where('identifier', isEqualTo: identifier).get();
    return snapshot.docs.length;
  }

  Future<void> logScanEvent(ScanEventModel event) async {
    await _firestore.collection('scanEvents').add(event.toMap());
  }
}

final verificationServiceProvider = Provider((ref) => VerificationService());
''',
    'features/scan/lookup_result_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/verification_providers.dart';
import '../../models/batch_model.dart';
import '../../models/scan_event_model.dart';
import '../../shared/widgets/primary_button.dart';
import '../../services/verification_engine.dart';

class LookupResultScreen extends ConsumerStatefulWidget {
  const LookupResultScreen({super.key});

  @override
  ConsumerState<LookupResultScreen> createState() => _LookupResultScreenState();
}

class _LookupResultScreenState extends ConsumerState<LookupResultScreen> {
  bool _isLoading = true;
  String? _error;
  VerificationResult? _result;

  @override
  void initState() {
    super.initState();
    _performVerification();
  }

  Future<void> _performVerification() async {
    try {
      final repo = ref.read(medicineLookupProvider);
      final verifService = ref.read(verificationServiceProvider);
      final engine = ref.read(verificationEngineProvider);
      final data = ref.read(scanStateProvider);
      final user = ref.read(authStateProvider).value;
      
      final meds = await repo.searchMedicines(data.extractedName);
      
      List<BatchModel> matchingBatches = [];
      if (meds.isNotEmpty && data.extractedBatch.isNotEmpty) {
        for (var m in meds) {
          final b = await repo.searchBatches(m.medicineId, data.extractedBatch);
          matchingBatches.addAll(b);
        }
      }

      final identifier = data.extractedBarcode.isNotEmpty ? data.extractedBarcode : data.extractedBatch;
      final scanCount = await verifService.getIdentifierScanCount(identifier);

      final result = engine.verify(
        scanData: data,
        matchedMedicines: meds,
        matchedBatches: matchingBatches,
        previousScanCount: scanCount,
      );

      if (user != null) {
        final event = ScanEventModel(
          eventId: '',
          userId: user.uid,
          identifier: identifier,
          medicineId: meds.isNotEmpty ? meds.first.medicineId : 'unknown',
          manufacturerId: meds.isNotEmpty ? meds.first.manufacturerId : 'unknown',
          batchNumber: data.extractedBatch,
          timestamp: DateTime.now(),
          resultCode: result.riskLevel,
          reasons: result.reasons,
        );
        await verifService.logScanEvent(event);
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getRiskColor(String level) {
    if (level == 'GREEN') return Colors.green;
    if (level == 'YELLOW') return Colors.orange;
    if (level == 'RED') return Colors.red;
    return Colors.grey;
  }
  
  IconData _getRiskIcon(String level) {
    if (level == 'GREEN') return Icons.check_circle;
    if (level == 'YELLOW') return Icons.warning;
    if (level == 'RED') return Icons.error;
    return Icons.help;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Result')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? Center(child: Text('Error: $_error'))
              : _result == null 
                  ? const Center(child: Text('Verification failed.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(_getRiskIcon(_result!.riskLevel), size: 100, color: _getRiskColor(_result!.riskLevel)),
                          const SizedBox(height: 24),
                          Text(
                            _result!.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _getRiskColor(_result!.riskLevel)),
                          ),
                          const SizedBox(height: 32),
                          const Text('Why?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ..._result!.reasons.map((r) => ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text(r),
                          )),
                          const SizedBox(height: 48),
                          PrimaryButton(
                            text: 'Back to Home',
                            onPressed: () => context.go('/'),
                          ),
                        ],
                      ),
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

print("Files generated for Module 6")
