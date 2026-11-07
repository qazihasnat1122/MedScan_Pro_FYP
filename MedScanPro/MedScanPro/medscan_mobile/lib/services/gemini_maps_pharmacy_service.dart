import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/pharmacy_model.dart';
import 'gemini_api_config.dart';
import 'location_service.dart';

/// Pluggable HTTP transport signature for Gemini Google Maps Grounding.
/// Allows unit and widget tests to run deterministically offline with mocked responses.
typedef GeminiMapsTransport =
    Future<Map<String, dynamic>> Function({
      required Uri endpoint,
      required Map<String, String> headers,
      required Map<String, dynamic> body,
    });

/// Exception thrown when Gemini Google Maps Grounding fails.
class GeminiMapsException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;
  final bool isQuotaExhausted;
  final Duration? retryDelay;

  const GeminiMapsException(
    this.message, {
    this.statusCode,
    this.isAuthError = false,
    this.isQuotaExhausted = false,
    this.retryDelay,
  });

  @override
  String toString() => message;
}

/// Structured result of a Gemini Google Maps Grounding discovery attempt,
/// containing granular diagnostics for logging and user-facing fallback indicators.
class GeminiMapsDiscoveryResult {
  final List<PharmacyModel> pharmacies;
  final int? statusCode;
  final String? errorMessage;
  final int candidateCount;
  final bool hasGroundingMetadata;
  final int groundedPlaceCount;
  final String? fallbackReason;
  final String modelAttempted;
  final bool isSuccess;
  final bool isQuotaExhausted;
  final Duration? retryDelay;
  final int? latencyMs;

  const GeminiMapsDiscoveryResult({
    this.pharmacies = const [],
    this.statusCode,
    this.errorMessage,
    this.candidateCount = 0,
    this.hasGroundingMetadata = false,
    this.groundedPlaceCount = 0,
    this.fallbackReason,
    this.modelAttempted = '',
    this.isSuccess = false,
    this.isQuotaExhausted = false,
    this.retryDelay,
    this.latencyMs,
  });
}

/// Discovers real nearby pharmacies dynamically using Gemini with Google Maps Grounding.
///
/// Implements the official Google Maps Grounding specification via the Interactions API:
/// https://ai.google.dev/gemini-api/docs/maps-grounding
/// Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/interactions`
class GeminiMapsPharmacyService {
  /// Endpoint for the Gemini Interactions API with built-in Google Maps grounding tool.
  static const String interactionsEndpointUrl =
      'https://generativelanguage.googleapis.com/v1beta/interactions';

  /// Default verified model supporting Google Maps Grounding via Interactions API.
  /// Per official Gemini API documentation, gemini-3.8-flash is the active model supporting
  /// Google Maps grounding with place citations.
  static const String defaultModel = 'gemini-3.8-flash';

  /// Preferred Gemini model supporting Google Maps Grounding.
  /// Explicitly configured via `--dart-define=GEMINI_MAPS_MODEL=...`.
  /// Does NOT inherit generic GEMINI_MODEL (which is used for prescription OCR/RAG).
  static const String _configuredModel = String.fromEnvironment(
    'GEMINI_MAPS_MODEL',
    defaultValue: defaultModel,
  );

  /// Verified models that officially support Grounding with Google Maps:
  /// Excludes retired/unsupported models like gemini-1.5-flash and gemini-3.5-flash.
  static List<String> get supportedModels {
    final list = <String>[
      _configuredModel,
      'gemini-3.8-flash',
      'gemini-2.5-flash',
    ];
    final seen = <String>{};
    return list.where((m) => seen.add(m)).toList();
  }

  final GeminiMapsTransport? _customTransport;
  final String? _injectedApiKey;

  GeminiMapsPharmacyService({
    GeminiMapsTransport? transport,
    String? apiKey,
  })  : _customTransport = transport,
        _injectedApiKey = apiKey;

