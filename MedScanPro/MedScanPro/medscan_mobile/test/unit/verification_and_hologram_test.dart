import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/models/medicine_model.dart';
import 'package:medscan_mobile/models/batch_model.dart';
import 'package:medscan_mobile/models/scan_event_model.dart';
import 'package:medscan_mobile/models/verification_record_model.dart';
import 'package:medscan_mobile/providers/scan_providers.dart';
import 'package:medscan_mobile/repositories/medicine_lookup_repository.dart';
import 'package:medscan_mobile/services/verification_engine.dart';

void main() {
  group('Consumer Mobile App Verification & Lookup Tests', () {
    late MedicineLookupRepository lookupRepo;
    late VerificationEngine verificationEngine;

    setUp(() {
      lookupRepo = MedicineLookupRepository();
      verificationEngine = VerificationEngine();
    });

    test(
      'Lookup medicine by Name, Brand, Generic Salt, and DRAP Reg',
      () async {
        // 1. By exact or partial name (including Disprin)
        final byDisprin = await lookupRepo.searchMedicines('Disprin');
        expect(byDisprin.isNotEmpty, isTrue);
        expect(byDisprin.first.medicineName, contains('Disprin'));
        expect(byDisprin.first.genericName, contains('Aspirin'));

        final byName = await lookupRepo.searchMedicines('Panadol');
        expect(byName.isNotEmpty, isTrue);
        expect(byName.first.medicineName, contains('Panadol'));

        // 2. By generic salt
        final bySalt = await lookupRepo.searchMedicines('Paracetamol');
        expect(bySalt.isNotEmpty, isTrue);
        expect(bySalt.first.genericName, contains('Paracetamol'));

        // 3. By DRAP Registration number
        final byReg = await lookupRepo.searchMedicines('001234');
        expect(byReg.isNotEmpty, isTrue);
        expect(byReg.first.registrationInfo, contains('001234'));

        // 4. By Barcode / Batch Unit Code
        final byBarcode = await lookupRepo.searchMedicines('896400012345');
        expect(byBarcode.isNotEmpty, isTrue);
      },
    );

    test(
      'VerificationEngine returns Reference matched (MANUFACTURER_SUPPORTED) for trusted active batch and lists matched fields',
      () {
        final scanData = ScanData();
        scanData.extractedBrand = 'Panadol';
        scanData.extractedName = 'Panadol 500mg';
        scanData.extractedGenericSalt = 'Paracetamol';
        scanData.extractedStrength = '500mg';
        scanData.extractedManufacturer = 'GSK Pakistan';
        scanData.extractedBatch = 'B1024';
        scanData.extractedExpiry = '12/2027';
        scanData.extractedBarcode = '896400012345';

        final testMed = MedicineModel(
          medicineId: 'med_panadol_500',
          manufacturerId: 'mfg_gsk',
          companyName: 'GSK Pakistan',
          medicineName: 'Panadol 500mg',
          genericName: 'Paracetamol',
          strength: '500mg',
          dosageForm: 'Tablet',
          registrationInfo: 'Reg # 001234',
          referencePrice: 35.0,
          description:
              'Paracetamol formulation for fever and mild pain relief.',
          status: 'approved',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final testBatch = BatchModel(
          batchId:
              'fs_live_batch_b1024', // simulates a live manufacturer-vault (Firestore) record
          medicineId: 'med_panadol_500',
          manufacturerId: 'mfg_gsk',
          batchNumber: 'B1024',
          manufacturingDate: DateTime(2025, 1, 1),
          expiryDate: DateTime(2027, 12, 31),
          status: 'active',
          identifiers: ['896400012345', 'B1024'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = verificationEngine.verify(
          scanData: scanData,
          matchedMedicines: [testMed],
          matchedBatches: [testBatch],
          previousScanCount: 1,
        );

        expect(result.riskLevel, 'MANUFACTURER_SUPPORTED');
        expect(result.verificationStatus, equals('Reference matched'));
        expect(result.isTrustedSource, isTrue);
        expect(
          result.matchedFields.any((f) => f.contains('Brand Name')),
          isTrue,
        );
        expect(
          result.matchedFields.any((f) => f.contains('Strength (500mg)')),
          isTrue,
        );
        expect(
          result.matchedFields.any((f) => f.contains('Batch Number')),
          isTrue,
        );
        expect(result.title, contains('Manufacturer-supported'));
      },
    );

    test(
      'VerificationEngine detects Strength / Variant Mismatch and returns Mismatch detected',
      () {
        final scanData = ScanData();
        scanData.extractedBrand = 'Disprin';
        scanData.extractedName = 'Disprin 500mg';
        scanData.extractedGenericSalt = 'Aspirin';
        scanData.extractedStrength =
            '500mg'; // Mismatch! Reference Disprin is 300mg
        scanData.extractedExpiry = '12/2027';

        final disprinRef = MedicineModel(
          medicineId: 'med_disprin_300',
          manufacturerId: 'mfg_reckitt',
          companyName: 'Reckitt Benckiser Pakistan',
          medicineName: 'Disprin 300mg',
          genericName: 'Aspirin B.P.',
          strength: '300mg',
          dosageForm: 'Tablet',
          registrationInfo: 'DRAP Reg # 004312',
          referencePrice: 40.0,
          description: 'Soluble Aspirin 300mg tablets.',
          status: 'approved',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = verificationEngine.verify(
          scanData: scanData,
          matchedMedicines: [disprinRef],
          matchedBatches: const [],
          previousScanCount: 0,
        );

        expect(result.state, equals(VerificationState.suspiciousDetected));
        expect(result.verificationStatus, equals('Mismatch detected'));
        expect(
          result.mismatchedFields.any((f) => f.contains('Strength')),
          isTrue,
        );
        expect(
          result.reasons.any((r) => r.toLowerCase().contains('strength')),
          isTrue,
        );
      },
    );

    test(
      'VerificationEngine elevates risk when medicine or printed package expiry is expired (Mismatch detected)',
      () {
        final scanData = ScanData();
        scanData.extractedName = 'Panadol 500mg';
        scanData.extractedBatch = 'B-EXPIRED';
        scanData.extractedExpiry = '01/2022';

        final testMed = MedicineModel(
          medicineId: 'med_panadol_500',
          manufacturerId: 'mfg_gsk',
          medicineName: 'Panadol 500mg',
          genericName: 'Paracetamol',
          strength: '500mg',
          dosageForm: 'Tablet',
          registrationInfo: 'Reg # 001234',
          referencePrice: 35.0,
          description:
              'Paracetamol formulation for fever and mild pain relief.',
          status: 'approved',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final expiredBatch = BatchModel(
          batchId: 'batch_old',
          medicineId: 'med_panadol_500',
          manufacturerId: 'mfg_gsk',
          batchNumber: 'B-EXPIRED',
          manufacturingDate: DateTime(2020, 1, 1),
          expiryDate: DateTime(2022, 1, 1), // expired!
          status: 'active',
          identifiers: ['B-EXPIRED'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = verificationEngine.verify(
          scanData: scanData,
          matchedMedicines: [testMed],
          matchedBatches: [expiredBatch],
          previousScanCount: 1,
        );

        expect(result.riskLevel, 'SUSPICIOUS_DETECTED');
        expect(result.verificationStatus, equals('Mismatch detected'));
        expect(
          result.reasons.any((r) => r.toLowerCase().contains('expired')),
          isTrue,
        );
      },
    );

    test(
      'Barcode with no trusted reference returns Unable to verify (NO_REFERENCE_FOUND)',
      () {
        final scanData = ScanData();
        scanData.extractedBarcode = '9999990000111';

        final result = verificationEngine.verify(
          scanData: scanData,
          matchedMedicines: const [],
          matchedBatches: const [],
          previousScanCount: 0,
        );

        expect(result.state, equals(VerificationState.noReferenceFound));
        expect(result.verificationStatus, equals('Unable to verify'));
        expect(result.reasons.any((r) => r.contains('9999990000111')), isTrue);
        expect(result.audit.observedData['Brand Name'], equals('Not detected'));
        expect(
          result.audit.observedData['Batch Number'],
          equals('Not detected'),
        );
      },
    );

    test(
      'Missing batch and expiry on front package scan returns Unable to verify (LIMITED_VERIFICATION) while preserving matched fields',
      () {
        final scanData = ScanData();
        scanData.extractedBrand = 'Disprin';
        scanData.extractedName = 'Disprin 300mg';
        scanData.extractedGenericSalt = 'Aspirin B.P.';
        scanData.extractedStrength = '300mg';
        // Batch and expiry missing on front blister/box side
        scanData.extractedBatch = '';
        scanData.extractedExpiry = '';

        final disprinRef = MedicineModel(
          medicineId: 'med_disprin_300',
          manufacturerId: 'mfg_reckitt',
          companyName: 'Reckitt Benckiser Pakistan',
          medicineName: 'Disprin 300mg',
          genericName: 'Aspirin B.P.',
          strength: '300mg',
          dosageForm: 'Tablet',
          registrationInfo: 'DRAP Reg # 004312',
          referencePrice: 40.0,
          description: 'Soluble Aspirin 300mg tablets.',
          status: 'approved',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = verificationEngine.verify(
          scanData: scanData,
          matchedMedicines: [disprinRef],
          matchedBatches: const [],
          previousScanCount: 0,
        );

        expect(result.state, equals(VerificationState.limitedVerification));
        expect(result.verificationStatus, equals('Unable to verify'));
        expect(result.matchedFields, isNotEmpty);
        expect(
          result.audit.observedData['Batch Number'],
          equals('Not detected'),
        );
        expect(
          result.audit.observedData['Expiry Date'],
          equals('Not detected'),
        );
      },
    );

    test(
      'ScanEventModel serializes with location, device info, and verification badge',
      () {
        final event = ScanEventModel(
          eventId: 'EVT-TEST-01',
          userId: 'consumer_patient_007',
          identifier: 'BATCH-2026-PAN-01-U0001',
          medicineId: 'med_panadol_500',
          medicineName: 'Panadol Extra 500mg/65mg Tablets',
          manufacturerId: 'DRAP-MFG-00109',
          batchNumber: 'BATCH-2026-PAN-01',
          timestamp: DateTime.now(),
          resultCode: 'GREEN',
          verificationResult: '100% Genuine',
          approximateLocation: 'Lahore (Mobile Device)',
          reasons: ['DRAP Approved', 'Active Batch Verified'],
        );

        final map = event.toMap();
        expect(map['medicineName'], 'Panadol Extra 500mg/65mg Tablets');
        expect(map['verificationResult'], '100% Genuine');
        expect(map['approximateLocation'], 'Lahore (Mobile Device)');
        expect(map['identifier'], 'BATCH-2026-PAN-01-U0001');

        final fromMap = ScanEventModel.fromMap(map, 'EVT-TEST-01');
        expect(fromMap.medicineName, event.medicineName);
        expect(fromMap.verificationResult, '100% Genuine');
        expect(fromMap.approximateLocation, 'Lahore (Mobile Device)');
      },
    );

    test('VerificationRecordModel logs correctly for patient history', () {
      final now = DateTime.now();
      final record = VerificationRecordModel(
        id: 'REC-001',
        userId: 'patient-42',
        medicineName: 'Panadol 500mg',
        riskLevel: 'GREEN',
        verifiedAt: now,
      );

      final map = record.toMap();
      expect(map['userId'], 'patient-42');
      expect(map['medicineName'], 'Panadol 500mg');
      expect(map['riskLevel'], 'GREEN');

      final fromMap = VerificationRecordModel.fromMap(map, 'REC-001');
      expect(fromMap.medicineName, 'Panadol 500mg');
      expect(fromMap.riskLevel, 'GREEN');
    });
  });
}
