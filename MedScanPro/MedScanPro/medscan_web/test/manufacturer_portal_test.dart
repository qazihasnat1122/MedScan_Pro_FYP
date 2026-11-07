import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_web/services/drap_fbr_directory.dart';
import 'package:medscan_web/services/operational_database_service.dart';
import 'package:medscan_web/models/packaging_model.dart';
import 'package:medscan_web/models/scan_event_model.dart';

void main() {
  group('1. DRAP & FBR Regulatory Authentication Tests', () {
    test('Successfully verifies official pharmaceutical company in DRAP directory', () {
      final verified = DrapFbrDirectory.verify(
        drapLicense: 'DRAP-MFG-00109',
        fbrNtn: '0824911-7',
        secretKey: 'GSK-DRAP-2026',
      );

      expect(verified, isNotNull);
      expect(verified!.name, contains('GlaxoSmithKline'));
      expect(verified.drapLicense, equals('DRAP-MFG-00109'));
      expect(verified.fbrNtn, equals('0824911-7'));
    });

    test('Successfully verifies Abbott Laboratories with NTN formatting spaces trimmed', () {
      final verified = DrapFbrDirectory.verify(
        drapLicense: 'drap-mfg-00284',
        fbrNtn: ' 1492044-2 ',
        secretKey: 'ABT-DRAP-2026',
      );

      expect(verified, isNotNull);
      expect(verified!.name, contains('Abbott'));
    });

    test('Rejects unauthorized or forged company credentials', () {
      final invalid = DrapFbrDirectory.verify(
        drapLicense: 'FAKE-DRAP-99999',
        fbrNtn: '0000000-0',
        secretKey: 'BAD-KEY',
      );

      expect(invalid, isNull);
    });

    test('Rejects when DRAP license is valid but FBR NTN does not match corporate tax record', () {
      final mismatch = DrapFbrDirectory.verify(
        drapLicense: 'DRAP-MFG-00109',
        fbrNtn: '9999999-9', // Wrong NTN for GSK
        secretKey: 'GSK-DRAP-2026',
      );

      expect(mismatch, isNull);
    });
  });

  group('2. Company Vault Data Isolation Tests', () {
    final db = OperationalDatabaseService.instance;

    test('Company A (GSK) only sees its own medicines and cannot see Company B (Abbott) medicines', () async {
      final gskMedicines = await db.watchMedicines('DRAP-MFG-00109').first;
      final abtMedicines = await db.watchMedicines('DRAP-MFG-00284').first;

      expect(gskMedicines.isNotEmpty, isTrue);
      expect(abtMedicines.isNotEmpty, isTrue);

      // Verify GSK list only has GSK medicines
      for (final m in gskMedicines) {
        expect(m.manufacturerId, equals('DRAP-MFG-00109'));
        expect(m.medicineName, isNot('Brufen'));
      }

      // Verify Abbott list only has Abbott medicines
      for (final m in abtMedicines) {
        expect(m.manufacturerId, equals('DRAP-MFG-00284'));
        expect(m.medicineName, isNot('Panadol'));
      }
    });

    test('Public consumer catalog sees medicines across all approved manufacturers', () async {
      final allPublic = await db.watchAllPublicMedicines().first;

      expect(allPublic.any((m) => m.medicineName.contains('Panadol')), isTrue);
      expect(allPublic.any((m) => m.medicineName.contains('Brufen')), isTrue);
      expect(allPublic.any((m) => m.medicineName.contains('Risek')), isTrue);
    });

    test('Company A only sees its own batches in production vault', () async {
      final gskBatches = await db.watchBatches('DRAP-MFG-00109').first;
      final abtBatches = await db.watchBatches('DRAP-MFG-00284').first;

      for (final b in gskBatches) {
        expect(b.manufacturerId, equals('DRAP-MFG-00109'));
      }
      for (final b in abtBatches) {
        expect(b.manufacturerId, equals('DRAP-MFG-00284'));
      }
    });
  });

  group('3. Packaging & Zero-Cost Hologram Image Storage Tests', () {
    final db = OperationalDatabaseService.instance;

    test('Correctly saves and retrieves Base64 data URI packaging reference', () async {
      const sampleBase64Data = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      
      final packRef = PackagingModel(
        referenceId: 'TEST-PKG-B64-001',
        medicineId: 'Panadol Extra 500mg/65mg Tablets',
        manufacturerId: 'DRAP-MFG-00109',
        frontImageUrl: sampleBase64Data,
        otherImageUrls: ['FEATURE:HOLOGRAPHIC_STRIP', 'FEATURE:TAMPER_EVIDENT_SEAL'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.addPackaging(packRef);

      final list = await db.watchPackaging('DRAP-MFG-00109').first;
      final retrieved = list.firstWhere((p) => p.referenceId == 'TEST-PKG-B64-001');

      expect(retrieved.frontImageUrl, startsWith('data:image/png;base64,'));
      expect(retrieved.otherImageUrls, contains('FEATURE:HOLOGRAPHIC_STRIP'));

      // Validate base64 decodability without corruption
      final rawBase64 = retrieved.frontImageUrl!.split(',').last;
      final bytes = base64Decode(rawBase64);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  group('4. Live Scan Telemetry & Anti-Counterfeit Auditing Tests', () {
    final db = OperationalDatabaseService.instance;

    test('Injecting consumer scan event routes to corresponding manufacturer telemetry', () async {
      final now = DateTime.now();
      final event = ScanEventModel(
        id: 'TEST-SCN-LIVE-99',
        identifier: 'PAN-TEST-999',
        medicineId: 'Panadol Extra 500mg/65mg Tablets',
        manufacturerId: 'DRAP-MFG-00109',
        batchNumber: 'PAN-500-2026-A',
        timestamp: now,
        verificationResult: '100% Genuine',
        approximateLocation: 'Islamabad F-10 Markaz',
      );

      db.addScanEvent(event);

      final gskScans = await db.watchScanEvents('DRAP-MFG-00109').first;
      expect(gskScans.any((s) => s.id == 'TEST-SCN-LIVE-99'), isTrue);

      final retrieved = gskScans.firstWhere((s) => s.id == 'TEST-SCN-LIVE-99');
      expect(retrieved.approximateLocation, equals('Islamabad F-10 Markaz'));
      expect(retrieved.verificationResult, equals('100% Genuine'));

      // Abbott does not see GSK scans
      final abtScans = await db.watchScanEvents('DRAP-MFG-00284').first;
      expect(abtScans.any((s) => s.id == 'TEST-SCN-LIVE-99'), isFalse);
    });
  });
}
