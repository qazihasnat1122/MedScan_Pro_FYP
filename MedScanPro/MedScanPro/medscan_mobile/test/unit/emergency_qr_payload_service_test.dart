import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/models/emergency_profile_model.dart';
import 'package:medscan_mobile/services/emergency_qr_payload_service.dart';

void main() {
  group('A & B. Emergency QR Payload & Model Serialization Tests', () {
    test('Encodes and decodes valid profile with all supported fields', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_42',
        name: 'Fatima Ali',
        age: 29,
        bloodGroup: 'O+',
        allergiesList: const ['Penicillin', 'Sulfa Drugs', 'Iodine'],
        medicalConditionsList: const ['Asthma', 'Hypertension'],
        currentMedicines: 'Ventolin Inhaler',
        emergencyContact: '+92 300 9876543',
        isSharingEnabled: true,
        shareAllergiesInQr: true,
        shareConditionsInQr: true,
        shareContactInQr: true,
      );

      final payload = EmergencyQrPayloadService.encodePayload(profile);
      expect(payload, isNotEmpty);

      // Verify payload is valid JSON and contains required schema tags
      final Map<String, dynamic> jsonMap = jsonDecode(payload);
      expect(jsonMap['type'], 'medscan_emergency');
      expect(jsonMap['schemaVersion'], 1);

      // Verify profile contents
      final profileMap = jsonMap['profile'] as Map<String, dynamic>;
      expect(profileMap['displayName'], 'Fatima Ali');
      expect(profileMap['age'], 29);
      expect(profileMap['bloodGroup'], 'O+');
      expect(profileMap['allergies'], ['Penicillin', 'Sulfa Drugs', 'Iodine']);
      expect(profileMap['medicalConditions'], ['Asthma', 'Hypertension']);
      expect(profileMap['emergencyContacts'], ['+92 300 9876543']);
      expect(profileMap['isUserReported'], true);

      // Verify no sensitive internal fields leak into QR payload
      expect(profileMap.containsKey('userId'), isFalse);
      expect(profileMap.containsKey('token'), isFalse);
      expect(profileMap.containsKey('password'), isFalse);
      expect(profileMap.containsKey('currentMedicines'), isFalse);

      // Decode using the shared service
      final decodeResult = EmergencyQrPayloadService.decodePayload(payload);
      expect(decodeResult.status, EmergencyQrDecodeStatus.success);
      expect(decodeResult.message, 'Emergency profile loaded.');

      final data = decodeResult.data!;
      expect(data.displayName, 'Fatima Ali');
      expect(data.age, 29);
      expect(data.bloodGroup, 'O+');
      expect(data.allergies, ['Penicillin', 'Sulfa Drugs', 'Iodine']);
      expect(data.medicalConditions, ['Asthma', 'Hypertension']);
      expect(data.emergencyContacts, ['+92 300 9876543']);
      expect(data.isUserReported, isTrue);
    });

    test('Round-trip preserves multiple allergies and multiple medical conditions', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_multi',
        name: 'Zainab Bibi',
        age: 45,
        bloodGroup: 'AB-',
        allergiesList: const ['Latex', 'Peanuts', 'Aspirin', 'Ciprofloxacin'],
        medicalConditionsList: const ['Type 2 Diabetes', 'Epilepsy', 'Thyroid Disorder'],
        currentMedicines: '',
        emergencyContact: '+92 321 5551234',
        isSharingEnabled: true,
      );

      final payload = profile.generateQrPayload();
      final result = EmergencyQrPayloadService.decodePayload(payload);

      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.allergies.length, 4);
      expect(result.data!.allergies, contains('Latex'));
      expect(result.data!.allergies, contains('Ciprofloxacin'));
      expect(result.data!.medicalConditions.length, 3);
      expect(result.data!.medicalConditions, contains('Epilepsy'));
    });

    test('Encodes and decodes Unicode and Urdu text accurately', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_urdu',
        name: 'محمد عثمان',
        age: 52,
        bloodGroup: 'A+',
        allergiesList: const ['پینسلین', 'مونگ پھلی'],
        medicalConditionsList: const ['ذیابیطس', 'بلڈ پریشر'],
        currentMedicines: '',
        emergencyContact: '+92 333 4445556',
        isSharingEnabled: true,
      );

      final payload = profile.generateQrPayload();
      expect(payload, contains('محمد عثمان'));
      expect(payload, contains('پینسلین'));
      expect(payload, contains('ذیابیطس'));

      final result = EmergencyQrPayloadService.decodePayload(payload);
      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.displayName, 'محمد عثمان');
      expect(result.data!.allergies, ['پینسلین', 'مونگ پھلی']);
      expect(result.data!.medicalConditions, ['ذیابیطس', 'بلڈ پریشر']);
    });

    test('Handles special characters and escaped JSON values safely', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_chars',
        name: 'John "Doc" O\'Connor <Dr. & Paramedic>',
        age: 38,
        bloodGroup: 'B-',
        allergiesList: const ['NSAIDs / "Ibuprofen"', 'Shellfish & Crab (Severe)'],
        medicalConditionsList: const ['Post-OP: Stent (2025)\nRef: #9948'],
        currentMedicines: '',
        emergencyContact: '+1 (555) 234-5678 ext. #101',
        isSharingEnabled: true,
      );

      final payload = profile.generateQrPayload();
      final result = EmergencyQrPayloadService.decodePayload(payload);

      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.displayName, 'John "Doc" O\'Connor <Dr. & Paramedic>');
      expect(result.data!.allergies, contains('NSAIDs / "Ibuprofen"'));
      expect(result.data!.allergies, contains('Shellfish & Crab (Severe)'));
      expect(result.data!.medicalConditions, contains('Post-OP: Stent (2025)\nRef: #9948'));
      expect(result.data!.emergencyContacts, contains('+1 (555) 234-5678 ext. #101'));
    });

    test('Privacy filtering: respects individual exclusion checkboxes', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_priv',
        name: 'Private Patient',
        age: 40,
        bloodGroup: 'O-',
        allergiesList: const ['Penicillin'],
        medicalConditionsList: const ['Epilepsy'],
        currentMedicines: '',
        emergencyContact: '+92 300 1112223',
        isSharingEnabled: true,
        shareAllergiesInQr: false, // User deselected allergies in QR
        shareConditionsInQr: false, // User deselected conditions in QR
        shareContactInQr: true,
      );

      final payload = profile.generateQrPayload();
      final Map<String, dynamic> jsonMap = jsonDecode(payload);
      final profileMap = jsonMap['profile'] as Map<String, dynamic>;

      expect(profileMap.containsKey('allergies'), isFalse);
      expect(profileMap.containsKey('medicalConditions'), isFalse);
      expect(profileMap.containsKey('emergencyContacts'), isTrue);

      final result = EmergencyQrPayloadService.decodePayload(payload);
      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.allergies, isEmpty);
      expect(result.data!.medicalConditions, isEmpty);
      expect(result.data!.emergencyContacts, ['+92 300 1112223']);
    });

    test('Master sharing disabled produces empty payload', () {
      final profile = EmergencyProfileModel(
        userId: 'patient_disabled',
        name: 'Disabled User',
        age: 30,
        bloodGroup: 'A+',
        allergiesList: const ['Aspirin'],
        medicalConditionsList: const ['Asthma'],
        currentMedicines: '',
        emergencyContact: '+92 300 0000000',
        isSharingEnabled: false, // Master toggle OFF
      );

      final payload = profile.generateQrPayload();
      expect(payload, isEmpty);

      final result = EmergencyQrPayloadService.decodePayload(payload);
      expect(result.status, EmergencyQrDecodeStatus.invalidCode);
    });

    test('Missing optional fields and null values are handled gracefully', () {
      const minimalJson = '''
      {
        "schemaVersion": 1,
        "type": "medscan_emergency",
        "profile": {
          "displayName": "Minimal User",
          "bloodGroup": "AB+",
          "allergies": null,
          "medicalConditions": null
        }
      }
      ''';

      final result = EmergencyQrPayloadService.decodePayload(minimalJson);
      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.displayName, 'Minimal User');
      expect(result.data!.bloodGroup, 'AB+');
      expect(result.data!.age, isNull);
      expect(result.data!.allergies, isEmpty);
      expect(result.data!.medicalConditions, isEmpty);
      expect(result.data!.emergencyContacts, isEmpty);
    });

    test('Returns emptyProfile status when profile contains no medical information', () {
      const emptyJson = '''
      {
        "schemaVersion": 1,
        "type": "medscan_emergency",
        "profile": {
          "displayName": "",
          "bloodGroup": "",
          "allergies": [],
          "medicalConditions": [],
          "emergencyContacts": []
        }
      }
      ''';

      final result = EmergencyQrPayloadService.decodePayload(emptyJson);
      expect(result.status, EmergencyQrDecodeStatus.emptyProfile);
      expect(result.message, 'No emergency information is available in this QR code.');
    });

    test('Returns unsupportedVersion for higher schema version', () {
      const futureVersionJson = '''
      {
        "schemaVersion": 99,
        "type": "medscan_emergency",
        "profile": {
          "displayName": "Future Patient",
          "bloodGroup": "O+"
        }
      }
      ''';

      final result = EmergencyQrPayloadService.decodePayload(futureVersionJson);
      expect(result.status, EmergencyQrDecodeStatus.unsupportedVersion);
      expect(result.message, 'This QR code uses an unsupported format.');
    });

    test('Returns invalidCode for wrong payload type', () {
      const wrongTypeJson = '''
      {
        "schemaVersion": 1,
        "type": "random_payload",
        "profile": {
          "name": "Wrong Type"
        }
      }
      ''';

      final result = EmergencyQrPayloadService.decodePayload(wrongTypeJson);
      expect(result.status, EmergencyQrDecodeStatus.invalidCode);
      expect(result.message, 'This QR code is not a valid MedScan Pro emergency code.');
    });

    test('Returns invalidCode for malformed JSON or arbitrary text', () {
      expect(
        EmergencyQrPayloadService.decodePayload('not json and not emergency').status,
        EmergencyQrDecodeStatus.invalidCode,
      );

      expect(
        EmergencyQrPayloadService.decodePayload('{broken json').status,
        EmergencyQrDecodeStatus.invalidCode,
      );

      expect(
        EmergencyQrPayloadService.decodePayload(null).status,
        EmergencyQrDecodeStatus.invalidCode,
      );
    });

    test('Backward compatibility: accurately parses legacy plain text MedScan payloads', () {
      const legacyPayload = '''MEDSCAN PRO EMERGENCY MEDICAL ID
Name: Tariq Mehmood
Age: 61
Blood Group: O-
Emergency Contact: +92 300 7654321
Allergies: Penicillin, Codeine
Conditions: Coronary Artery Disease, Hypertension
Status: User-Reported Emergency Info''';

      final result = EmergencyQrPayloadService.decodePayload(legacyPayload);
      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.message, 'Emergency profile loaded.');

      final data = result.data!;
      expect(data.schemaVersion, 0); // Legacy version marker
      expect(data.displayName, 'Tariq Mehmood');
      expect(data.age, 61);
      expect(data.bloodGroup, 'O-');
      expect(data.emergencyContacts, ['+92 300 7654321']);
      expect(data.allergies, ['Penicillin', 'Codeine']);
      expect(data.medicalConditions, ['Coronary Artery Disease', 'Hypertension']);
      expect(data.isUserReported, isTrue);
    });

    test('Field type robustness: handles comma-separated string for allergies in JSON', () {
      const stringAllergiesJson = '''
      {
        "schemaVersion": 1,
        "type": "medscan_emergency",
        "profile": {
          "displayName": "String Allergies Patient",
          "bloodGroup": "B+",
          "allergies": "Sulfa Drugs, Peanuts, Eggs",
          "medicalConditions": "Asthma",
          "emergencyContact": "+92 300 1231234"
        }
      }
      ''';

      final result = EmergencyQrPayloadService.decodePayload(stringAllergiesJson);
      expect(result.status, EmergencyQrDecodeStatus.success);
      expect(result.data!.allergies, ['Sulfa Drugs', 'Peanuts', 'Eggs']);
      expect(result.data!.medicalConditions, ['Asthma']);
      expect(result.data!.emergencyContacts, ['+92 300 1231234']);
    });
  });
}