  /// Sanitizes sensitive values like API keys from error messages and logs.
  static String sanitizeError(String text) {
    var sanitized = text;
    sanitized = sanitized.replaceAll(RegExp(r'key=[A-Za-z0-9_-]+'), 'key=***');
    sanitized = sanitized.replaceAll(RegExp(r'AIza[0-9A-Za-z-_]{35}'), 'AIza***');
    sanitized = sanitized.replaceAll(RegExp(r'x-goog-api-key:\s*[^\s\n,]+'), 'x-goog-api-key: ***');
    return sanitized;
  }

  /// Resolves the unified Gemini API key via [GeminiApiKeyProvider],
  /// sharing the identical resolution chain across Chatbot, Prescription AI, and Nearby Pharmacies.
  static Future<String> resolveApiKey() => GeminiApiKeyProvider.resolveApiKey();

  /// Sends a dynamic pharmacy discovery request grounded in Google Maps using
  /// the user's actual GPS coordinates as the geographic bias, capturing structured diagnostics.
  Future<GeminiMapsDiscoveryResult> discoverPharmaciesWithDiagnostics({
    required DeviceCoordinates userCoordinates,
    int radiusMeters = 5000,
  }) async {
    final stopwatch = Stopwatch()..start();
    final apiKey = _injectedApiKey ??
        (_customTransport != null ? 'test_api_key' : await resolveApiKey());

    if (_customTransport == null && apiKey.isEmpty) {
      const msg =
          'Gemini API key is not configured. Set GEMINI_API_KEY via --dart-define or local configuration.';
      _logDiagnostic(
        model: _configuredModel,
        status: 401,
        candidates: 0,
        hasGrounding: false,
        places: 0,
        fallback: 'Missing API Key: GEMINI_API_KEY not configured',
        error: msg,
      );
      return const GeminiMapsDiscoveryResult(
        statusCode: 401,
        errorMessage: msg,
        candidateCount: 0,
        hasGroundingMetadata: false,
        groundedPlaceCount: 0,
        fallbackReason: 'Missing API Key: GEMINI_API_KEY not configured',
        modelAttempted: _configuredModel,
        isSuccess: false,
      );
    }

    final modelsToTry =
        _customTransport != null ? [_configuredModel] : supportedModels;
    GeminiMapsDiscoveryResult? lastResult;
    bool hasRetriedBackoff = false;

    for (int modelIndex = 0; modelIndex < modelsToTry.length; modelIndex++) {
      final model = modelsToTry[modelIndex];
      try {
        final endpoint = Uri.parse(interactionsEndpointUrl);

        // Documented Interactions API payload with Google Maps tool and GPS coordinates
        final requestBody = <String, dynamic>{
          'model': model,
          'input':
              'Find open pharmacies and medical stores near latitude '
              '${userCoordinates.latitude}, longitude ${userCoordinates.longitude}. '
              'Ground all recommendations in Google Maps and provide real place citations.',
          'tools': [
            {
              'type': 'google_maps',
              'latitude': userCoordinates.latitude,
              'longitude': userCoordinates.longitude,
            },
          ],
        };

        final headers = <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'x-goog-api-key': apiKey,
        };

        final transport = _customTransport ?? _defaultTransport;
        final responseMap = await transport(
          endpoint: endpoint,
          headers: headers,
          body: requestBody,
        );

        stopwatch.stop();
        final latency = stopwatch.elapsedMilliseconds;

        // Parse response diagnostics (supporting Interactions API and generateContent)
        int candidateCount = 0;
        bool hasGrounding = false;

        final steps = responseMap['steps'];
        if (steps is List) {
          for (final step in steps) {
            if (step is Map && (step['type'] == 'model_output' || step['content'] is List)) {
              candidateCount++;
              final content = step['content'];
              if (content is List) {
                for (final item in content) {
                  if (item is Map &&
                      item['annotations'] is List &&
                      (item['annotations'] as List).isNotEmpty) {
                    hasGrounding = true;
                  }
                }
              }
            }
          }
        }

        final candidates = responseMap['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          candidateCount = candidates.length;
          if (candidates.first is Map && candidates.first['groundingMetadata'] is Map) {
            hasGrounding = true;
          }
        }

        final pharmacies = parseGroundingResponse(
          responseMap,
          userLatitude: userCoordinates.latitude,
          userLongitude: userCoordinates.longitude,
        );

        if (pharmacies.isNotEmpty) {
          _logDiagnostic(
            model: model,
            status: 200,
            candidates: candidateCount,
            hasGrounding: hasGrounding,
            places: pharmacies.length,
            fallback: null,
            latencyMs: latency,
          );
          return GeminiMapsDiscoveryResult(
            pharmacies: pharmacies,
            statusCode: 200,
            candidateCount: candidateCount,
            hasGroundingMetadata: hasGrounding,
            groundedPlaceCount: pharmacies.length,
            modelAttempted: model,
            isSuccess: true,
            latencyMs: latency,
          );
        }

        // Empty places extracted from candidate
        final fallbackReason = candidateCount == 0
            ? 'Gemini returned 0 candidates'
            : (!hasGrounding
                ? 'Gemini returned text response without Google Maps grounding chunks'
                : 'Grounding metadata contained 0 valid place chunks');

        _logDiagnostic(
          model: model,
          status: 200,
          candidates: candidateCount,
          hasGrounding: hasGrounding,
          places: 0,
          fallback: fallbackReason,
          latencyMs: latency,
        );

        lastResult = GeminiMapsDiscoveryResult(
          pharmacies: const [],
          statusCode: 200,
          candidateCount: candidateCount,
          hasGroundingMetadata: hasGrounding,
          groundedPlaceCount: 0,
          fallbackReason: fallbackReason,
          modelAttempted: model,
          isSuccess: false,
          latencyMs: latency,
        );
        // If the model responded 200 OK but had 0 places, do not try other models
        break;
      } on GeminiMapsException catch (e) {
        final sanitizedMsg = sanitizeError(e.message);

        // ── 1. HTTP 429: Quota / Rate limit exhausted ────────────────────────
        if (e.statusCode == 429) {
          // Check if bounded backoff retry is viable (short delay <= 2s)
          if (!hasRetriedBackoff &&
              e.retryDelay != null &&
              e.retryDelay! <= const Duration(seconds: 2)) {
            hasRetriedBackoff = true;
            _logDiagnostic(
              model: model,
              status: 429,
              candidates: 0,
              hasGrounding: false,
              places: 0,
              fallback:
                  'Transient rate limit (HTTP 429). Applying backoff: ${e.retryDelay!.inMilliseconds}ms',
              error: sanitizedMsg,
            );
            await Future<void>.delayed(e.retryDelay!);
            // Retry the same model once
            modelIndex--;
            continue;
          }

          // Do NOT cycle through other models on HTTP 429
          final quotaFallback =
              'Gemini quota/rate limit exhausted (HTTP 429): $sanitizedMsg. '
              'Please check your project quota and billing in Google AI Studio or Google Cloud Console.';

          _logDiagnostic(
            model: model,
            status: 429,
            candidates: 0,
            hasGrounding: false,
            places: 0,
            fallback: quotaFallback,
            error: sanitizedMsg,
          );

          return GeminiMapsDiscoveryResult(
            statusCode: 429,
            errorMessage: sanitizedMsg,
            candidateCount: 0,
            hasGroundingMetadata: false,
            groundedPlaceCount: 0,
            fallbackReason: quotaFallback,
            modelAttempted: model,
            isSuccess: false,
            isQuotaExhausted: true,
            retryDelay: e.retryDelay,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }

        // ── 2. HTTP 401 / 403: Auth / Project / Feature Permission ─────────
        if (e.statusCode == 401 || e.statusCode == 403) {
          final authFallback =
              'Gemini API authentication failed (HTTP ${e.statusCode}): $sanitizedMsg. '
              'Please verify that your API key belongs to the intended MedScan project '
              'and that Grounding with Google Maps is enabled in Google AI Studio or Google Cloud Console.';

          _logDiagnostic(
            model: model,
            status: e.statusCode,
            candidates: 0,
            hasGrounding: false,
            places: 0,
            fallback: authFallback,
            error: sanitizedMsg,
          );

          return GeminiMapsDiscoveryResult(
            statusCode: e.statusCode,
            errorMessage: sanitizedMsg,
            candidateCount: 0,
            hasGroundingMetadata: false,
            groundedPlaceCount: 0,
            fallbackReason: authFallback,
            modelAttempted: model,
            isSuccess: false,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }

        // ── 3. HTTP 404: Model Not Found / Unsupported ─────────────────────
        if (e.statusCode == 404) {
          final notFoundFallback =
              "Model '$model' was not found or is unsupported for Google Maps Grounding (HTTP 404). "
              "Google recommends updating to gemini-3.8-flash.";

          _logDiagnostic(
            model: model,
            status: 404,
            candidates: 0,
            hasGrounding: false,
            places: 0,
            fallback: notFoundFallback,
            error: sanitizedMsg,
          );

          lastResult = GeminiMapsDiscoveryResult(
            statusCode: 404,
            errorMessage: sanitizedMsg,
            candidateCount: 0,
            hasGroundingMetadata: false,
            groundedPlaceCount: 0,
            fallbackReason: notFoundFallback,
            modelAttempted: model,
            isSuccess: false,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
          // Try next verified model in the chain
          continue;
        }

        // ── 4. HTTP 503: Transient Service Unavailable ─────────────────────
        if (e.statusCode == 503) {
          final serverFallback =
              "Gemini service temporarily unavailable (HTTP 503): $sanitizedMsg.";

          _logDiagnostic(
            model: model,
            status: 503,
            candidates: 0,
            hasGrounding: false,
            places: 0,
            fallback: serverFallback,
            error: sanitizedMsg,
          );

          lastResult = GeminiMapsDiscoveryResult(
            statusCode: 503,
            errorMessage: sanitizedMsg,
            candidateCount: 0,
            hasGroundingMetadata: false,
            groundedPlaceCount: 0,
            fallbackReason: serverFallback,
            modelAttempted: model,
            isSuccess: false,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
          continue;
        }

        // Other HTTP errors (e.g. 400 Bad Request)
        final genericFallback =
            'Gemini API Error (HTTP ${e.statusCode ?? 'unknown'}): $sanitizedMsg';

        _logDiagnostic(
          model: model,
          status: e.statusCode,
          candidates: 0,
          hasGrounding: false,
          places: 0,
          fallback: genericFallback,
          error: sanitizedMsg,
        );

        lastResult = GeminiMapsDiscoveryResult(
          statusCode: e.statusCode,
          errorMessage: sanitizedMsg,
          candidateCount: 0,
          hasGroundingMetadata: false,
          groundedPlaceCount: 0,
          fallbackReason: genericFallback,
          modelAttempted: model,
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
        break;
      } catch (e) {
        final sanitizedMsg = sanitizeError(e.toString());
        final fallbackReason =
            'Network/Transport error contacting Gemini: $sanitizedMsg';

        _logDiagnostic(
          model: model,
          status: null,
          candidates: 0,
          hasGrounding: false,
          places: 0,
          fallback: fallbackReason,
          error: sanitizedMsg,
        );

        lastResult = GeminiMapsDiscoveryResult(
          errorMessage: sanitizedMsg,
          candidateCount: 0,
          hasGroundingMetadata: false,
          groundedPlaceCount: 0,
          fallbackReason: fallbackReason,
          modelAttempted: model,
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
        break;
      }
    }

    return lastResult ??
        const GeminiMapsDiscoveryResult(
          fallbackReason: 'Gemini discovery terminated unexpectedly',
          isSuccess: false,
        );
  }

  /// Sends a dynamic pharmacy discovery request grounded in Google Maps.
  /// Retained for backwards compatibility.
  Future<List<PharmacyModel>> discoverPharmacies({
    required DeviceCoordinates userCoordinates,
    int radiusMeters = 5000,
  }) async {
    final result = await discoverPharmaciesWithDiagnostics(
      userCoordinates: userCoordinates,
      radiusMeters: radiusMeters,
    );

    if (result.isSuccess) {
      return result.pharmacies;
    }

    if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
      throw GeminiMapsException(
        result.errorMessage!,
        statusCode: result.statusCode,
        isAuthError: result.statusCode == 401 || result.statusCode == 403,
        isQuotaExhausted: result.isQuotaExhausted,
        retryDelay: result.retryDelay,
      );
    }

    return result.pharmacies;
  }

  /// Parses the Gemini API response, extracting verified place citations from either:
  /// 1. Interactions API (`steps` -> `type == 'model_output'` -> `content` -> `annotations` with `place_citation`)
  /// 2. generateContent API (`candidates` -> `groundingMetadata` -> `groundingChunks` -> `maps`)
  ///
  /// Never fabricates missing entities or parses unstructured prose as guaranteed data.
  List<PharmacyModel> parseGroundingResponse(
    Map<String, dynamic> responseJson, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final results = <PharmacyModel>[];
    final seenIds = <String>{};
    final seenNames = <String>{};

    void addPharmacy({
      required String name,
      String? placeId,
      String? mapsUri,
      String? address,
      double? lat,
      double? lng,
    }) {
      final cleanName = name.trim();
      if (cleanName.isEmpty) return;

      final normalizedName = PharmacyModel.normalizeNameForComparison(cleanName);
      final cleanPlaceId = (placeId ?? '').trim();
      final dedupeKey = cleanPlaceId.isNotEmpty ? cleanPlaceId : normalizedName;

      if (seenIds.contains(dedupeKey) ||
          (normalizedName.isNotEmpty && seenNames.contains(normalizedName))) {
        return;
      }
      seenIds.add(dedupeKey);
      if (normalizedName.isNotEmpty) {
        seenNames.add(normalizedName);
      }

      final pharmacy = PharmacyModel.fromGoogleMapsGrounding(
        name: cleanName,
        placeId: cleanPlaceId.isNotEmpty ? cleanPlaceId : null,
        mapsUri: mapsUri?.trim().isNotEmpty == true ? mapsUri!.trim() : null,
        address: address?.trim(),
        latitude: lat,
        longitude: lng,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      results.add(pharmacy);
    }

    // 1. Parse Interactions API format (steps -> model_output -> content -> annotations)
    final steps = responseJson['steps'];
    if (steps is List) {
      for (final step in steps) {
        if (step is! Map) continue;
        final content = step['content'];
        if (content is! List) continue;

        for (final block in content) {
          if (block is! Map) continue;
          final annotations = block['annotations'];
          if (annotations is! List) continue;

          for (final ann in annotations) {
            if (ann is! Map) continue;
            final citation = ann['place_citation'] is Map
                ? ann['place_citation'] as Map
                : ann;

            final name = (citation['name'] ?? citation['title'] ?? '').toString().trim();
            final placeId = (citation['place_id'] ?? citation['placeId'] ?? '').toString().trim();
            final url = (citation['url'] ?? citation['uri'] ?? '').toString().trim();
            final address = (citation['address'] ?? '').toString().trim();

            double? lat;
            double? lng;
            final latLng = citation['latLng'] ?? citation['location'];
            if (latLng is Map) {
              lat = (latLng['latitude'] as num?)?.toDouble();
              lng = (latLng['longitude'] as num?)?.toDouble();
            } else if (citation['latitude'] != null && citation['longitude'] != null) {
              lat = (citation['latitude'] as num?)?.toDouble();
              lng = (citation['longitude'] as num?)?.toDouble();
            }

            if (name.isNotEmpty || placeId.isNotEmpty || url.isNotEmpty) {
              addPharmacy(
                name: name.isNotEmpty ? name : 'Pharmacy $placeId',
                placeId: placeId.isNotEmpty ? placeId : null,
                mapsUri: url.isNotEmpty ? url : null,
                address: address.isNotEmpty ? address : null,
                lat: lat,
                lng: lng,
              );
            }
          }
        }
      }
    }

    // 2. Parse generateContent format (candidates -> groundingMetadata -> groundingChunks)
    final candidates = responseJson['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final candidate = candidates.first;
      if (candidate is Map) {
        final groundingMetadata = candidate['groundingMetadata'];
        if (groundingMetadata is Map) {
          final chunks = groundingMetadata['groundingChunks'];
          if (chunks is List) {
            for (final rawChunk in chunks) {
              if (rawChunk is! Map) continue;
              final mapsData = rawChunk['maps'] is Map ? rawChunk['maps'] as Map : rawChunk;
              final webData = rawChunk['web'] is Map ? rawChunk['web'] as Map : null;

              final title = (mapsData['title'] ?? webData?['title'] ?? mapsData['name'] ?? '').toString().trim();
              if (title.isEmpty) continue;

              final placeId = (mapsData['placeId'] ?? mapsData['place_id'] ?? '').toString().trim();
              final uri = (mapsData['uri'] ?? webData?['uri'] ?? mapsData['url'] ?? '').toString().trim();

              double? placeLat;
              double? placeLng;
              final latLng = mapsData['latLng'] ?? mapsData['location'];
              if (latLng is Map) {
                placeLat = (latLng['latitude'] as num?)?.toDouble();
                placeLng = (latLng['longitude'] as num?)?.toDouble();
              }

              addPharmacy(
                name: title,
                placeId: placeId.isNotEmpty ? placeId : null,
                mapsUri: uri.isNotEmpty ? uri : null,
                address: (mapsData['address'] ?? '').toString().trim(),
                lat: placeLat,
                lng: placeLng,
              );
            }
          }
        }
      }
    }

    return results;
  }

  static void _logDiagnostic({
    required String model,
    required int? status,
    required int candidates,
    required bool hasGrounding,
    required int places,
    required String? fallback,
    String? error,
    int? latencyMs,
  }) {
    debugPrint(
      '[Gemini Maps Diagnostic] endpoint=$interactionsEndpointUrl model=$model '
      'status=${status != null ? "HTTP $status" : "None"} '
      'candidates=$candidates hasGrounding=$hasGrounding places=$places '
      'latency=${latencyMs != null ? "${latencyMs}ms" : "N/A"} '
      'fallback=${fallback ?? "None"}'
      '${error != null ? " error=$error" : ""}',
    );
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
        final sanitizedBody = sanitizeError(responseBody);
        if (response.statusCode == 403 || response.statusCode == 401) {
          throw GeminiMapsException(
            'Gemini API authentication failed (HTTP ${response.statusCode}): $sanitizedBody',
            statusCode: response.statusCode,
            isAuthError: true,
          );
        }
        if (response.statusCode == 429) {
          Duration? retryDelay;
          String? cleanMessage;
          try {
            final decoded = jsonDecode(responseBody);
            if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
              final errMap = decoded['error'] as Map<String, dynamic>;
              cleanMessage = errMap['message']?.toString();
              final details = errMap['details'];
              if (details is List) {
                for (final item in details) {
                  if (item is Map && item['retryDelay'] != null) {
                    final str = item['retryDelay'].toString();
                    final secs = double.tryParse(str.replaceAll('s', ''));
                    if (secs != null) {
                      retryDelay = Duration(milliseconds: (secs * 1000).round());
                    }
                  }
                }
              }
            }
          } catch (_) {}

          if (retryDelay == null) {
            final header = response.headers.value('retry-after');
            if (header != null) {
              final s = int.tryParse(header);
              if (s != null) {
                retryDelay = Duration(seconds: s);
              }
            }
          }

          final msg = cleanMessage != null
              ? sanitizeError(cleanMessage)
              : 'Gemini Maps grounding rate limit or quota exceeded (HTTP 429).';

          throw GeminiMapsException(
            msg,
            statusCode: 429,
            isQuotaExhausted: true,
            retryDelay: retryDelay,
          );
        }
        throw GeminiMapsException(
          'Gemini Maps grounding request failed with HTTP ${response.statusCode}: $sanitizedBody',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const GeminiMapsException(
          'Malformed JSON response received from Gemini grounding API.',
        );
      }
      return decoded;
    } on SocketException catch (e) {
      throw GeminiMapsException('Network connection error: ${sanitizeError(e.message)}');
    } on TimeoutException {
      throw const GeminiMapsException(
        'Request to Gemini Google Maps grounding timed out. Please check your network connection.',
      );
    } finally {
      client.close();
    }
  }
}
