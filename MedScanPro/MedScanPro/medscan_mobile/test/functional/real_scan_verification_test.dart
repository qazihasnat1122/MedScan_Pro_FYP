import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/services/packaging_ocr_parser.dart';
import 'package:medscan_mobile/repositories/medicine_lookup_repository.dart';
import 'package:medscan_mobile/services/verification_engine.dart';
import 'package:medscan_mobile/providers/scan_providers.dart';

void main() {
  group('Real Blister Pack Verification Pipeline Test', () {
    const realUserScan = '''
Each enteric coated tablet contains:
50mg Diclofenac Sodium B.P
NovaMed
8.P
PUNJAB COVLPROPERIY
NOT
FORSALE
50mg
Dianic
(Diclofenac Sodium B.P)
10x10's Tablets
Batch No.
Mig. Date:
Exp. Date:
MRP. Rs.:
21787
04-25
04-27
417.0
ArA
A Fle Edit Selection View Go Run
Terminal Help
50mg
Egplorer
V MedScanPro
v github\\workilows
Y build josyml
vmedscan mobile
Shift
> dart tool
>idea
va android
>gradle
>kotlin
Tab
> aradle
CapsLk
Esc
Fnlock
A
Z
''';

    test(
      'End-to-End: Raw OCR is cleaned, structured, and matched to sample reference (never manufacturer-supported)',
      () async {
        // 1. OCR Parser Stage
        final parsed = PackagingOcrParser.parse(realUserScan);

        expect(parsed.brandName, equals('Dianic'));
        expect(parsed.medicineName, equals('Dianic 50mg'));
        expect(parsed.manufacturer, equals('NovaMed Pharmaceuticals'));
        expect(parsed.batchNumber, equals('21787'));
        expect(parsed.expiryDate, equals('04/2027'));
        expect(parsed.specialNotice, contains('Punjab Govt Property'));

        // 2. Scan Data Population
        final scanData = ScanData();
        scanData.rawText = realUserScan;
        scanData.extractedName = parsed.medicineName;
        scanData.extractedManufacturer = parsed.manufacturer;
        scanData.extractedBatch = parsed.batchNumber;
        scanData.extractedExpiry = parsed.expiryDate;
        scanData.extractedRegistrationInfo = parsed.registrationInfo;
        scanData.extractedGenericSalt = parsed.genericSalt;
        scanData.extractedStrength = parsed.strength;
        scanData.extractedPrice = parsed.price;
        scanData.extractedMfgDate = parsed.mfgDate;
        scanData.extractedDosageForm = parsed.dosageForm;
        scanData.specialNotice = parsed.specialNotice;
        scanData.structuredSummary = parsed.structuredSummary;

        // 3. Medicine & Batch Lookup
        final repo = MedicineLookupRepository();
        final meds = await repo.searchMedicines(scanData.extractedName);
        expect(meds.isNotEmpty, isTrue);
        expect(meds.first.medicineName, equals('Dianic 50mg'));
        expect(meds.first.genericName, contains('Diclofenac Sodium'));

        final batches = await repo.searchBatches(
          meds.first.medicineId,
          scanData.extractedBatch,
        );
        expect(batches.isNotEmpty, isTrue);
        expect(batches.first.batchNumber, equals('21787'));
        expect(batches.first.status, equals('active'));

        // 4. Verification Engine
        final engine = VerificationEngine();
        final result = engine.verify(
          scanData: scanData,
          matchedMedicines: meds,
          matchedBatches: batches,
          previousScanCount: 0,
        );

        // Batch came from sample data bundled in the app, so it must NOT be
        // reported as manufacturer-supported (green).
        expect(result.state, isNot(VerificationState.manufacturerSupported));
        expect(
          result.state,
          anyOf(
            VerificationState.referenceAvailable,
            VerificationState.limitedVerification,
          ),
        );
        expect(
          result.audit.unresolvedUncertainty.any(
            (u) => u.contains('bundled in this app build'),
          ),
          isTrue,
        );
      },
    );
  });
}
