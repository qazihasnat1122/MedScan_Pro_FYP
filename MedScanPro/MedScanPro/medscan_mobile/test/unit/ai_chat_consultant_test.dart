import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/models/emergency_profile_model.dart';
import 'package:medscan_mobile/models/user_medication_model.dart';
import 'package:medscan_mobile/services/ai_rag_service.dart';
import 'package:medscan_mobile/services/gemini_api_config.dart';

void main() {
  group('Health & Medicine Information Assistant (Phase 1–5 Comprehensive)', () {
    setUp(() {
      GeminiApiKeyProvider.resetForTesting();
    });

    tearDown(() {
      GeminiApiKeyProvider.resetForTesting();
    });

    test('1 & 2. Cloud LLM integration parses OpenAI-compatible chat completion payload', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final service = AiRagService(
        transport: ({required endpoint, required headers, required body}) async {
          capturedUri = endpoint;
          capturedHeaders = headers;
          capturedBody = body;
          return {
            'id': 'chatcmpl-123',
            'object': 'chat.completion',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content':
                      'Panadol contains paracetamol (acetaminophen). It is commonly used to treat mild to moderate pain and reduce fever. Common precautions: do not exceed 4,000mg in 24 hours to protect the liver.',
                },
                'finish_reason': 'stop',
              },
            ],
          };
        },
      );

      GeminiApiKeyProvider.setApiKey('sk-test_openai_key_1234567890');

      final result = await service.queryConsultantDetailed(
        userQuery: 'What is Panadol used for and what are its precautions?',
        activeMeds: const [],
      );

      expect(result.isFromCloudLlm, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.text, contains('Panadol contains paracetamol'));
      expect(result.text, contains('4,000mg'));
      expect(capturedUri!.path, contains('chat/completions'));
      expect(capturedHeaders!['Authorization'], contains('Bearer sk-test_openai_key'));
      expect(capturedBody!['model'], equals('gpt-4o-mini'));
      expect(capturedBody!['messages'], isNotEmpty);
    });

    test('3. Medicine interaction questions: Injects verified clinical interaction alerts into context', () async {
      String? sentSystemPrompt;

      final service = AiRagService(
        transport: ({required endpoint, required headers, required body}) async {
          final messages = body['messages'] as List<dynamic>;
          sentSystemPrompt = messages[0]['content'].toString();
          return {
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Taking Aspirin and Warfarin together poses a severe bleeding risk.',
                },
              },
            ],
          };
        },
      );

      GeminiApiKeyProvider.setApiKey('sk-valid_test_key');

      final activeMeds = [
        UserMedicationModel(
          id: '1',
          userId: 'u1',
          name: 'Disprin',
          dosage: '1 tablet',
          frequency: 'Daily',
          strength: '300mg',
          mealInstruction: 'After food',
          createdAt: DateTime.now(),
        ),
        UserMedicationModel(
          id: '2',
          userId: 'u1',
          name: 'Warfarin',
          dosage: '5mg',
          frequency: 'Daily',
          strength: '5mg',
          mealInstruction: 'Evening',
          createdAt: DateTime.now(),
        ),
      ];

      final result = await service.queryConsultantDetailed(
        userQuery: 'Can I take these two medicines together?',
        activeMeds: activeMeds,
      );

      expect(sentSystemPrompt, contains('Severe Interaction: Aspirin + Warfarin'));
      expect(result.text, contains('severe bleeding risk'));
    });

    test('4. Unclear medicine names: Does not guess and admits uncertainty', () async {
      final service = AiRagService();
      GeminiApiKeyProvider.resetForTesting();

      final answer = await service.queryClinicalRag(
        userQuery: 'How much Xylophantozine 900mg should I take?',
        activeMeds: const [],
      );

      expect(answer, contains('will not guess'));
      expect(answer, contains('not medical advice'));
    });

    test('5. Unreadable prescriptions: Directs user to clinician/pharmacist and warns against guessing', () async {
      final service = AiRagService();
      GeminiApiKeyProvider.resetForTesting();

      final answer = await service.queryClinicalRag(
        userQuery: 'The prescription handwriting is unclear and illegible. What is the dose?',
        activeMeds: const [],
      );

      expect(answer, contains('Never guess an unclear handwriting'));
      expect(answer, contains('registered pharmacist or request your prescribing physician'));
    });

    test('6. Supports multi-turn conversation history for English, Urdu, and Roman Urdu follow-ups', () async {
      List<dynamic>? capturedMessages;

      final service = AiRagService(
        transport: ({required endpoint, required headers, required body}) async {
          capturedMessages = body['messages'] as List<dynamic>;
          return {
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Haan, aap Glucophage khana khanay kay foran baad le saktay hain.',
                },
              },
            ],
          };
        },
      );

      GeminiApiKeyProvider.setApiKey('sk-multiturn_key');

      final history = [
        {'role': 'user', 'content': 'Glucophage kab leni chahiye?'},
        {'role': 'assistant', 'content': 'Glucophage khana khanay kay sath leni chahiye.'},
      ];

      final result = await service.queryConsultantDetailed(
        userQuery: 'Kya khana khatam hotay hi le sakte hain?',
        activeMeds: const [],
        conversationHistory: history,
      );

      expect(result.isFromCloudLlm, isTrue);
      expect(capturedMessages!.length, equals(4)); // system + 2 history + 1 new query
      expect(capturedMessages![1]['content'], equals('Glucophage kab leni chahiye?'));
      expect(capturedMessages![3]['content'], equals('Kya khana khatam hotay hi le sakte hain?'));
      expect(result.text, contains('foran baad'));
    });

    test('7. Emergency symptoms trigger immediate emergency medical instructions', () async {
      final service = AiRagService();
      GeminiApiKeyProvider.resetForTesting();

      final answer = await service.queryClinicalRag(
        userQuery: 'Patient has severe chest pain, shortness of breath and face drooping!',
        activeMeds: const [],
      );

      expect(answer, contains('EMERGENCY MEDICAL ALERT'));
      expect(answer, contains('Call emergency medical services immediately (1122 in Pakistan)'));
      expect(answer, contains('cannot provide emergency medical care'));
    });

    test('8. Missing or unavailable medical data: States limitation without fabricating info', () async {
      final service = AiRagService();
      GeminiApiKeyProvider.resetForTesting();

      final answer = await service.queryClinicalRag(
        userQuery: 'What is the price of rare herbal tree bark?',
        activeMeds: const [],
      );

      expect(answer, contains('will not guess'));
      expect(answer, contains('Ask your pharmacist or doctor'));
    });

    test('9 & 10. HTTP 429, timeout and server errors fall back safely to clinical knowledge', () async {
      final service = AiRagService(
        transport: ({required endpoint, required headers, required body}) async {
          throw const HttpException('AI service error (HTTP 429): Quota exhausted');
        },
      );

      GeminiApiKeyProvider.setApiKey('sk-quota_exhausted_key');

      final result = await service.queryConsultantDetailed(
        userQuery: 'I missed my morning dose, should I take two pills?',
        activeMeds: const [],
      );

      expect(result.isFromCloudLlm, isFalse);
      expect(result.text, contains('NEVER DOUBLE UP'));
      expect(result.text, contains('not medical advice'));
    });

    test('11. Sensitive API keys and tokens are never exposed in sanitized logs', () {
      const raw =
          'Headers: Authorization: Bearer sk-Tn2hEkqttr4V5eYkDPr4C3UOhVqzTvDYHbMsMZJXhAdFdgUw on key=AIzaSyA123456789012345678901234567890';
      final clean = AiRagService.sanitizeLogs(raw);
      expect(clean, isNot(contains('sk-Tn2hEkqttr4V5eYkDPr4C3UOhVqzTvDYHbMsMZJXhAdFdgUw')));
      expect(clean, isNot(contains('AIzaSyA123456789012345678901234567890')));
      expect(clean, contains('Bearer ***'));
      expect(clean, contains('key=***'));
    });

    test('12. Known allergies in EmergencyProfileModel trigger critical contraindication alerts', () async {
      final service = AiRagService();
      GeminiApiKeyProvider.resetForTesting();

      final profile = EmergencyProfileModel(
        userId: 'test_user_123',
        name: 'Test Patient',
        age: 32,
        bloodGroup: 'B+',
        allergiesList: ['Penicillin', 'Augmentin'],
        medicalConditionsList: ['Hypertension'],
        currentMedicines: 'None',
        emergencyContact: '03001234567',
        isSharingEnabled: true,
      );

      final answer = await service.queryClinicalRag(
        userQuery: 'Can I take Augmentin 625mg for tooth pain?',
        activeMeds: const [],
        emergencyProfile: profile,
      );

      expect(answer, contains('CRITICAL ALLERGY ALERT'));
      expect(answer, contains('penicillin-group antibiotic'));
      expect(answer, contains('DO NOT TAKE THIS MEDICATION'));
    });
  });
}
