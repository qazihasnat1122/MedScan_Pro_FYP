import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/features/prescriptions/prescription_review_screen.dart';
import 'package:medscan_mobile/features/prescriptions/prescription_upload_screen.dart';
import 'package:medscan_mobile/models/prescription_model.dart';
import 'package:medscan_mobile/models/reminder_model.dart';
import 'package:medscan_mobile/models/user_medication_model.dart';
import 'package:medscan_mobile/providers/auth_providers.dart';
import 'package:medscan_mobile/providers/medication_providers.dart';
import 'package:medscan_mobile/providers/scan_providers.dart';
import 'package:medscan_mobile/providers/storage_providers.dart';
import 'package:medscan_mobile/services/notification_service.dart';
import 'package:medscan_mobile/services/prescription_ai_service.dart';
import 'package:medscan_mobile/services/prescription_parser.dart';
import 'package:medscan_mobile/services/storage_service.dart';

/// Fake Firebase User for widget and repository tests.
class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory `MedicationRepository` for testing history saves, duplicate prevention,
/// per-user isolation, and optional reminder storage without live Firestore network calls.
class _InMemoryMedicationRepository implements MedicationRepository {
  final Map<String, PrescriptionModel> prescriptionsById = {};
  final Map<String, UserMedicationModel> medicationsById = {};
  final Map<String, ReminderModel> remindersById = {};
  bool shouldFailOnSavePrescription = false;
  int savePrescriptionAttempts = 0;

  @override
  Future<bool> addPrescription(PrescriptionModel p) async {
    savePrescriptionAttempts++;
    if (shouldFailOnSavePrescription) {
      throw Exception('Simulated Firebase network error');
    }
    if (p.userId.trim().isEmpty) {
      throw StateError(
        'Authenticated userId is required to save a prescription.',
      );
    }
    if (!p.isConfirmedByUser) {
      throw StateError(
        'Raw or unconfirmed prescription output cannot be saved to history.',
      );
    }
    if (p.id.trim().isNotEmpty && prescriptionsById.containsKey(p.id.trim())) {
      return false; // Duplicate prevented
    }
    final key = p.id.trim().isNotEmpty
        ? p.id.trim()
        : 'rx_${prescriptionsById.length + 1}';
    prescriptionsById[key] = p;
    return true;
  }

  List<PrescriptionModel> getPrescriptionsForUser(String uid) {
    return prescriptionsById.values.where((p) => p.userId == uid).toList();
  }

  @override
  Future<void> deletePrescription(
    PrescriptionModel p, {
    required String currentUserId,
    StorageService? storageService,
  }) async {
    if (currentUserId.trim().isEmpty || p.userId != currentUserId) {
      throw StateError(
        'Unauthorized: Cannot delete another user\'s prescription.',
      );
    }
    prescriptionsById.remove(p.id);
  }

  @override
  Future<void> removePrescriptionOriginalFile(
    PrescriptionModel p, {
    required String currentUserId,
    StorageService? storageService,
  }) async {
    if (currentUserId.trim().isEmpty || p.userId != currentUserId) {
      throw StateError(
        'Unauthorized: Cannot modify another user\'s prescription.',
      );
    }
    final existing = prescriptionsById[p.id];
    if (existing != null) {
      prescriptionsById[p.id] = PrescriptionModel(
        id: existing.id,
        userId: existing.userId,
        imagePath: '',
        extractedMedicines: existing.extractedMedicines,
        structuredMedicines: existing.structuredMedicines,
        prescriptionDate: existing.prescriptionDate,
        rawText: existing.rawText,
        mimeType: existing.mimeType,
        isConfirmedByUser: existing.isConfirmedByUser,
        uploadedAt: existing.uploadedAt,
      );
    }
  }

  @override
  Future<String> addMedication(UserMedicationModel med, {String? docId}) async {
    if (med.userId.trim().isEmpty) {
      throw StateError('Authenticated userId is required.');
    }
    final id = docId ?? med.id;
    medicationsById[id] = med;
    return id;
  }

  @override
  Future<void> addReminder(ReminderModel r, {String? docId}) async {
    if (r.userId.trim().isEmpty) {
      throw StateError('Authenticated userId is required.');
    }
    final id = docId ?? r.id;
    remindersById[id] = r;
  }

  @override
  Future<void> deleteMedication(String medId) async {
    medicationsById.remove(medId);
  }

  @override
  Future<void> updateMedicationReminders(
    String medId,
    List<String> reminderTimes,
  ) async {}
}

