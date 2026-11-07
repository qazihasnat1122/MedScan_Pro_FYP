import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_medication_model.dart';
import '../models/emergency_profile_model.dart';
import 'clinical_service.dart';
import 'gemini_api_config.dart';

/// Pluggable transport signature for Chatbot LLM requests.
/// Enables deterministic offline testing with mocked responses.
typedef AiChatTransport =
    Future<Map<String, dynamic>> Function({
      required Uri endpoint,
      required Map<String, String> headers,
      required Map<String, dynamic> body,
    });

/// Structured diagnostic result returned by the Health and Medicine Consultant.
class AiConsultantResult {
  final String text;
  final bool isFromCloudLlm;
  final int? statusCode;
  final String? errorMessage;
  final String modelUsed;

  const AiConsultantResult({
    required this.text,
    this.isFromCloudLlm = false,
    this.statusCode,
    this.errorMessage,
    this.modelUsed = '',
  });
}

class AiRagService {
  /// Appended to local clinical engine fallback answers when no cloud LLM is active.
  static const String _disclaimer =
      '⚠️ General information only - not medical advice. This assistant can be wrong or incomplete and cannot see your full medical history. Confirm doses and combinations with your doctor or pharmacist.';

  /// Phase 3 — Official System Prompt for MedScan Pro's Health and Medicine Assistant.
  static const String healthConsultantSystemPrompt = '''
You are MedScan Pro's Health and Medicine Information Assistant.

Your purpose is to help users understand general health information,
medicines, medicine safety, common symptoms, and appropriate next steps.

COMMUNICATION:
- Use simple, clear language suitable for ordinary people in Pakistan.
- Support English and Urdu; use Roman Urdu when the user communicates
  in Roman Urdu.
- Explain medical terminology in understandable words.
- Ask relevant follow-up questions when necessary.
- Keep answers focused on the user's question.
- Clearly distinguish established information from uncertainty.

MEDICINE INFORMATION:
When relevant and supported by reliable information, explain:
- Brand name and generic/active ingredient.
- What the medicine is commonly used for.
- General precautions and common side effects.
- Important contraindications and interactions.
- Relevant warnings for children, pregnancy, breastfeeding, allergies,
  and older adults.
- Safe storage and expiry considerations.

Do not assume two medicines are equivalent just because their brand
names or packaging look similar.
Check the active ingredients, strength, and dosage form when comparing
medicines.

Do not invent medicine ingredients, approved uses, dosage instructions,
prices, availability, or clinical facts.
Use verified MedScan Pro medicine data or reliable configured sources
when available. If information cannot be verified, clearly say so.

DOSAGE AND PRESCRIPTIONS:
- Never independently prescribe medication or change a clinician's
  prescribed dose.
- Do not recommend starting, stopping, combining, or doubling medicines
  without appropriate clinical guidance.
- Explain that the correct dose depends on factors such as age, weight,
  diagnosis, formulation, medical history, and other medicines.
- For unclear handwritten prescriptions, explain uncertainty and direct
  the user to confirm with the prescribing clinician or pharmacist.
- Never guess an illegible medicine name or prescription dose.

SYMPTOM QUESTIONS:
- Provide general information about possible causes, not a definitive
  diagnosis.
- Ask about duration, severity, age, and relevant symptoms when needed.
- Explain when professional assessment is appropriate.
- Do not claim a diagnosis based only on a few symptoms.
- Do not generate unsupported confidence percentages.
- Do not delay urgent care by asking unnecessary questions.

EMERGENCY SAFETY:
If the user describes possible life-threatening symptoms, including
severe breathing difficulty, unconsciousness, suspected overdose,
severe allergic reaction, or signs of stroke or heart attack:
- Clearly tell the user to seek emergency medical assistance immediately.
- Give only appropriate, concise first-aid guidance.
- Do not suggest that chatting with the assistant is a substitute
  for emergency care.

INTERACTIONS AND ALLERGIES:
- Never declare a medicine combination safe without sufficient,
  reliable information.
- Ask for the exact medicine names, strengths, and relevant details
  when needed.
- Clearly distinguish a verified interaction from a possible or
  unverified interaction.
- Recommend a pharmacist or clinician when an interaction cannot
  be reliably assessed.

REAL-TIME INFORMATION:
- Never claim to have checked a pharmacy, medicine database, medical
  guideline, or live source unless the corresponding tool or service
  actually returned that information.
- Never fabricate citations, sources, pharmacy addresses, prices,
  opening hours, or medicine availability.
- If live information is unavailable, disclose that limitation.

PRIVACY:
- Ask only for health information needed to answer the question.
- Do not request passwords, API keys, or unnecessary personal identifiers.
- Do not expose one user's medical information to another user.

LIMITATIONS:
You are an AI health-information assistant, not a licensed physician.
You can help users understand medical information but cannot replace
professional diagnosis, treatment, or emergency care.
Do not repeat a long disclaimer in every answer; communicate limitations
when they are relevant to the question.''';

