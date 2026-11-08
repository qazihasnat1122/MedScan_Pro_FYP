import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemini_api_config.dart';
import 'prescription_parser.dart';

/// Selected prescription document (camera photo, gallery image, or multi-page PDF).
class SelectedPrescriptionFile {
  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int pageCount;
  final List<String> previewImagePaths;

  const SelectedPrescriptionFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.pageCount = 1,
    this.previewImagePaths = const [],
  });

  bool get isPdf => mimeType == 'application/pdf';
}

/// Result returned by the secure Gemini extraction backend.
class PrescriptionExtractionResult {
  final String rawText;
  final String prescriptionDate;
  final List<PrescriptionMedicineItem> medicines;
  final String extractionSource;

  const PrescriptionExtractionResult({
    required this.rawText,
    required this.prescriptionDate,
    required this.medicines,
    this.extractionSource = 'gemini_backend',
  });
}

/// Thrown when a prescription file is unsupported, empty, corrupt, or unreadable.
class PrescriptionFileException implements Exception {
  final String message;
  const PrescriptionFileException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the Gemini backend proxy fails, is unreachable, or is not configured.
class PrescriptionExtractionException implements Exception {
  final String message;
  final bool isSetupError;
  final int? statusCode;

  const PrescriptionExtractionException(
    this.message, {
    this.isSetupError = false,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Pluggable HTTP transport signature so unit/widget tests can mock backend responses
/// without making real network or Gemini API calls.
typedef PrescriptionBackendTransport =
    Future<Map<String, dynamic>> Function({
      required Uri endpoint,
      required String idToken,
      required Map<String, dynamic> body,
    });

final prescriptionAiServiceProvider = Provider<PrescriptionAiService>((ref) {
  return PrescriptionAiService();
});

class PrescriptionAiService {
  static const MethodChannel _pdfChannel = MethodChannel(
    'com.medscan.pro/document_picker',
  );

  /// Secure backend endpoint URL configured via `--dart-define=PRESCRIPTION_API_URL=...`
  /// Defaults to the project's Firebase Cloud Function v2 HTTPS endpoint.
  static const String _configuredEndpoint = String.fromEnvironment(
    'PRESCRIPTION_API_URL',
    defaultValue:
        'https://us-central1-medscan-bed48.cloudfunctions.net/extractPrescription',
  );

  /// Gemini model used for direct local-evaluation calls. Override with
  /// `--dart-define=GEMINI_MODEL=...` when Google retires a model
  /// (gemini-2.5-flash is no longer available to new API keys).
  static const String _geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );

  /// Resilient model fallback chain in case the primary model experiences
  /// temporary HTTP 503 high-demand spikes or regional retirement.
  static List<String> get _modelFallbackChain {
    final models = <String>[
      _geminiModel,
      'gemini-3.5-flash',
      'gemini-flash-lite-latest',
      'gemini-3.6-flash',
      'gemini-3.5-flash-lite',
      'gemini-flash-latest',
    ];
    return models.toSet().toList();
  }

  /// Resolves the local evaluation Gemini API key via the unified [GeminiApiKeyProvider],
  /// sharing the identical resolution chain across Chatbot, Prescription AI, and Nearby Pharmacies.
  static Future<String> _resolveDevApiKey() => GeminiApiKeyProvider.resolveApiKey();

  /// Compresses large camera/gallery images (> 350 KB) via Android Bitmap downscaling
  /// before base64 encoding to prevent multi-megabyte uploads and `Broken pipe` errors.
  static Future<File> _compressImageFileIfNeeded(File originalFile) async {
    try {
      final len = await originalFile.length();
      if (len <= 350 * 1024) return originalFile;
      final compressedPath = await _pdfChannel.invokeMethod<String>(
        'compressImageForAi',
        <String, dynamic>{
          'path': originalFile.path,
          'maxDimension': 1400,
          'quality': 80,
        },
      );
      if (compressedPath != null && compressedPath.isNotEmpty) {
        final compressedFile = File(compressedPath);
        if (await compressedFile.exists() &&
            await compressedFile.length() > 0) {
          return compressedFile;
        }
      }
    } catch (_) {
      // Fall back to original file in unit tests or if native channel is unavailable
    }
    return originalFile;
  }

  static const String _packagingExtractionPrompt =
      'You are an expert pharmaceutical packaging reader for a medicine verification app in Pakistan.\n'
      'Read all visible text on this medicine box, bottle label, or blister strip image.\n'
      'Extract ONLY what is visibly printed or embossed on the packaging. Do NOT guess or invent missing values.\n'
      'If a field is not visible on this side of the pack, return "" for that field.\n'
      'Return strictly valid JSON with keys:\n'
      '{\n'
      '  "rawText": "all visible text on the pack",\n'
      '  "brandName": "prominent brand name (e.g. Panadol, Augmentin, Risek)",\n'
      '  "genericSalt": "active generic ingredient(s) (e.g. Paracetamol, Co-Amoxiclav, Omeprazole)",\n'
      '  "strength": "dosage strength (e.g. 500mg, 625mg, 40mg)",\n'
      '  "dosageForm": "Tablet, Capsule, Syrup, Suspension, Injection, Drops, Cream, Gel, or Sachet",\n'
      '  "manufacturer": "manufacturer / pharma company name if visible (e.g. GSK, Getz Pharma, Sami, Abbott)",\n'
      '  "batchNumber": "Batch No / Lot No / B.No if visible (e.g. KX902, B4021)",\n'
      '  "expiryDate": "Exp / Expiry Date if visible (e.g. 12/2027, AUG 2026)",\n'
      '  "mfgDate": "Mfg Date if visible",\n'
      '  "price": "printed retail price / M.R.P in Rs./PKR as a number string if visible (e.g. 420.00)",\n'
      '  "registrationNumber": "DRAP Reg. No. if visible",\n'
      '  "barcode": "numeric barcode / GTIN digits if printed"\n'
      '}';

  static const String _extractionSystemPrompt =
      'You are a clinical prescription text extractor for a medication safety app.\n'
      'Extract ONLY what is visibly written on the prescription. Do NOT diagnose conditions, '
      'recommend treatments, or invent missing medicine names, strengths, dosages, routes, '
      'frequencies, clock times, durations, quantities, or dates.\n'
      'If any field is illegible, missing, or uncertain, leave its value as "" (or null for '
      'durationDays), set "confidence" to "low" or "medium", and list the field in "uncertainFields".\n'
      'Return strictly valid JSON with keys: "rawText" (string), "prescriptionDate" (string), '
      'and "medicines" (array of objects with keys: "medicineName", "brand", "strength", '
      '"dosageInstructions", "route", "frequency", "timing", "duration", "durationDays", '
      '"quantity", "specialInstructions", "confidence", "uncertainFields").';

  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB limit

  final String endpointUrl;
  final PrescriptionBackendTransport _transport;
  final Future<String?> Function()? _tokenProvider;

  PrescriptionAiService({
    String? endpointUrl,
    PrescriptionBackendTransport? transport,
    Future<String?> Function()? tokenProvider,
  }) : endpointUrl = endpointUrl ?? _configuredEndpoint,
       _transport = transport ?? _defaultHttpTransport,
       _tokenProvider = tokenProvider;

  /// Opens the native Android PDF picker and renders page previews.
  Future<SelectedPrescriptionFile?> pickPdfDocument() async {
    try {
      final result = await _pdfChannel.invokeMapMethod<String, dynamic>(
        'pickPdf',
      );
      if (result == null) return null; // User cancelled

      final path = (result['path'] ?? '').toString();
      final fileName = (result['fileName'] ?? 'prescription.pdf').toString();
      final pageCount = (result['pageCount'] as num?)?.toInt() ?? 1;
      final pagePaths =
          (result['pagePaths'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];

      return validateAndPrepareFile(
        File(path),
        explicitFileName: fileName,
        pdfPageCount: pageCount,
        pdfPreviewPaths: pagePaths,
      );
    } on PlatformException catch (e) {
      if (e.code == 'EMPTY_FILE') {
        throw const PrescriptionFileException(
          'The selected PDF file is empty. Please choose a valid prescription document.',
        );
      }
      if (e.code == 'CORRUPT_PDF') {
        throw const PrescriptionFileException(
          'The selected PDF file appears corrupted or password-protected and could not be read.',
        );
      }
      throw PrescriptionFileException(
        e.message ?? 'Could not open the selected PDF file.',
      );
    }
  }

  /// Validates an image or PDF file for existence, size, format, and header integrity.
  Future<SelectedPrescriptionFile> validateAndPrepareFile(
    File file, {
    String? explicitFileName,
    int? pdfPageCount,
    List<String>? pdfPreviewPaths,
  }) async {
    if (!await file.exists()) {
      throw const PrescriptionFileException(
        'The selected file does not exist or could not be accessed.',
      );
    }

    final length = await file.length();
    if (length <= 0) {
      throw const PrescriptionFileException(
        'The selected file is empty (0 bytes). Please choose a valid image or PDF.',
      );
    }
    if (length > maxFileSizeBytes) {
      throw const PrescriptionFileException(
        'The selected file exceeds the 15 MB size limit. Please select a clearer or smaller file.',
      );
    }

    final fileName =
        explicitFileName ??
        file.uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => 'prescription',
        );
    final lowerName = fileName.toLowerCase();

    // Read leading bytes to verify header integrity and detect corrupt files
    final headerBytes = await file
        .openRead(0, 12)
        .fold<List<int>>(<int>[], (prev, element) => prev..addAll(element));
    if (headerBytes.length < 4) {
      throw const PrescriptionFileException(
        'The selected file is too small or corrupted to be a valid prescription.',
      );
    }

    String? detectedMime;
    if (_startsWithPdfHeader(headerBytes)) {
      detectedMime = 'application/pdf';
    } else if (_startsWithJpegHeader(headerBytes)) {
      detectedMime = 'image/jpeg';
    } else if (_startsWithPngHeader(headerBytes)) {
      detectedMime = 'image/png';
    } else if (_startsWithWebpHeader(headerBytes)) {
      detectedMime = 'image/webp';
    }

    if (detectedMime == null) {
      if (lowerName.endsWith('.pdf')) {
        throw const PrescriptionFileException(
          'The selected PDF file is corrupted or does not have a valid PDF header.',
        );
      }
      if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png') ||
          lowerName.endsWith('.webp')) {
        throw const PrescriptionFileException(
          'The selected image file is corrupted or unreadable.',
        );
      }
      throw const PrescriptionFileException(
        'Unsupported file format. Please select a clear JPG, PNG, WEBP image, or PDF document.',
      );
    }

    final previews = detectedMime == 'application/pdf'
        ? (pdfPreviewPaths ?? const <String>[])
        : <String>[file.path];

    return SelectedPrescriptionFile(
      path: file.path,
      fileName: fileName,
      mimeType: detectedMime,
      sizeBytes: length,
      pageCount: detectedMime == 'application/pdf' ? (pdfPageCount ?? 1) : 1,
      previewImagePaths: previews,
    );
  }

  /// Sends the validated prescription file to the secure server-side Gemini proxy.
  /// Never logs file bytes, tokens, or extracted text.
  Future<PrescriptionExtractionResult> extractPrescription(
    SelectedPrescriptionFile selectedFile,
  ) async {
    final trimmedEndpoint = endpointUrl.trim();
    if (trimmedEndpoint.isEmpty) {
      throw const PrescriptionExtractionException(
        'Prescription AI backend URL is not configured. Deploy the Firebase Cloud Function or provide PRESCRIPTION_API_URL.',
        isSetupError: true,
      );
    }

    final uri = Uri.tryParse(trimmedEndpoint);
    if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
      throw const PrescriptionExtractionException(
        'Invalid Prescription AI backend URL configuration.',
        isSetupError: true,
      );
    }

    // Obtain Firebase Auth ID token for authenticated backend request
    String? idToken;
    if (_tokenProvider != null) {
      idToken = await _tokenProvider();
    } else {
      try {
        final user = FirebaseAuth.instance.currentUser;
        idToken = await user?.getIdToken();
      } catch (_) {
        idToken = null;
      }
    }

    if (idToken == null || idToken.isEmpty) {
      throw const PrescriptionExtractionException(
        'You must be signed in to extract prescriptions securely.',
        statusCode: 401,
      );
    }

    final file = File(selectedFile.path);
    if (!await file.exists()) {
      throw const PrescriptionFileException(
        'The selected prescription file is no longer available. Please re-select it.',
      );
    }

    final fileToRead = selectedFile.isPdf
        ? file
        : await _compressImageFileIfNeeded(file);
    final bytes = await fileToRead.readAsBytes();
    if (bytes.isEmpty) {
      throw const PrescriptionFileException(
        'The selected file is empty and cannot be processed.',
      );
    }

    // For multi-page PDFs where rendered page previews exist, also attach additional pages
    // if needed while keeping payload compact.
    final additionalPagesBase64 = <String>[];
    if (selectedFile.isPdf && selectedFile.previewImagePaths.length > 1) {
      for (final previewPath
          in selectedFile.previewImagePaths.skip(1).take(3)) {
        final previewFile = File(previewPath);
        if (await previewFile.exists()) {
          final compressedPreview = await _compressImageFileIfNeeded(
            previewFile,
          );
          final previewBytes = await compressedPreview.readAsBytes();
          if (previewBytes.isNotEmpty) {
            additionalPagesBase64.add(base64Encode(previewBytes));
          }
        }
      }
    }

    final effectiveMimeType =
        (!selectedFile.isPdf && fileToRead.path != file.path)
        ? 'image/jpeg'
        : selectedFile.mimeType;

    final requestBody = <String, dynamic>{
      'mimeType': effectiveMimeType,
      'base64Data': base64Encode(bytes),
      if (additionalPagesBase64.isNotEmpty)
        'additionalPagesBase64': additionalPagesBase64,
    };

    final responseJson = await _transport(
      endpoint: uri,
      idToken: idToken,
      body: requestBody,
    );

    return parseBackendResponse(responseJson);
  }

