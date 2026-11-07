import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/pharmacy_model.dart';
import 'overpass_pharmacy_service.dart';

enum MapboxErrorType {
  none,
  notConfigured,
  insecureSecretToken,
  invalidToken,
  rateLimited,
  timeout,
  offline,
  serverUnavailable,
  malformedResponse,
}

class MapboxPharmacyException implements Exception {
  final MapboxErrorType type;
  final String message;
  final int? statusCode;

  const MapboxPharmacyException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Service that queries the Mapbox Search Box API v1 Category endpoint
/// (`GET /search/searchbox/v1/category/pharmacy`) around the user's real device coordinates.
///
/// SECURITY & TERMS COMPLIANCE:
/// - Never hard-codes or logs any access token.
/// - Explicitly refuses secret tokens (`sk.*`) in mobile client code; requires a
///   restricted public token (`pk.*`) with `SEARCH:READ` scope.
/// - Complies with Mapbox Search Box API "Temporary Results" storage terms:
///   results are NEVER persisted to disk, `SharedPreferences`, or Firestore.
class MapboxPharmacyService {
  static const String defaultCategoryEndpoint =
      'https://api.mapbox.com/search/searchbox/v1/category/pharmacy';
  static const String defaultTilequeryBaseUrl =
      'https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/tilequery';
  static const int maxCategoryResultsLimit = 25;

  static const String _dartDefineToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const MethodChannel _platformChannel = MethodChannel(
    'com.medscan.pro/document_picker',
  );

  final http.Client _httpClient;
  final String endpointUrl;
  final String tilequeryBaseUrl;
  final bool enableTilequeryFallback;
  final Duration requestTimeout;
  final String? _injectedAccessToken;
  String? _cachedChannelToken;

  MapboxPharmacyService({
    http.Client? httpClient,
    this.endpointUrl = defaultCategoryEndpoint,
    this.tilequeryBaseUrl = defaultTilequeryBaseUrl,
    this.enableTilequeryFallback = true,
    this.requestTimeout = const Duration(seconds: 10),
    String? accessToken,
  }) : _httpClient = httpClient ?? http.Client(),
       _injectedAccessToken = accessToken;

  /// Resolves the configured Mapbox token without ever logging or exposing its raw value.
  Future<String> resolveAccessToken() async {
    if (_injectedAccessToken != null) {
      return _injectedAccessToken.trim();
    }
    if (_dartDefineToken.trim().isNotEmpty) {
      return _dartDefineToken.trim();
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return '';
    }
    if (_cachedChannelToken != null) {
      return _cachedChannelToken!;
    }
    try {
      final token = await _platformChannel
          .invokeMethod<String>('getMapboxAccessToken')
          .timeout(const Duration(seconds: 2), onTimeout: () => '');
      _cachedChannelToken = (token ?? '').trim();
      return _cachedChannelToken!;
    } catch (_) {
      return '';
    }
  }

  /// Returns true if a valid public (`pk.*`) Mapbox token is currently configured.
  Future<bool> isConfiguredWithValidPublicToken() async {
    final token = await resolveAccessToken();
    return token.startsWith('pk.') && token.length > 10;
  }

