import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/models/emergency_profile_model.dart';

void main() {
  group('EmergencyProfileModel Unit Tests', () {
    test('Serializes to Map and deserializes accurately', () {
      final profile = EmergencyProfileModel(
        userId: 'user_em_1',
        name: 'Ahmad Khan',
        age: 32,
        bloodGroup: 'B+',
        allergiesList: const ['Penicillin', 'Peanuts'],
        medicalConditionsList: const ['Hypertension'],
        currentMedicines: 'Glucophage 500mg',
        emergencyContact: '+92 300 1234567',
        isSharingEnabled: true,
      );

      final map = profile.toMap();
      expect(map['userId'], 'user_em_1');
      expect(map['name'], 'Ahmad Khan');
      expect(map['bloodGroup'], 'B+');
      expect(map['allergies'], 'Penicillin, Peanuts');
      expect(map['isSharingEnabled'], true);

      final fromMap = EmergencyProfileModel.fromMap(map);
      expect(fromMap.userId, 'user_em_1');
      expect(fromMap.name, 'Ahmad Khan');
      expect(fromMap.age, 32);
      expect(fromMap.bloodGroup, 'B+');
      expect(fromMap.isSharingEnabled, true);
    });
  });
}
