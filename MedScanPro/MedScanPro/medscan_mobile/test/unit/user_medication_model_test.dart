import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/models/user_medication_model.dart';

void main() {
  group('UserMedicationModel Unit Tests', () {
    test(
      'Correctly serializes to Map and deserializes from Map with all rich fields',
      () {
        final now = DateTime(2026, 9, 27, 10, 30);
        final model = UserMedicationModel(
          id: 'med_123',
          userId: 'user_456',
          name: 'Panadol Extra',
          genericName: 'Paracetamol + Caffeine',
          strength: '500mg/65mg',
          form: 'Tablet',
          unit: 'mg',
          category: 'Pain Relief',
          dosage: '1 Tablet',
          frequency: 'Twice Daily',
          mealInstruction: 'After Meal',
          stockCount: 40,
          reminderTimes: ['08:00 AM', '08:00 PM'],
          repeatDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          createdAt: now,
        );

        final map = model.toMap();

        expect(map['userId'], 'user_456');
        expect(map['name'], 'Panadol Extra');
        expect(map['genericName'], 'Paracetamol + Caffeine');
        expect(map['strength'], '500mg/65mg');
        expect(map['form'], 'Tablet');
        expect(map['unit'], 'mg');
        expect(map['category'], 'Pain Relief');
        expect(map['dosage'], '1 Tablet');
        expect(map['frequency'], 'Twice Daily');
        expect(map['mealInstruction'], 'After Meal');
        expect(map['stockCount'], 40);
        expect(map['reminderTimes'], ['08:00 AM', '08:00 PM']);
        expect(map['repeatDays'], ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        expect(map['createdAt'], now.toIso8601String());

        final fromMapModel = UserMedicationModel.fromMap(map, 'med_123');
        expect(fromMapModel.id, 'med_123');
        expect(fromMapModel.userId, 'user_456');
        expect(fromMapModel.name, 'Panadol Extra');
        expect(fromMapModel.genericName, 'Paracetamol + Caffeine');
        expect(fromMapModel.strength, '500mg/65mg');
        expect(fromMapModel.form, 'Tablet');
        expect(fromMapModel.unit, 'mg');
        expect(fromMapModel.category, 'Pain Relief');
        expect(fromMapModel.stockCount, 40);
        expect(fromMapModel.reminderTimes.length, 2);
        expect(fromMapModel.reminderTimes[0], '08:00 AM');
        expect(fromMapModel.reminderTimes[1], '08:00 PM');
        expect(fromMapModel.repeatDays.length, 5);
        expect(fromMapModel.createdAt, now);
      },
    );

    test(
      'Gracefully uses fallback defaults when optional fields are null or missing',
      () {
        final minimalMap = {
          'userId': 'user_999',
          'name': 'Augmentin',
          'strength': '625mg',
          'dosage': '1 Tablet',
          'frequency': 'Twice daily',
        };

        final parsed = UserMedicationModel.fromMap(minimalMap, 'doc_abc');

        expect(parsed.id, 'doc_abc');
        expect(parsed.name, 'Augmentin');
        expect(parsed.form, 'Tablet');
        expect(parsed.unit, 'mg');
        expect(parsed.category, 'Pain Relief');
        expect(parsed.mealInstruction, 'After Meal');
        expect(parsed.stockCount, 30);
        expect(parsed.reminderTimes, isEmpty);
        expect(parsed.repeatDays, contains('Mon'));
      },
    );
  });
}