  /// Validates the client token format without revealing the token in error messages.
  static void validateClientToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.notConfigured,
        message:
            'Mapbox access token is not configured. Add MAPBOX_ACCESS_TOKEN=pk.... to your gitignored .env file or pass --dart-define=MAPBOX_ACCESS_TOKEN=pk....',
      );
    }
    if (trimmed.startsWith('sk.')) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.insecureSecretToken,
        message:
            'Security error: Secret Mapbox tokens (sk.*) must never be used in a mobile client APK. Please configure a restricted public token (pk.*) with SEARCH:READ scope.',
      );
    }
    if (!trimmed.startsWith('pk.')) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.invalidToken,
        message:
            'Invalid Mapbox token prefix. A public Mapbox token starting with "pk." is required.',
      );
    }
  }

  /// Computes a geographic bounding box (`minLon,minLat,maxLon,maxLat`) around
  /// [latitude] and [longitude] for [radiusMeters].
  static String buildBoundingBoxParam({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) {
    final safeRadius = radiusMeters.clamp(100, 50000).toDouble();
    // 1 degree of latitude is ~111,320 meters
    final latDelta = safeRadius / 111320.0;
    final cosLat = math
        .cos(latitude * (math.pi / 180.0))
        .abs()
        .clamp(0.01, 1.0);
    final lonDelta = safeRadius / (111320.0 * cosLat);

    final minLat = (latitude - latDelta).clamp(-90.0, 90.0);
    final maxLat = (latitude + latDelta).clamp(-90.0, 90.0);
    final minLon = (longitude - lonDelta).clamp(-180.0, 180.0);
    final maxLon = (longitude + lonDelta).clamp(-180.0, 180.0);

    return '${minLon.toStringAsFixed(6)},'
        '${minLat.toStringAsFixed(6)},'
        '${maxLon.toStringAsFixed(6)},'
        '${maxLat.toStringAsFixed(6)}';
  }

  /// Builds the Mapbox Search Box API v1 Category request URI.
  static Uri buildCategorySearchUri({
    required String baseEndpoint,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String accessToken,
    int limit = maxCategoryResultsLimit,
  }) {
    final safeLimit = limit.clamp(1, maxCategoryResultsLimit);
    final proximity =
        '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}';
    final bbox = buildBoundingBoxParam(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    final baseUri = Uri.parse(baseEndpoint);
    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'proximity': proximity,
        'bbox': bbox,
        'limit': safeLimit.toString(),
        'language': 'en',
        'access_token': accessToken,
      },
    );
  }

  /// Queries Mapbox Search Box API `/category/pharmacy` for real pharmacies near
  /// [latitude] and [longitude] within [radiusMeters].
  ///
  /// Does NOT persist results to disk or SharedPreferences (Mapbox ToS compliance).
  Future<NearbyPharmacyFetchResult> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    int radiusMeters = OverpassPharmacyService.defaultRadiusMeters,
  }) async {
    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0 ||
        (latitude == 0.0 && longitude == 0.0)) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.malformedResponse,
        message: 'Invalid device coordinates supplied for pharmacy search.',
      );
    }

    final token = await resolveAccessToken();
    validateClientToken(token);

    final uri = buildCategorySearchUri(
      baseEndpoint: endpointUrl,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      accessToken: token,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _httpClient
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'MedScanPro-FYP/1.0 (Android; Flutter)',
            },
          )
          .timeout(requestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw MapboxPharmacyException(
          type: MapboxErrorType.invalidToken,
          statusCode: response.statusCode,
          message:
              'Mapbox rejected the access token (HTTP ${response.statusCode}). Verify that your public token (pk.*) is active and has the SEARCH:READ scope.',
        );
      }

      if (response.statusCode == 429) {
        throw const MapboxPharmacyException(
          type: MapboxErrorType.rateLimited,
          statusCode: 429,
          message:
              'Mapbox Search Box API rate limit reached (HTTP 429). Please wait a moment and try again.',
        );
      }

      if (response.statusCode >= 500) {
        throw MapboxPharmacyException(
          type: MapboxErrorType.serverUnavailable,
          statusCode: response.statusCode,
          message:
              'Mapbox Search Box service is temporarily unavailable (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MapboxPharmacyException(
          type: MapboxErrorType.serverUnavailable,
          statusCode: response.statusCode,
          message:
              'Mapbox Search Box service returned an unexpected status (HTTP ${response.statusCode}).',
        );
      }

      var pharmacies = parseMapboxResponseBody(
        response.body,
        userLatitude: latitude,
        userLongitude: longitude,
        maxRadiusMeters: radiusMeters,
      );

      // In regions like Pakistan where Mapbox Search Box /category/pharmacy returns
      // 0 indexed POIs, supplement via Mapbox Tilequery API (mapbox-streets-v8 poi_label)
      if (pharmacies.isEmpty && enableTilequeryFallback) {
        try {
          // Tilequery API limits radius to maximum 10,000 meters (HTTP 422 if exceeded)
          final tilequeryRadius = radiusMeters.clamp(1, 10000);
          final tqUri =
              Uri.parse(
                '$tilequeryBaseUrl/${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}.json',
              ).replace(
                queryParameters: {
                  'layers': 'poi_label',
                  'radius': tilequeryRadius.toString(),
                  'limit': '50',
                  'access_token': token,
                },
              );
          final tqResp = await _httpClient
              .get(
                tqUri,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'MedScanPro-FYP/1.0 (Android; Flutter)',
                },
              )
              .timeout(requestTimeout);
          if (tqResp.statusCode >= 200 && tqResp.statusCode < 300) {
            pharmacies = parseMapboxTilequeryResponseBody(
              tqResp.body,
              userLatitude: latitude,
              userLongitude: longitude,
              maxRadiusMeters: radiusMeters,
            );
          }
        } catch (_) {
          // Keep empty Search Box result if Tilequery supplement fails
        }
      }

      stopwatch.stop();
      return NearbyPharmacyFetchResult(
        pharmacies: pharmacies,
        radiusMeters: radiusMeters,
        userLatitude: latitude,
        userLongitude: longitude,
        fetchedAt: DateTime.now(),
        isFromCache: false,
        isStaleCache: false,
        sourceProvider: 'mapbox',
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: response.statusCode,
        httpStatusLabel: '200 OK (Mapbox)',
      );
    } on MapboxPharmacyException {
      rethrow;
    } on TimeoutException {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.timeout,
        message: 'The Mapbox Search Box pharmacy request timed out.',
      );
    } on SocketException {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.offline,
        message:
            'Unable to reach Mapbox Search Box API. Please check your internet connection.',
      );
    } catch (_) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.serverUnavailable,
        message:
            'A network error occurred while querying the Mapbox pharmacy service.',
      );
    }
  }

  /// Defensively parses Mapbox Search Box GeoJSON `FeatureCollection`, filters to
  /// [maxRadiusMeters], deduplicates records, and sorts nearest-first.
  static List<PharmacyModel> parseMapboxResponseBody(
    String responseBody, {
    required double userLatitude,
    required double userLongitude,
    int? maxRadiusMeters,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.malformedResponse,
        message: 'Received an empty response from Mapbox Search Box API.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.malformedResponse,
        message: 'Received malformed JSON from Mapbox Search Box API.',
      );
    }

    if (decoded is! Map) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.malformedResponse,
        message: 'Unexpected JSON root structure from Mapbox Search Box API.',
      );
    }

    final rawFeatures = decoded['features'];
    if (rawFeatures is! List) {
      throw const MapboxPharmacyException(
        type: MapboxErrorType.malformedResponse,
        message: 'Mapbox Search Box response is missing the "features" list.',
      );
    }

    final results = <PharmacyModel>[];

    for (final item in rawFeatures) {
      if (item is! Map) continue;
      final featureMap = Map<String, dynamic>.from(item);
      final model = PharmacyModel.fromMapboxFeature(
        featureMap,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      if (model == null || model.isDemo) continue;

      if (maxRadiusMeters != null && model.distanceMeters > maxRadiusMeters) {
        continue;
      }

      final isDuplicate = results.any(
        (existing) => existing.isNearDuplicateOf(model),
      );
      if (isDuplicate) continue;

      results.add(model);
    }

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  /// Parses Mapbox Tilequery API v4 `poi_label` GeoJSON features, filtering to
  /// genuine pharmacy POIs within [maxRadiusMeters] and sorting nearest-first.
  static List<PharmacyModel> parseMapboxTilequeryResponseBody(
    String responseBody, {
    required double userLatitude,
    required double userLongitude,
    int? maxRadiusMeters,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map) return const [];
    final rawFeatures = decoded['features'];
    if (rawFeatures is! List) return const [];

    final results = <PharmacyModel>[];
    for (final item in rawFeatures) {
      if (item is! Map) continue;
      final model = PharmacyModel.fromMapboxTilequeryFeature(
        Map<String, dynamic>.from(item),
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      if (model == null || model.isDemo) continue;
      if (maxRadiusMeters != null && model.distanceMeters > maxRadiusMeters) {
        continue;
      }
      if (results.any((e) => e.isNearDuplicateOf(model))) continue;
      results.add(model);
    }

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }
}