class _NoOpStorageService extends StorageService {
  @override
  Future<String> uploadPrescriptionImage({
    required String userId,
    required String localPath,
  }) async {
    return 'https://storage.medscan.test/prescriptions/$userId/rx.jpg';
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medscan_rx_test_');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 2.1 & 2.2 — File Validation & Mocked Gemini Extraction', () {
    test('Rejects empty, corrupt, and unsupported files gracefully', () async {
      final aiService = PrescriptionAiService(
        tokenProvider: () async => 'mock-id-token',
      );

      // 1. Empty file
      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.writeAsBytes(const <int>[]);
      await expectLater(
        () => aiService.validateAndPrepareFile(emptyFile),
        throwsA(isA<PrescriptionFileException>()),
      );

      // 2. Corrupt PDF (invalid header)
      final corruptPdf = File('${tempDir.path}/corrupt.pdf');
      await corruptPdf.writeAsBytes(<int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
      await expectLater(
        () => aiService.validateAndPrepareFile(corruptPdf),
        throwsA(
          isA<PrescriptionFileException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('corrupted'),
          ),
        ),
      );

      // 3. Unsupported format (.txt)
      final unsupportedFile = File('${tempDir.path}/notes.txt');
      await unsupportedFile.writeAsString('Hello prescription world');
      await expectLater(
        () => aiService.validateAndPrepareFile(unsupportedFile),
        throwsA(
          isA<PrescriptionFileException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('unsupported'),
          ),
        ),
      );
    });

    test(
      'Validates valid JPEG and multi-page PDF and extracts structured Gemini fields',
      () async {
        final validPdf = File('${tempDir.path}/rx_multipage.pdf');
        // %PDF-1.7 header
        await validPdf.writeAsBytes(<int>[
          0x25,
          0x50,
          0x44,
          0x46,
          0x2D,
          0x31,
          0x2E,
          0x37,
          0x0A,
          0x25,
          0xE2,
          0xE3,
        ]);

        Map<String, dynamic>? capturedRequestBody;
        String? capturedToken;

        final aiService = PrescriptionAiService(
          endpointUrl: 'https://example.com/extractPrescription',
          tokenProvider: () async => 'valid-firebase-id-token',
          transport:
              ({
                required Uri endpoint,
                required String idToken,
                required Map<String, dynamic> body,
              }) async {
                capturedToken = idToken;
                capturedRequestBody = body;
                return <String, dynamic>{
                  'rawText':
                      'Rx Date: 2026-10-20\n1. Augmentin (Amoxicillin/Clavulanate) 625mg Oral Tablet - 1 tablet Twice daily after meal for 5 days (Qty: 10 tablets) - Complete full antibiotic course.',
                  'prescriptionDate': '2026-10-20',
                  'medicines': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'medicineName': 'Amoxicillin + Clavulanic Acid',
                      'brand': 'Augmentin',
                      'strength': '625mg',
                      'dosageInstructions': '1 tablet',
                      'route': 'Oral Tablet',
                      'frequency': 'Twice daily',
                      'timing': 'After meal',
                      'duration': '5 days',
                      'durationDays': 5,
                      'quantity': '10 tablets',
                      'prescriptionDate': '2026-10-20',
                      'specialInstructions': 'Complete full antibiotic course',
                      'confidence': 'high',
                      'uncertainFields': <String>[],
                    },
                  ],
                };
              },
        );

        final prepared = await aiService.validateAndPrepareFile(
          validPdf,
          pdfPageCount: 2,
        );
        expect(prepared.isPdf, isTrue);
        expect(prepared.pageCount, equals(2));

        final result = await aiService.extractPrescription(prepared);
        expect(capturedToken, equals('valid-firebase-id-token'));
        expect(capturedRequestBody?['mimeType'], equals('application/pdf'));
        expect(result.prescriptionDate, equals('2026-10-20'));
        expect(result.medicines, hasLength(1));

        final med = result.medicines.first;
        expect(med.medicineName, equals('Amoxicillin + Clavulanic Acid'));
        expect(med.brand, equals('Augmentin'));
        expect(med.strength, equals('625mg'));
        expect(med.dosageInstructions, equals('1 tablet'));
        expect(med.route, equals('Oral Tablet'));
        expect(med.frequency, equals('Twice daily'));
        expect(med.duration, equals('5 days'));
        expect(med.durationDays, equals(5));
        expect(med.quantity, equals('10 tablets'));
        expect(med.prescriptionDate, equals('2026-10-20'));
        expect(
          med.specialInstructions,
          equals('Complete full antibiotic course'),
        );
        // Raw Gemini output is never pre-confirmed before user review
        expect(med.isConfirmed, isFalse);
      },
    );

    test(
      'Missing or unclear fields remain unknown and marked for review (never invented)',
      () {
        final item = PrescriptionMedicineItem.fromMap(<String, dynamic>{
          'medicineName': 'Cefixime',
          'brand': '',
          'strength': null, // Illegible on prescription
          'dosageInstructions': '',
          'route': 'Capsule',
          'frequency': 'unknown', // Illegible
          'duration': '', // Missing
          'quantity': '',
          'confidence': 'low',
          'uncertainFields': <String>['strength', 'frequency', 'duration'],
        });

        // Must NOT invent "500mg", "Twice daily", or "5 days"
        expect(item.medicineName, equals('Cefixime'));
        expect(item.strength, isEmpty);
        expect(item.frequency, isEmpty);
        expect(item.duration, isEmpty);
        expect(item.durationDays, equals(0));
        expect(item.isConfirmed, isFalse);
        expect(item.confidence, equals(FieldConfidence.low));
        expect(
          item.missingOrUncertainFields,
          containsAll(<String>['strength', 'frequency', 'duration']),
        );
      },
    );

    test(
      'Gemini backend setup / network errors surface honestly without faking results',
      () async {
        final validJpg = File('${tempDir.path}/rx.jpg');
        await validJpg.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

        final aiService = PrescriptionAiService(
          endpointUrl: 'https://example.com/extractPrescription',
          tokenProvider: () async => 'mock-token',
          transport:
              ({
                required Uri endpoint,
                required String idToken,
                required Map<String, dynamic> body,
              }) async {
                throw const PrescriptionExtractionException(
                  'Server configuration error: GEMINI_API_KEY secret is not configured on the backend.',
                  isSetupError: true,
                  statusCode: 503,
                );
              },
        );

        final prepared = await aiService.validateAndPrepareFile(validJpg);
        await expectLater(
          () => aiService.extractPrescription(prepared),
          throwsA(
            isA<PrescriptionExtractionException>()
                .having((e) => e.isSetupError, 'isSetupError', isTrue)
                .having((e) => e.statusCode, 'statusCode', equals(503)),
          ),
        );
      },
    );
  });

  group(
    'Phase 2.4, 2.5 & 2.6 — Consent Dialog, Review/Edit, History Save & Duplicate Prevention',
    () {
      testWidgets(
        'Shows explicit External AI Consent dialog before sending file to Gemini',
        (tester) async {
          tester.view.physicalSize = const Size(900, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          bool backendCalled = false;
          final mockAiService = PrescriptionAiService(
            endpointUrl: 'https://example.com/extractPrescription',
            tokenProvider: () async => 'mock-token',
            transport:
                ({
                  required Uri endpoint,
                  required String idToken,
                  required Map<String, dynamic> body,
                }) async {
                  backendCalled = true;
                  return <String, dynamic>{
                    'rawText': 'Panadol 500mg',
                    'prescriptionDate': '2026-10-22',
                    'medicines': <Map<String, dynamic>>[],
                  };
                },
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                prescriptionAiServiceProvider.overrideWithValue(mockAiService),
              ],
              child: MaterialApp(
                home: PrescriptionUploadScreen(
                  customImagePicker: (_) async =>
                      const SelectedPrescriptionFile(
                        path: 'mock_rx.jpg',
                        fileName: 'mock_rx.jpg',
                        mimeType: 'image/jpeg',
                        sizeBytes: 2048,
                        previewImagePaths: <String>[],
                      ),
                ),
              ),
            ),
          );

          // Pick image from gallery
          await tester.tap(find.byKey(const Key('pick_gallery_button')));
          await tester.pumpAndSettle();

          // Preview is shown; backend not called yet
          expect(
            find.byKey(const Key('extract_with_gemini_button')),
            findsOneWidget,
          );
          expect(backendCalled, isFalse);

          // Tap Extract -> Consent dialog must appear first
          await tester.tap(find.byKey(const Key('extract_with_gemini_button')));
          await tester.pumpAndSettle();
          expect(find.text('External AI Processing Consent'), findsOneWidget);
          expect(backendCalled, isFalse);

          // Cancel consent -> backend is NOT called
          await tester.tap(find.byKey(const Key('ai_consent_cancel_button')));
          await tester.pumpAndSettle();
          expect(backendCalled, isFalse);
        },
      );

      testWidgets(
        'Review screen highlights missing fields, allows editing & confirming, saves once without duplicates, and preserves screen on error',
        (tester) async {
          tester.view.physicalSize = const Size(900, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final fakeRepo = _InMemoryMedicationRepository();
          final unconfirmedItem = PrescriptionMedicineItem(
            id: 'item_1',
            medicineName: 'Amoxicillin',
            brand: '',
            strength: '', // Missing strength -> highlighted for review
            dosageInstructions: '1 capsule',
            route: 'Oral Capsule',
            frequency: 'Twice daily',
            duration: '5 days',
            durationDays: 5,
            uncertainFields: const ['strength'],
            confidence: FieldConfidence.low,
            isConfirmed: false,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authStateProvider.overrideWith(
                  (ref) => Stream<User?>.value(_FakeUser('user_alpha')),
                ),
                medicationRepositoryProvider.overrideWithValue(fakeRepo),
                storageServiceProvider.overrideWithValue(_NoOpStorageService()),
              ],
              child: MaterialApp(
                home: PrescriptionReviewScreen(
                  initialItems: <PrescriptionMedicineItem>[unconfirmedItem],
                  rawText: 'Rx Amoxicillin 1 cap BD x 5 days',
                  prescriptionDate: '2026-10-22',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Original prescription comparison section & missing field warning are visible
          expect(
            find.textContaining('Original Prescription for Comparison'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Strength: Unknown (Review)'),
            findsOneWidget,
          );

          // 2. Attempting to save before confirming is blocked (never saves raw unconfirmed output)
          await tester.tap(
            find.byKey(const Key('confirm_and_save_history_button')),
          );
          await tester.pumpAndSettle();
          expect(fakeRepo.prescriptionsById, isEmpty);

          // 3. Edit the item to fill missing strength and confirm
          final editBtn = find.byKey(const Key('edit_item_button_0'));
          await tester.ensureVisible(editBtn);
          await tester.tap(editBtn);
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('edit_strength_field')),
            '500mg',
          );
          await tester.tap(find.byKey(const Key('save_edited_item_button')));
          await tester.pumpAndSettle();

          expect(find.text('Strength: 500mg'), findsOneWidget);
          expect(find.text('Confirmed'), findsOneWidget);

          // 4. Simulate a Firebase error first: screen must NOT be lost
          fakeRepo.shouldFailOnSavePrescription = true;
          await tester.tap(
            find.byKey(const Key('confirm_and_save_history_button')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('review_save_error_banner')),
            findsOneWidget,
          );
          expect(
            find.text('Amoxicillin'),
            findsOneWidget,
          ); // Review screen still intact

          // 5. Retry when network recovers -> saves to user history
          fakeRepo.shouldFailOnSavePrescription = false;
          await tester.tap(
            find.byKey(const Key('confirm_and_save_history_button')),
          );
          await tester.pumpAndSettle();
          expect(fakeRepo.prescriptionsById.length, equals(1));
          expect(
            fakeRepo.prescriptionsById.values.first.userId,
            equals('user_alpha'),
          );

          // 6. Repeated tap on save does NOT create a duplicate record
          await tester.tap(
            find.byKey(const Key('confirm_and_save_history_button')),
          );
          await tester.pumpAndSettle();
          expect(fakeRepo.prescriptionsById.length, equals(1));
        },
      );
    },
  );

  group(
    'Phase 2.7, 2.8 & Phase 3 — Optional Reminders, PRN Safety, Permissions & User Isolation',
    () {
      test(
        'PRN ("as needed") and tapering/ambiguous schedules are detected and not auto-scheduled',
        () {
          final prnItem = PrescriptionMedicineItem.fromMap(<String, dynamic>{
            'medicineName': 'Paracetamol',
            'strength': '500mg',
            'frequency': 'PRN (As needed for fever)',
            'duration': '3 days',
          });
          expect(prnItem.isPrnOrAsNeeded, isTrue);
          expect(prnItem.expectedDailyDoseCount, isNull);

          final taperingItem =
              PrescriptionMedicineItem.fromMap(<String, dynamic>{
                'medicineName': 'Prednisolone',
                'strength': '5mg',
                'frequency': 'Taper dose gradually over 2 weeks',
                'duration': '14 days',
              });
          expect(taperingItem.isAmbiguousOrTaperingSchedule, isTrue);
          expect(taperingItem.expectedDailyDoseCount, isNull);

          final twiceDailyItem =
              PrescriptionMedicineItem.fromMap(<String, dynamic>{
                'medicineName': 'Metformin',
                'strength': '500mg',
                'frequency': 'Twice daily',
                'duration': '30 days',
              });
          expect(twiceDailyItem.isPrnOrAsNeeded, isFalse);
          expect(twiceDailyItem.expectedDailyDoseCount, equals(2));
        },
      );

      testWidgets(
        'Reminder setup requires user to fill missing clock times for "Twice daily" and handles denied notification permissions',
        (tester) async {
          tester.view.physicalSize = const Size(900, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final fakeRepo = _InMemoryMedicationRepository();
          bool allowNotifications = false;
          final scheduledCalls = <int>[];

          final testableNotifications = NotificationService.testable(
            permissionRequester: () async => allowNotifications,
            scheduleOverride: (id, title, body, scheduledTime) async {
              scheduledCalls.add(id);
              return true;
            },
          );

          final confirmedItem = PrescriptionMedicineItem(
            id: 'met_1',
            medicineName: 'Metformin',
            strength: '500mg',
            dosageInstructions: '1 tablet',
            route: 'Tablet',
            frequency: 'Twice daily',
            timing: 'After meal',
            duration: '30 days',
            durationDays: 30,
            confidence: FieldConfidence.high,
            isConfirmed: true,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authStateProvider.overrideWith(
                  (ref) => Stream<User?>.value(_FakeUser('user_alpha')),
                ),
                medicationRepositoryProvider.overrideWithValue(fakeRepo),
                notificationServiceProvider.overrideWithValue(
                  testableNotifications,
                ),
                storageServiceProvider.overrideWithValue(_NoOpStorageService()),
              ],
              child: MaterialApp(
                home: PrescriptionReviewScreen(
                  initialItems: <PrescriptionMedicineItem>[confirmedItem],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open separate optional reminder sheet
          await tester.tap(
            find.byKey(const Key('set_optional_reminders_button')),
          );
          await tester.pumpAndSettle();

          // 1. Try confirming without selecting clock times -> blocked because "Twice daily" does NOT assume clock times!
          final confirmBtn = find.byKey(
            const Key('confirm_schedule_reminders_button'),
          );
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Please select exact clock time(s)'),
            findsOneWidget,
          );
          expect(scheduledCalls, isEmpty);

          // 2. Select both clock times explicitly using preset chips
          final preset0 = find.byKey(const Key('preset_time_met_1_0_08:00 AM'));
          await tester.ensureVisible(preset0);
          await tester.tap(preset0);
          await tester.pumpAndSettle();

          final preset1 = find.byKey(const Key('preset_time_met_1_1_08:00 PM'));
          await tester.ensureVisible(preset1);
          await tester.tap(preset1);
          await tester.pumpAndSettle();

          // 3. With notification permissions denied (`allowNotifications = false`), scheduleReminder returns false
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Notification permission was denied'),
            findsOneWidget,
          );
          expect(scheduledCalls, isEmpty);
          expect(fakeRepo.remindersById, isEmpty);

          // 4. Grant notification permissions and confirm -> alarms are scheduled without duplicates
          allowNotifications = true;
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(scheduledCalls.length, equals(2));
          expect(fakeRepo.remindersById.length, equals(2));
        },
      );

      test(
        'Per-user access control: users can read and delete only their own prescriptions',
        () async {
          final repo = _InMemoryMedicationRepository();

          final userAPrescription = PrescriptionModel(
            id: 'rx_user_a',
            userId: 'user_a',
            imagePath:
                'https://storage.medscan.test/prescriptions/user_a/1.jpg',
            extractedMedicines: const ['Panadol 500mg'],
            isConfirmedByUser: true,
            uploadedAt: DateTime.now(),
          );
          await repo.addPrescription(userAPrescription);

          // User B cannot see User A's prescriptions
          expect(repo.getPrescriptionsForUser('user_b'), isEmpty);
          expect(repo.getPrescriptionsForUser('user_a'), hasLength(1));

          // User B cannot delete User A's prescription or file
          await expectLater(
            () => repo.deletePrescription(
              userAPrescription,
              currentUserId: 'user_b',
            ),
            throwsA(isA<StateError>()),
          );
          await expectLater(
            () => repo.removePrescriptionOriginalFile(
              userAPrescription,
              currentUserId: 'user_b',
            ),
            throwsA(isA<StateError>()),
          );

          // User A can delete their own original file and record
          await repo.removePrescriptionOriginalFile(
            userAPrescription,
            currentUserId: 'user_a',
          );
          expect(repo.prescriptionsById['rx_user_a']?.imagePath, isEmpty);

          await repo.deletePrescription(
            userAPrescription,
            currentUserId: 'user_a',
          );
          expect(repo.getPrescriptionsForUser('user_a'), isEmpty);
        },
      );
    },
  );
}