  /// Extracts medicine packaging attributes (brand, generic salt, strength, batch,
  /// expiry, manufacturer, price) from a camera/gallery photo using AI vision when available.
  /// Returns an empty map if offline or unconfigured so on-device OCR remains the primary path.
  Future<Map<String, dynamic>> extractPackagingAttributesFromImage(
    String imagePath,
  ) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return const {};
      final compressed = await _compressImageFileIfNeeded(file);
      final bytes = await compressed.readAsBytes();
      if (bytes.isEmpty) return const {};

      final devKey = await _resolveDevApiKey();
      if (devKey.isEmpty) return const {};

      final body = <String, dynamic>{
        'mimeType': 'image/jpeg',
        'base64Data': base64Encode(bytes),
      };
      return await _callGeminiWithRuntimeEnvKey(
        body,
        explicitKey: devKey,
        customSystemPrompt: _packagingExtractionPrompt,
      );
    } catch (_) {
      return const {};
    }
  }

  /// Parses the structured JSON response from the secure Gemini backend into
  /// unconfirmed `PrescriptionMedicineItem` records for user review.
  PrescriptionExtractionResult parseBackendResponse(
    Map<String, dynamic> responseJson,
  ) {
    final rawText = (responseJson['rawText'] ?? '').toString().trim();
    final prescriptionDate = (responseJson['prescriptionDate'] ?? '')
        .toString()
        .trim();
    final rawMedicines = responseJson['medicines'];

    final items = <PrescriptionMedicineItem>[];
    if (rawMedicines is List) {
      for (var i = 0; i < rawMedicines.length; i++) {
        final entry = rawMedicines[i];
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final item =
              PrescriptionMedicineItem.fromMap(
                map,
                id: 'gemini_rx_${DateTime.now().microsecondsSinceEpoch}_$i',
                defaultPrescriptionDate: prescriptionDate,
              ).copyWith(
                // Raw Gemini output is NEVER pre-confirmed; user must review and confirm.
                isConfirmed: false,
              );
          items.add(item);
        }
      }
    }

    return PrescriptionExtractionResult(
      rawText: rawText,
      prescriptionDate: prescriptionDate,
      medicines: items,
      extractionSource: 'gemini_backend',
    );
  }

  static Future<Map<String, dynamic>> _defaultHttpTransport({
    required Uri endpoint,
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);
    try {
      // Cheap preflight so a missing/undeployed backend (HTTP 404) is reported
      // cleanly without streaming a large multi-megabyte request body.
      try {
        final probe = await client.getUrl(endpoint);
        final probeRes = await probe.close().timeout(
          const Duration(seconds: 12),
        );
        await probeRes.drain<void>();
        if (probeRes.statusCode == 404) {
          throw const PrescriptionExtractionException(
            'The secure extraction backend is not deployed yet (HTTP 404). Please use On-Device OCR or manual review.',
            isSetupError: true,
            statusCode: 404,
          );
        }
      } on PrescriptionExtractionException {
        rethrow;
      } on SocketException {
        // Proceed to main postUrl
      } on TimeoutException {
        // Proceed to main postUrl
      }

      final request = await client.postUrl(endpoint);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      final encoded = utf8.encode(jsonEncode(body));
      request.contentLength = encoded.length;
      request.add(encoded);

      final response = await request.close().timeout(
        const Duration(seconds: 55),
      );
      final responseBody = await response.transform(utf8.decoder).join();

      Map<String, dynamic> decoded = const {};
      if (responseBody.trim().isNotEmpty) {
        try {
          final dynamic jsonVal = jsonDecode(responseBody);
          if (jsonVal is Map<String, dynamic>) {
            decoded = jsonVal;
          }
        } catch (_) {
          // Non-JSON error body (e.g., HTML response from proxy)
        }
      }

      if (response.statusCode == 200) {
        return decoded;
      }

      final serverError = (decoded['error'] ?? '').toString().trim();
      if (response.statusCode == 404 || response.statusCode == 503) {
        throw PrescriptionExtractionException(
          serverError.isNotEmpty
              ? serverError
              : (response.statusCode == 404
                  ? 'The secure extraction backend is not deployed yet (HTTP 404). Please use On-Device OCR or manual review.'
                  : 'Secure Gemini backend is temporarily unavailable or GEMINI_API_KEY secret is not configured on Firebase Functions.'),
          isSetupError: true,
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw PrescriptionExtractionException(
          serverError.isNotEmpty
              ? serverError
              : 'Authentication failed when contacting the prescription extraction backend.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 422) {
        throw PrescriptionExtractionException(
          serverError.isNotEmpty
              ? serverError
              : 'No readable prescription text could be found in this file.',
          statusCode: 422,
        );
      }

      throw PrescriptionExtractionException(
        serverError.isNotEmpty
            ? serverError
            : 'Prescription extraction service returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    } on PrescriptionExtractionException {
      rethrow;
    } on SocketException catch (e) {
      throw PrescriptionExtractionException(
        'Could not complete the request to the extraction service (${e.osError?.message ?? e.message}). Please check your internet connection or use On-Device OCR.',
      );
    } on TimeoutException {
      throw const PrescriptionExtractionException(
        'Prescription extraction timed out. Please try again with a clearer image or smaller PDF, or use On-Device OCR.',
      );
    } catch (_) {
      throw const PrescriptionExtractionException(
        'Unable to complete prescription extraction right now. Please retry or review manually.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _callGeminiWithRuntimeEnvKey(
    Map<String, dynamic> body, {
    String? explicitKey,
    String? customSystemPrompt,
  }) async {
    final key = (explicitKey ?? await _resolveDevApiKey()).trim();
    if (key.isEmpty) {
      throw const PrescriptionExtractionException(
        'Gemini API key is not configured in the backend or runtime environment.',
        isSetupError: true,
      );
    }

    final parts = <Map<String, dynamic>>[
      <String, dynamic>{'text': customSystemPrompt ?? _extractionSystemPrompt},
      <String, dynamic>{
        'inlineData': <String, dynamic>{
          'mimeType': body['mimeType'],
          'data': body['base64Data'],
        },
      },
    ];

    final extraPages = body['additionalPagesBase64'];
    if (extraPages is List) {
      for (final pageB64 in extraPages.take(4)) {
        if (pageB64 is String && pageB64.isNotEmpty) {
          parts.add(<String, dynamic>{
            'inlineData': <String, dynamic>{
              'mimeType': 'image/png',
              'data': pageB64,
            },
          });
        }
      }
    }

    final payload = utf8.encode(
      jsonEncode(<String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{'role': 'user', 'parts': parts},
        ],
        'generationConfig': <String, dynamic>{
          'temperature': 0.0,
          'responseMimeType': 'application/json',
        },
      }),
    );

    PrescriptionExtractionException? lastError;

    for (final modelName in _modelFallbackChain) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=${Uri.encodeQueryComponent(key)}',
        );
        final req = await client.postUrl(uri);
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.headers.set('x-goog-api-key', key);
        req.contentLength = payload.length;
        req.add(payload);

        final res = await req.close().timeout(const Duration(seconds: 45));
        final resText = await res.transform(utf8.decoder).join();

        if (res.statusCode == 200) {
          final dynamic outer = jsonDecode(resText);
          final rawJsonText =
              outer?['candidates']?[0]?['content']?['parts']?[0]?['text']
                  ?.toString() ??
              '';
          if (rawJsonText.trim().isEmpty) {
            throw const PrescriptionExtractionException(
              'No readable prescription content could be extracted from the document.',
              statusCode: 422,
            );
          }
          final dynamic parsed = jsonDecode(rawJsonText);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
          throw const PrescriptionExtractionException(
            'AI service returned malformed structured output.',
          );
        }

        var detail = '';
        try {
          final dynamic errJson = jsonDecode(resText);
          detail = (errJson?['error']?['message'] ?? '').toString().trim();
        } catch (_) {}

        // If the key itself is invalid (400 API_KEY_INVALID or 403), fail immediately
        if (res.statusCode == 400 || res.statusCode == 403) {
          throw PrescriptionExtractionException(
            'Gemini extraction returned HTTP ${res.statusCode}.${detail.isNotEmpty ? ' $detail' : ' Verify the configured GEMINI_API_KEY is valid.'}',
            isSetupError: true,
            statusCode: res.statusCode,
          );
        }

        // For 404 (model retired), 429 (rate limit), or 503 (high demand), try the next model in _modelFallbackChain
        lastError = PrescriptionExtractionException(
          'Gemini extraction returned HTTP ${res.statusCode}.${detail.isNotEmpty ? ' $detail' : ''}',
          statusCode: res.statusCode,
        );
      } on PrescriptionExtractionException catch (e) {
        if (e.isSetupError || e.statusCode == 422) {
          rethrow;
        }
        lastError = e;
      } on SocketException catch (e) {
        lastError = PrescriptionExtractionException(
          'Network interrupted while contacting AI service (${e.osError?.message ?? e.message}). Please retry or use On-Device OCR.',
        );
      } on TimeoutException {
        lastError = const PrescriptionExtractionException(
          'AI model request timed out. Retrying with fast fallback model...',
        );
      } finally {
        client.close(force: true);
      }
    }

    throw lastError ??
        const PrescriptionExtractionException(
          'Unable to complete prescription extraction right now. Please retry or use On-Device OCR.',
        );
  }

  static bool _startsWithPdfHeader(List<int> b) =>
      b.length >= 4 &&
      b[0] == 0x25 && // %
      b[1] == 0x50 && // P
      b[2] == 0x44 && // D
      b[3] == 0x46; // F

  static bool _startsWithJpegHeader(List<int> b) =>
      b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static bool _startsWithPngHeader(List<int> b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  static bool _startsWithWebpHeader(List<int> b) =>
      b.length >= 12 &&
      b[0] == 0x52 && // R
      b[1] == 0x49 && // I
      b[2] == 0x46 && // F
      b[3] == 0x46 && // F
      b[8] == 0x57 && // W
      b[9] == 0x45 && // E
      b[10] == 0x42 && // B
      b[11] == 0x50; // P
}
