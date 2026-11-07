import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/repositories/medicine_lookup_repository.dart';
import 'package:medscan_mobile/services/ocr_service.dart';
import 'package:medscan_mobile/services/packaging_ocr_parser.dart';

void main() {
  group('PackagingOcrParser & Medicine Candidate Ranking Tests', () {
    test(
      'REGRESSION: Disprin vs dawaai.com selects Disprin and never selects dawaai.com',
      () {
        const disprinWithWatermarkOcr = '''
dawaai.com
Order medicines online at www.dawaai.com
Fast Pain Relief
Each soluble tablet contains:
Aspirin B.P. 300mg
Disprin
Reckitt Benckiser Pakistan
Keep out of reach of children
''';

        final result = PackagingOcrParser.parse(disprinWithWatermarkOcr);

        expect(result.brandName, equals('Disprin'));
        expect(result.medicineName, equals('Disprin 300mg'));
        expect(result.brandName.toLowerCase(), isNot(contains('dawaai')));
        expect(result.medicineName.toLowerCase(), isNot(contains('dawaai')));
        expect(result.genericSalt, contains('Aspirin'));
        expect(result.strength, equals('300mg'));
        expect(result.manufacturer, equals('Reckitt Benckiser Pakistan'));
        expect(
          result.brandCandidates.any((c) => c.toLowerCase().contains('dawaai')),
          isFalse,
        );
      },
    );

    test(
      'Excludes URLs, website domains, retailer names, and slogans even when no database brand is present',
      () {
        const retailerAndSlogansOnly = '''
https://www.dvago.pk
dawaai.com
sehat.com.pk
emeds.pk
Fast Pain Relief
Doctor Recommended No. 1
Dissolve in water before use
Store below 30C
''';

        final result = PackagingOcrParser.parse(retailerAndSlogansOnly);
        expect(result.brandName, isEmpty);
        expect(result.medicineName, isEmpty);
      },
    );

    test(
      'Uses OCR bounding box visual prominence and database matching to rank brand candidates',
      () {
        final ocrLines = [
          const OcrTextLine(
            text: 'dawaai.com',
            boundingBox: Rect.fromLTWH(10, 5, 200, 28),
            blockIndex: 0,
            lineIndex: 0,
          ),
          const OcrTextLine(
            text: 'Soluble Aspirin Tablets',
            boundingBox: Rect.fromLTWH(10, 40, 180, 18),
            blockIndex: 1,
            lineIndex: 0,
          ),
          const OcrTextLine(
            text: 'DISPRIN',
            boundingBox: Rect.fromLTWH(20, 80, 320, 74), // Largest text on pack
            blockIndex: 2,
            lineIndex: 0,
          ),
          const OcrTextLine(
            text: '300mg',
            boundingBox: Rect.fromLTWH(250, 95, 90, 32),
            blockIndex: 2,
            lineIndex: 1,
          ),
        ];

        final rawText = ocrLines.map((l) => l.text).join('\n');
        final result = PackagingOcrParser.parse(rawText, ocrLines: ocrLines);

        expect(result.brandName, equals('Disprin'));
        expect(result.medicineName, equals('Disprin 300mg'));
        expect(result.genericSalt, contains('Aspirin'));
        expect(result.strength, equals('300mg'));
      },
    );

    test(
      'Exact and fuzzy brand matching against medicine lookup repository',
      () async {
        final repo = MedicineLookupRepository();

        // 1. Exact brand match
        final exactDisprin = await repo.rankMedicineCandidates(
          'Disprin',
          genericSalt: 'Aspirin',
          strength: '300mg',
        );
        expect(exactDisprin, isNotEmpty);
        expect(
          exactDisprin.first.medicine.medicineName,
          equals('Disprin 300mg'),
        );

        // 2. Fuzzy OCR typo match ("Dlsprin" -> "Disprin 300mg", "PanadoI" -> "Panadol 500mg")
        final fuzzyDisprin = await repo.rankMedicineCandidates(
          'Dlsprin',
          genericSalt: 'Aspirin',
          strength: '300mg',
        );
        expect(fuzzyDisprin, isNotEmpty);
        expect(
          fuzzyDisprin.first.medicine.medicineName,
          equals('Disprin 300mg'),
        );

        final fuzzyPanadol = await repo.rankMedicineCandidates(
          'Panado1',
          genericSalt: 'Paracetamol',
          strength: '500mg',
        );
        expect(fuzzyPanadol, isNotEmpty);
        expect(
          fuzzyPanadol.first.medicine.medicineName,
          equals('Panadol 500mg'),
        );

        // 3. URL query returns empty
        final urlQuery = await repo.rankMedicineCandidates('dawaai.com');
        expect(urlQuery, isEmpty);
      },
    );

    test('Correctly parses real user scan of Dianic 50mg (NovaMed)', () {
      const userRawOcr = '''
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

      final result = PackagingOcrParser.parse(userRawOcr);

      expect(result.brandName, equals('Dianic'));
      expect(result.medicineName, equals('Dianic 50mg'));
      expect(result.genericSalt, contains('Diclofenac Sodium'));
      expect(result.strength, equals('50mg'));
      expect(result.manufacturer, equals('NovaMed Pharmaceuticals'));
      expect(result.batchNumber, equals('21787'));
      expect(result.mfgDate, equals('04/2025'));
      expect(result.expiryDate, equals('04/2027'));
      expect(result.price, contains('417.0'));
      expect(result.dosageForm, equals('Enteric Coated Tablet'));
      expect(result.specialNotice, contains('Punjab Govt Property'));
      expect(
        result.cleanedLines.any((l) => l.contains('Terminal Help')),
        isFalse,
      );
      expect(result.cleanedLines.any((l) => l.contains('dart tool')), isFalse);
    });

    test(
      'Expiry date parsing and validation handles valid future dates, expired dates, and missing dates',
      () {
        final refNow = DateTime(2026, 10, 23);

        final futureCheck = PackagingOcrParser.validateExpiryDate(
          '12/2027',
          now: refNow,
        );
        expect(futureCheck.isExpired, isFalse);
        expect(futureCheck.message, contains('Valid until 12/2027'));

        final shortMonthYear = PackagingOcrParser.validateExpiryDate(
          '04-28',
          now: refNow,
        );
        expect(shortMonthYear.isExpired, isFalse);
        expect(shortMonthYear.message, contains('04/2028'));

        final alphaMonthYear = PackagingOcrParser.validateExpiryDate(
          'Dec 2027',
          now: refNow,
        );
        expect(alphaMonthYear.isExpired, isFalse);
        expect(alphaMonthYear.message, contains('12/2027'));

        final expiredCheck = PackagingOcrParser.validateExpiryDate(
          '05/2024',
          now: refNow,
        );
        expect(expiredCheck.isExpired, isTrue);
        expect(expiredCheck.message, contains('EXPIRED'));

        final missingCheck = PackagingOcrParser.validateExpiryDate(
          '',
          now: refNow,
        );
        expect(missingCheck.isExpired, isNull);
        expect(missingCheck.message, equals('Not detected'));
      },
    );

    test(
      'Unreadable or missing batch numbers are never fabricated and return empty',
      () {
        const unreadableBatchOcr = '''
Disprin 300mg
Aspirin B.P.
Batch No: Date
Lot No: ---
Exp. Date: 12/2027
''';
        final result = PackagingOcrParser.parse(unreadableBatchOcr);
        expect(result.brandName, equals('Disprin'));
        expect(result.batchNumber, isEmpty);
        expect(result.expiryDate, equals('12/2027'));
      },
    );

    test('Ambiguous or missing OCR results do not fabricate medicine names', () {
      // 1. Empty OCR
      final emptyResult = PackagingOcrParser.parse('');
      expect(emptyResult.medicineName, isEmpty);
      expect(emptyResult.brandName, isEmpty);
      expect(emptyResult.genericSalt, isEmpty);
      expect(emptyResult.strength, isEmpty);
      expect(emptyResult.batchNumber, isEmpty);
      expect(emptyResult.expiryDate, isEmpty);
      expect(emptyResult.manufacturer, isEmpty);
      expect(emptyResult.expiryValidationMessage, equals('Not detected'));

      // 2. Only generic salt ("Paracetamol") with no brand name -> provides brand candidates and marks ambiguous
      const saltOnlyOcr = '''
Each tablet contains:
Paracetamol 500mg
Store below 30C
''';
      final saltOnlyResult = PackagingOcrParser.parse(saltOnlyOcr);
      expect(saltOnlyResult.brandName, isEmpty);
      expect(saltOnlyResult.genericSalt, equals('Paracetamol'));
      expect(saltOnlyResult.strength, equals('500mg'));
      expect(saltOnlyResult.brandCandidates, isNotEmpty);
      expect(saltOnlyResult.isAmbiguous, isTrue);
    });
  });
}
