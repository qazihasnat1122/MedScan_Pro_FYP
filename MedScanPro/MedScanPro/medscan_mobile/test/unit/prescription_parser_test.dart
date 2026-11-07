import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/services/prescription_parser.dart';
import 'package:medscan_mobile/providers/scan_providers.dart';

void main() {
  group('PrescriptionParser Tests', () {
    test('Anti-fabrication: Blank OCR returns empty list', () {
      final items = PrescriptionParser.parse('');
      expect(items, isEmpty);
    });

    test(
      'Anti-fabrication: Doctor/Hospital header noise returns empty list',
      () {
        const headerNoise = '''
Dr. Muhammad Ali MBBS FCPS
Shifa International Hospital Islamabad
Phone: 0300-1234567
Patient Name: Ahmad Raza  Age: 35
''';
        final items = PrescriptionParser.parse(headerNoise);
        expect(items, isEmpty);
      },
    );

    test(
      'Structured extraction: Parses valid drug line with dosage and frequency',
      () {
        const rxText = '''
Dr. Farooq Khan MBBS
National Clinic Lahore
Rx
Augmentin 625mg Tab
1-0-1 After meal x 5 days
''';
        final items = PrescriptionParser.parse(rxText);
        expect(items.length, equals(1));
        final item = items.first;
        expect(item.medicineName, equals('Augmentin'));
        expect(item.strength, equals('625mg'));
        expect(item.dosageForm, equals('Tablet'));
        expect(item.frequency, contains('Twice daily'));
        expect(item.timing, equals('After meal'));
        expect(item.durationDays, equals(5));
        expect(item.confidence, equals(FieldConfidence.high));
      },
    );

    test('Candidate matching: Resolves known reference medicine name', () {
      const rxText = '''
Rx
panadol 500mg
1 tab TDS x 3 days
''';
      final items = PrescriptionParser.parse(rxText);
      expect(items.length, equals(1));
      final item = items.first;
      expect(item.medicineName, equals('Panadol'));
      expect(item.strength, equals('500mg'));
    });
  });
}