  /// Configurable endpoint URL via `--dart-define=CHAT_API_URL=...`.
  /// Defaults to empty (which dynamically routes based on API key format).
  static const String _configuredApiUrl = String.fromEnvironment(
    'CHAT_API_URL',
    defaultValue: '',
  );

  /// Configurable model identifier via `--dart-define=CHAT_MODEL=...`.
  static const String _configuredModel = String.fromEnvironment(
    'CHAT_MODEL',
    defaultValue: '',
  );

  final AiChatTransport? _customTransport;
  final ClinicalService _clinicalService;

  AiRagService({
    AiChatTransport? transport,
    ClinicalService? clinicalService,
  })  : _customTransport = transport,
        _clinicalService = clinicalService ?? ClinicalService();

  // Unified API key provider - can be set dynamically in AI Chat screen or loaded via Gradle .env
  static String get geminiApiKey => GeminiApiKeyProvider.currentKey;
  static set geminiApiKey(String value) => GeminiApiKeyProvider.setApiKey(value);

  /// Sanitizes sensitive values like API keys or tokens from logs.
  static String sanitizeLogs(String text) {
    var s = text;
    s = s.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9_-]+'), 'Bearer ***');
    s = s.replaceAll(RegExp(r'key=[A-Za-z0-9_-]+'), 'key=***');
    s = s.replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{20,}'), 'sk-***');
    s = s.replaceAll(RegExp(r'AIza[0-9A-Za-z-_]{35}'), 'AIza***');
    return s;
  }

  /// Executes the Health & Medicine Information Assistant pipeline:
  /// 1. RAG Retrieval & Clinical Augmentation (Active meds, Allergies, Conditions, Interactions)
  /// 2. Cloud LLM Generation (OpenAI-compatible / Gemini / Firebase Cloud Function proxy)
  /// 3. Offline Clinical Fallback (if key is empty or API call fails)
  Future<String> queryClinicalRag({
    required String userQuery,
    required List<UserMedicationModel> activeMeds,
    EmergencyProfileModel? emergencyProfile,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final result = await queryConsultantDetailed(
      userQuery: userQuery,
      activeMeds: activeMeds,
      emergencyProfile: emergencyProfile,
      conversationHistory: conversationHistory,
    );
    return result.text;
  }

  /// Detailed query returning structured status codes, model used, and diagnostics.
  Future<AiConsultantResult> queryConsultantDetailed({
    required String userQuery,
    required List<UserMedicationModel> activeMeds,
    EmergencyProfileModel? emergencyProfile,
    List<Map<String, String>>? conversationHistory,
  }) async {
    // 1. RETRIEVAL & CLINICAL AUGMENTATION (RAG)
    final retrievedContext = StringBuffer();
    retrievedContext.writeln('=== MEDSCAN PRO VERIFIED PATIENT CONTEXT ===');

    if (activeMeds.isNotEmpty) {
      retrievedContext.writeln('Active Prescribed Medications:');
      for (final m in activeMeds) {
        retrievedContext.writeln(
          '- ${m.name} ${m.strength} (Dosage: ${m.dosage}, Frequency: ${m.frequency}, Intake: ${m.mealInstruction})',
        );
      }
    } else {
      retrievedContext.writeln('Active Prescribed Medications: None currently registered.');
    }

    if (emergencyProfile != null) {
      if (emergencyProfile.allergies.isNotEmpty) {
        retrievedContext.writeln('Known Allergies: ${emergencyProfile.allergies}');
      }
      if (emergencyProfile.medicalConditions.isNotEmpty) {
        retrievedContext.writeln('Medical Conditions: ${emergencyProfile.medicalConditions}');
      }
    }

    // Check verified drug interactions from ClinicalService
    final interactions = _clinicalService.checkInteractions(activeMeds);
    if (interactions.isNotEmpty) {
      retrievedContext.writeln('Verified Clinical Drug Interaction Alerts:');
      for (final alert in interactions) {
        retrievedContext.writeln('- $alert');
      }
    }
    retrievedContext.writeln('============================================');

    // 2. GENERATION VIA CLOUD LLM (OpenAI-compatible, OpenRouter, Gemini, or Cloud Function)
    var activeKey = geminiApiKey;
    if (activeKey.isEmpty && _customTransport == null) {
      activeKey = await GeminiApiKeyProvider.resolveApiKey();
    }

    if (activeKey.isNotEmpty || _customTransport != null) {
      try {
        final cloudResponse = await _callCloudLlm(
          userQuery: userQuery,
          ragContext: retrievedContext.toString(),
          apiKey: activeKey,
          conversationHistory: conversationHistory,
        );

        if (cloudResponse != null && cloudResponse.text.trim().isNotEmpty) {
          return cloudResponse;
        }
      } catch (e) {
        debugPrint('Cloud LLM Exception: ${sanitizeLogs(e.toString())}');
      }
    }

    // 3. CLINICAL REASONING ENGINE (Guaranteed Offline / Free Fallback)
    final offlineText = _localClinicalReasoning(userQuery, activeMeds, emergencyProfile);
    return AiConsultantResult(
      text: '$offlineText\n\n$_disclaimer',
      isFromCloudLlm: false,
      statusCode: null,
      modelUsed: 'offline-clinical-engine',
    );
  }

  /// Calls upstream LLM provider supporting OpenAI-compatible chat completions standard,
  /// OpenRouter, Google Gemini, or custom secure Firebase Cloud Function proxy.
  Future<AiConsultantResult?> _callCloudLlm({
    required String userQuery,
    required String ragContext,
    required String apiKey,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final isOpenAiFormat = apiKey.startsWith('sk-');
    final String defaultModel = isOpenAiFormat ? 'gpt-4o-mini' : 'gemini-3.8-flash';
    final String model = _configuredModel.isNotEmpty ? _configuredModel : defaultModel;

    Uri endpoint;
    Map<String, String> headers;
    Map<String, dynamic> body;

    final augmentedSystemInstruction =
        '$healthConsultantSystemPrompt\n\n$ragContext';

    if (_configuredApiUrl.isNotEmpty) {
      endpoint = Uri.parse(_configuredApiUrl);
      headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      };
      body = {
        'model': model,
        'userQuery': userQuery,
        'ragContext': ragContext,
        'systemInstruction': augmentedSystemInstruction,
      };
    } else if (isOpenAiFormat) {
      // Standard OpenAI / OpenRouter Chat Completions standard
      endpoint = Uri.parse('https://api.openai.com/v1/chat/completions');
      headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      };

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': augmentedSystemInstruction},
      ];

      // Append multi-turn conversation history
      if (conversationHistory != null) {
        for (final item in conversationHistory) {
          final role = item['role'] ?? 'user';
          final content = item['content'] ?? '';
          if (content.isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        }
      }

      messages.add({'role': 'user', 'content': userQuery});

      body = {
        'model': model,
        'messages': messages,
        'temperature': 0.2,
        'max_tokens': 1000,
      };
    } else {
      // Google Gemini generateContent standard
      endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );
      headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'x-goog-api-key': apiKey,
      };

      final contents = <Map<String, dynamic>>[];
      if (conversationHistory != null) {
        for (final item in conversationHistory) {
          final role = item['role'] == 'assistant' ? 'model' : 'user';
          final content = item['content'] ?? '';
          if (content.isNotEmpty) {
            contents.add({
              'role': role,
              'parts': [{'text': content}],
            });
          }
        }
      }

      contents.add({
        'role': 'user',
        'parts': [{'text': userQuery}],
      });

      body = {
        'contents': contents,
        'systemInstruction': {
          'parts': [{'text': augmentedSystemInstruction}],
        },
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 1000,
        },
      };
    }

    final transport = _customTransport ?? _defaultTransport;
    final responseMap = await transport(
      endpoint: endpoint,
      headers: headers,
      body: body,
    );

    // Parse response
    String? replyText;

    // 1. OpenAI / OpenRouter format
    final choices = responseMap['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map && firstChoice['message'] is Map) {
        replyText = firstChoice['message']['content']?.toString();
      }
    }

    // 2. Google Gemini format
    if (replyText == null) {
      final candidates = responseMap['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final firstCand = candidates.first;
        if (firstCand is Map && firstCand['content'] is Map) {
          final parts = firstCand['content']['parts'];
          if (parts is List && parts.isNotEmpty) {
            replyText = parts.first['text']?.toString();
          }
        }
      }
    }

    // 3. Custom Proxy / Firebase Cloud Function format
    replyText ??= (responseMap['reply'] ?? responseMap['text'] ?? responseMap['response'])?.toString();

    if (replyText != null && replyText.trim().isNotEmpty) {
      return AiConsultantResult(
        text: replyText.trim(),
        isFromCloudLlm: true,
        statusCode: 200,
        modelUsed: model,
      );
    }

    return null;
  }

  static Future<Map<String, dynamic>> _defaultTransport({
    required Uri endpoint,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    try {
      final request = await client.postUrl(endpoint);
      headers.forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(body));

      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );

      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        final sanitizedMsg = sanitizeLogs(responseBody);
        debugPrint('AI Chat API error HTTP ${response.statusCode}: $sanitizedMsg');
        throw HttpException(
          'AI service error (HTTP ${response.statusCode}): $sanitizedMsg',
          uri: endpoint,
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Malformed response from AI provider.');
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  /// Built-in clinical reasoning engine: guaranteed 100% offline, deterministic,
  /// rule-governed safety responses for core clinical scenarios.
  String _localClinicalReasoning(
    String query,
    List<UserMedicationModel> activeMeds,
    EmergencyProfileModel? emergencyProfile,
  ) {
    final lower = query.toLowerCase();
    final medNames = activeMeds.map((m) => m.name).join(', ');
    final contextNote = activeMeds.isNotEmpty
        ? '\n\n*(Medicines currently on file in this app: $medNames - not clinically reviewed)*'
        : '';

    // Emergency symptoms detection
    if (lower.contains('chest pain') ||
        lower.contains('shortness of breath') ||
        lower.contains('difficulty breathing') ||
        lower.contains('unconscious') ||
        lower.contains('overdose') ||
        lower.contains('face drooping') ||
        lower.contains('stroke')) {
      return '🚨 **EMERGENCY MEDICAL ALERT**:\n\n'
          'The symptoms you described may be **life-threatening**.\n'
          '• **Call emergency medical services immediately (1122 in Pakistan)** or go to the nearest emergency room.\n'
          '• Rest in a safe position and keep airways clear.\n'
          '• Do not take additional medications while awaiting emergency medical personnel.\n'
          '• MedScan Pro AI is an information tool and cannot provide emergency medical care.';
    }

    // Check allergy contraindications across all saved allergies
    if (emergencyProfile != null && emergencyProfile.allergiesList.isNotEmpty) {
      for (final allergy in emergencyProfile.allergiesList) {
        final aLower = allergy.toLowerCase();
        if ((aLower.contains('penicillin') || aLower.contains('amoxicillin')) &&
            (lower.contains('augmentin') ||
                lower.contains('amoxicillin') ||
                lower.contains('penicillin') ||
                lower.contains('curam'))) {
          return '🚨 **CRITICAL ALLERGY ALERT**:\n\n'
              '• Your user-reported profile records an allergy to **$allergy**!\n'
              '• The medication inquired contains a penicillin-group antibiotic.\n'
              '• **DO NOT TAKE THIS MEDICATION** without consulting your physician immediately.';
        }
        if ((aLower.contains('aspirin') || aLower.contains('nsaid')) &&
            (lower.contains('disprin') ||
                lower.contains('aspirin') ||
                lower.contains('brufen') ||
                lower.contains('ibuprofen') ||
                lower.contains('diclofenac') ||
                lower.contains('voltral'))) {
          return '🚨 **CRITICAL ALLERGY ALERT**:\n\n'
              '• Your user-reported profile records an allergy or sensitivity to **$allergy**!\n'
              '• The inquired medicine belongs to the NSAID/salicylate family.\n'
              '• Risk of severe hypersensitivity or reaction. Consult your physician immediately.';
        }
        if (aLower.length >= 3 && lower.contains(aLower)) {
          return '🚨 **ALLERGY WARNING**:\n\n'
              '• Your user-reported profile lists **$allergy** as a known allergy.\n'
              '• Exercise caution and verify formulation ingredients with your pharmacist before taking this product.';
        }
      }
    }

    // Drug Interaction: Panadol (Paracetamol) + Brufen (Ibuprofen)
    if ((lower.contains('panadol') || lower.contains('paracetamol')) &&
        (lower.contains('brufen') || lower.contains('ibuprofen'))) {
      return '⚠️ **Panadol (Paracetamol) + Brufen (Ibuprofen) Interaction**:\n\n'
          '• **Interaction Level**: Moderate / Permissible under timing control.\n'
          '• **Clinical Mechanism**: Paracetamol is metabolized by the liver, while Ibuprofen (NSAID) acts on the COX pathway and kidneys.\n'
          '• **Protocol**: In acute pain or high fever, clinicians often advise alternating them every 4 to 6 hours rather than taking both together.\n'
          '• **Safety Threshold**: Never exceed 4,000mg Paracetamol or 1,200mg Ibuprofen in a 24-hour window.\n'
          '• **Stomach Protection**: Always take Ibuprofen with or after food to prevent gastritis.$contextNote';
    }

    // Missed dose protocol
    if (lower.contains('missed') ||
        lower.contains('skip') ||
        lower.contains('forgot')) {
      return '⏰ **Clinical Missed Dose Protocol**:\n\n'
          '1. **General Rule**: Take the missed dose as soon as you remember.\n'
          '2. **Near-Next Exception**: If it is almost time (less than 3-4 hours) for your next scheduled dose, skip the missed dose and resume your regular timeline.\n'
          '3. **NEVER DOUBLE UP**: Taking a double dose to compensate can cause dangerous toxicity or hypoglycemia.\n'
          '4. Check your scheduled alert times in the **Schedule & Reminders** tab.$contextNote';
    }

    // Metformin / Glucophage
    if (lower.contains('glucophage') || lower.contains('metformin')) {
      return '💊 **Glucophage (Metformin Hydrochloride)**:\n\n'
          '• **Primary Therapeutic Class**: Biguanide antidiabetic agent.\n'
          '• **Intake Direction**: MUST be taken with or immediately after a substantial meal to reduce gastrointestinal irritation.\n'
          '• **Expected Reactions**: Temporary nausea, mild metallic taste, or loose stools during the initial 1-2 weeks.\n'
          '• **Hydration**: Maintain consistent daily water intake to support kidney function.$contextNote';
    }

    // Counterfeit & Verification
    if (lower.contains('fake') ||
        lower.contains('counterfeit') ||
        lower.contains('verify') ||
        lower.contains('packaging')) {
      return '🔍 **Packaging Checks (general tips only)**:\n\n'
          '1. **Scan in MedScan Pro**: A scan compares printed pack details with reference records. It can NOT prove a physical medicine is genuine or test its contents.\n'
          '2. **Foil & Blister Alignment**: Counterfeits can show uneven foil seals, blurred printing, or misaligned tablet pockets.\n'
          '3. **Security features**: If the manufacturer states its packs carry a hologram or tamper-evident seal, check that feature - but not all genuine packs have one.\n'
          '4. **Batch & Expiry**: Check that batch and expiry are clearly printed and match the outer box and the blister.\n'
          '5. **When in doubt**: Do not use the medicine; buy from a licensed pharmacy and report suspicious products to DRAP.';
    }

    // Antibiotic courses
    if (lower.contains('antibiotic') ||
        lower.contains('augmentin') ||
        lower.contains('amoxicillin')) {
      return '🦠 **Antibiotic Clinical Safety**:\n\n'
          '• **Complete Full Course**: Complete all prescribed days even if you feel 100% recovered to prevent bacterial resistance.\n'
          '• **Even Interval Spacing**: Twice-daily antibiotics require strict 12-hour spacing for continuous therapeutic blood concentration.\n'
          '• **Gastrointestinal Support**: Taking with food significantly reduces stomach cramping.$contextNote';
    }

    // Unreadable prescription guidance
    if (lower.contains('prescription') &&
        (lower.contains('unclear') ||
            lower.contains('handwriting') ||
            lower.contains('read') ||
            lower.contains('illegible'))) {
      return '📋 **Unclear Prescription Safety Notice**:\n\n'
          '• Never guess an unclear handwriting or illegible dose on a prescription.\n'
          '• Small errors in decimal points or abbreviations (e.g. 5.0mg vs 50mg) can cause severe adverse drug events.\n'
          '• Always present the prescription directly to a registered pharmacist or request your prescribing physician to clarify the written order.';
    }

    // Default response
    return 'I do not have specific verified information for **"$query"** in my built-in offline knowledge, so I will not guess.\n\n'
        '• Follow the dose and interval prescribed by your doctor or printed on the pack.\n'
        '• Ask your pharmacist or doctor about this question, especially for combinations, pregnancy, children, or long-term illness.\n'
        '• In case of chest tightness, acute swelling, severe rash, or breathing difficulty, seek emergency medical care immediately.$contextNote';
  }
}
