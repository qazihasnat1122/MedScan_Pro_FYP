import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/services/clinical_service.dart';
import 'package:medscan_mobile/models/user_medication_model.dart';

void main() {
  group('ClinicalService Unit Tests', () {
    late ClinicalService clinicalService;

    setUp(() {
      clinicalService = ClinicalService();
    });

    test(
      'Detects potential interaction or advisories between concurrent medications',
      () {
        final meds = [
          UserMedicationModel(
            id: '1',
            userId: 'u1',
            name: 'Panadol 500mg',
            strength: '500mg',
            dosage: '1 Tablet',
            frequency: 'As needed',
            createdAt: DateTime.now(),
          ),
          UserMedicationModel(
            id: '2',
            userId: 'u1',
            name: 'Brufen 400mg',
            strength: '400mg',
            dosage: '1 Tablet',
            frequency: 'Twice daily',
            createdAt: DateTime.now(),
          ),
        ];

        final warnings = clinicalService.checkInteractions(meds);
        expect(warnings, isA<List<String>>());
        expect(
          warnings.any(
            (w) =>
                w.contains('Timing Advisory') &&
                w.contains('Paracetamol + Ibuprofen'),
          ),
          isTrue,
        );
      },
    );

    test('Detects duplicate active salt toxicity (e.g. Panadol + Calpol)', () {
      final meds = [
        UserMedicationModel(
          id: '1',
          userId: 'u1',
          name: 'Panadol 500mg',
          strength: '500mg',
          dosage: '1 Tablet',
          frequency: 'As needed',
          createdAt: DateTime.now(),
        ),
        UserMedicationModel(
          id: '2',
          userId: 'u1',
          name: 'Calpol 500mg',
          strength: '500mg',
          dosage: '1 Tablet',
          frequency: 'Twice daily',
          createdAt: DateTime.now(),
        ),
      ];

      final warnings = clinicalService.checkInteractions(meds);
      expect(
        warnings.any(
          (w) =>
              w.contains('Duplicate Active Salt Alert') &&
              w.contains('PARACETAMOL'),
        ),
        isTrue,
      );
    });

    test('Detects critical Aspirin + Warfarin bleeding risk', () {
      final meds = [
        UserMedicationModel(
          id: '1',
          userId: 'u1',
          name: 'Disprin (Aspirin)',
          strength: '300mg',
          dosage: '1 Tablet',
          frequency: 'Once daily',
          createdAt: DateTime.now(),
        ),
        UserMedicationModel(
          id: '2',
          userId: 'u1',
          name: 'Warfarin 5mg',
          strength: '5mg',
          dosage: '1 Tablet',
          frequency: 'Once daily evening',
          createdAt: DateTime.now(),
        ),
      ];

      final warnings = clinicalService.checkInteractions(meds);
      expect(
        warnings.any(
          (w) => w.contains('Severe Interaction') && w.contains('bleeding'),
        ),
        isTrue,
      );
    });

    test(
      'Flags unknown or unmapped medicine as incomplete information advisory',
      () {
        final meds = [
          UserMedicationModel(
            id: '1',
            userId: 'u1',
            name: 'Panadol 500mg',
            strength: '500mg',
            dosage: '1 Tablet',
            frequency: 'As needed',
            createdAt: DateTime.now(),
          ),
          UserMedicationModel(
            id: '2',
            userId: 'u1',
            name: 'Custom Herbal Compound XYZ',
            strength: '10ml',
            dosage: '1 Spoon',
            frequency: 'Daily',
            createdAt: DateTime.now(),
          ),
        ];

        final warnings = clinicalService.checkInteractions(meds);
        expect(
          warnings.any(
            (w) =>
                w.contains('Incomplete ingredient profile') &&
                w.contains('Custom Herbal Compound XYZ'),
          ),
          isTrue,
        );
      },
    );

    test('Handles single medication without false positive warnings', () {
      final meds = [
        UserMedicationModel(
          id: '1',
          userId: 'u1',
          name: 'Amoxicillin 500mg',
          strength: '500mg',
          dosage: '1 Capsule',
          frequency: 'Three times daily',
          createdAt: DateTime.now(),
        ),
      ];

      final warnings = clinicalService.checkInteractions(meds);
      expect(warnings, isEmpty);
    });

    test(
      'Pair with no known interaction still carries limited-coverage notice (never a safety clearance)',
      () {
        UserMedicationModel med(String id, String name) => UserMedicationModel(
          id: id,
          userId: 'u1',
          name: name,
          strength: '',
          dosage: '1 Tablet',
          frequency: 'Daily',
          createdAt: DateTime.now(),
        );

        final warnings = clinicalService.checkInteractions([
          med('1', 'Glucophage 500mg'),
          med('2', 'Risek 20mg'),
        ]);
        expect(warnings.any((w) => w.contains('Severe Interaction')), isFalse);
        expect(
          warnings.any(
            (w) => w.contains('does NOT mean the combination is safe'),
          ),
          isTrue,
        );
      },
    );
  });
}
