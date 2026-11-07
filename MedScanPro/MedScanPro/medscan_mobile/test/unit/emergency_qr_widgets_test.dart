import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:medscan_mobile/models/emergency_profile_model.dart';
import 'package:medscan_mobile/providers/safety_providers.dart';
import 'package:medscan_mobile/features/emergency/emergency_qr_screen.dart';
import 'package:medscan_mobile/features/emergency/widgets/emergency_profile_display_sheet.dart';
import 'package:medscan_mobile/services/emergency_qr_payload_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('C. Emergency QR Widget & Display Tests', () {
    testWidgets('Displays QR Code when valid sharing profile is available', (
      WidgetTester tester,
    ) async {
      final sampleProfile = EmergencyProfileModel(
        userId: 'user_active',
        name: 'Sara Ahmed',
        age: 34,
        bloodGroup: 'A+',
        allergiesList: const ['Penicillin'],
        medicalConditionsList: const ['Asthma'],
        currentMedicines: '',
        emergencyContact: '+92 300 1234567',
        isSharingEnabled: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyProfileProvider.overrideWith(
              (ref) => Stream.value(sampleProfile),
            ),
          ],
          child: const MaterialApp(
            home: EmergencyQrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // QrImageView must be visible with sufficient dimensions
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('Blood Group: A+'), findsOneWidget);
      expect(find.text('+92 300 1234567'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('Asthma'), findsOneWidget);

      // Verify scan action button is present for responders
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    });

    testWidgets('Displays honest disabled state when sharing is disabled', (
      WidgetTester tester,
    ) async {
      final disabledProfile = EmergencyProfileModel(
        userId: 'user_disabled',
        name: 'Disabled User',
        age: 30,
        bloodGroup: 'B+',
        allergiesList: const [],
        medicalConditionsList: const [],
        currentMedicines: '',
        emergencyContact: '',
        isSharingEnabled: false, // Disabled
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyProfileProvider.overrideWith(
              (ref) => Stream.value(disabledProfile),
            ),
          ],
          child: const MaterialApp(
            home: EmergencyQrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Emergency QR Sharing Disabled'), findsOneWidget);
      expect(find.text('Configure Health Profile'), findsOneWidget);
      expect(find.text('Scan Another Patient Emergency QR'), findsOneWidget);
    });

    testWidgets('Displays loading indicator while loading profile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyProfileProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: const MaterialApp(
            home: EmergencyQrScreen(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Scanned EmergencyProfileDisplaySheet accurately renders patient data', (
      WidgetTester tester,
    ) async {
      const scannedData = EmergencyQrData(
        schemaVersion: 1,
        displayName: 'Kamran Akmal',
        age: 41,
        bloodGroup: 'O+',
        allergies: ['Aspirin', 'Iodine'],
        medicalConditions: ['Coronary Artery Disease'],
        emergencyContacts: ['+92 321 9998877'],
        isUserReported: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmergencyProfileDisplaySheet(data: scannedData),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY MEDICAL ID'), findsOneWidget);
      expect(find.text('Kamran Akmal'), findsOneWidget);
      expect(find.text('Age: 41'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('+92 321 9998877'), findsOneWidget);
      expect(find.text('Aspirin'), findsOneWidget);
      expect(find.text('Iodine'), findsOneWidget);
      expect(find.text('Coronary Artery Disease'), findsOneWidget);
      expect(find.text('Done / Dismiss'), findsOneWidget);
    });
  });

  group('D. Regression & Privacy Isolation Tests', () {
    test('Local cache persists profile and restores instantly', () async {
      final service = SafetyService();
      final profile = EmergencyProfileModel(
        userId: 'patient_offline_1',
        name: 'Offline Patient',
        age: 28,
        bloodGroup: 'AB+',
        allergiesList: const ['Peanuts'],
        medicalConditionsList: const ['Asthma'],
        currentMedicines: 'Albuterol',
        emergencyContact: '+92 300 4443322',
        isSharingEnabled: true,
      );

      await service.saveLocalCacheOnly(profile);

      final restored = await service.getLocalEmergencyProfile('patient_offline_1');
      expect(restored, isNotNull);
      expect(restored!.name, 'Offline Patient');
      expect(restored.bloodGroup, 'AB+');
      expect(restored.allergiesList, ['Peanuts']);
      expect(restored.medicalConditionsList, ['Asthma']);
      expect(restored.isSharingEnabled, isTrue);
    });

    test('User isolation: scanned stranger profile does not overwrite local user profile', () async {
      final service = SafetyService();

      // Local user has their own profile
      final myProfile = EmergencyProfileModel(
        userId: 'my_own_user_id',
        name: 'My Real Name',
        age: 30,
        bloodGroup: 'A+',
        allergiesList: const ['Penicillin'],
        medicalConditionsList: const ['Hypertension'],
        currentMedicines: '',
        emergencyContact: '+92 300 0001111',
        isSharingEnabled: true,
      );
      await service.saveLocalCacheOnly(myProfile);

      // Now user scans a stranger's QR code
      const strangerPayload = '''
      {
        "schemaVersion": 1,
        "type": "medscan_emergency",
        "profile": {
          "displayName": "Stranger Patient",
          "bloodGroup": "O-",
          "allergies": ["Latex"],
          "medicalConditions": ["Diabetes"],
          "emergencyContacts": ["+92 345 9999999"]
        }
      }
      ''';

      final decodeResult = EmergencyQrPayloadService.decodePayload(strangerPayload);
      expect(decodeResult.status, EmergencyQrDecodeStatus.success);
      expect(decodeResult.data!.displayName, 'Stranger Patient');

      // Verify that my local profile remains untouched
      final restoredMyProfile = await service.getLocalEmergencyProfile('my_own_user_id');
      expect(restoredMyProfile!.name, 'My Real Name');
      expect(restoredMyProfile.bloodGroup, 'A+');
      expect(restoredMyProfile.displayName, isNot('Stranger Patient'));
    });
  });
}

extension on EmergencyProfileModel {
  String get displayName => name;
}
