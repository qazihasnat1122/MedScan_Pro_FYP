import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/pharmacy_model.dart';

enum OverpassErrorType {
  none,
  offline,
  networkError,
  timeout,
  rateLimited,
  serverUnavailable,
  malformedResponse,
}

class OverpassPharmacyException implements Exception {
  final OverpassErrorType type;
  final String message;
  final int? statusCode;

  const OverpassPharmacyException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class NearbyPharmacyFetchResult {
  final List<PharmacyModel> pharmacies;
  final int radiusMeters;
  final double userLatitude;
  final double userLongitude;
  final DateTime fetchedAt;
  final bool isFromCache;
  final bool isStaleCache;
  final String? cacheNotice;
  final String sourceProvider;
  final int? requestDurationMs;
  final int? httpStatusCode;
  final String? httpStatusLabel;
  final int? geminiStatusCode;
  final String? geminiErrorMessage;
  final int? geminiCandidateCount;
  final bool? geminiHasGroundingMetadata;
  final int? geminiGroundedPlaceCount;
  final String? geminiFallbackReason;
  final String? geminiModelAttempted;
  final bool isQuotaExhausted;

  const NearbyPharmacyFetchResult({
    required this.pharmacies,
    required this.radiusMeters,
    required this.userLatitude,
    required this.userLongitude,
    required this.fetchedAt,
    this.isFromCache = false,
    this.isStaleCache = false,
    this.cacheNotice,
    this.sourceProvider = 'osm',
    this.requestDurationMs,
    this.httpStatusCode,
    this.httpStatusLabel,
    this.geminiStatusCode,
    this.geminiErrorMessage,
    this.geminiCandidateCount,
    this.geminiHasGroundingMetadata,
    this.geminiGroundedPlaceCount,
    this.geminiFallbackReason,
    this.geminiModelAttempted,
    this.isQuotaExhausted = false,
  });
}

class _CachedPharmacyEntry {
  final List<PharmacyModel> pharmacies;
  final int radiusMeters;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const _CachedPharmacyEntry({
    required this.pharmacies,
    required this.radiusMeters,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

class _OverpassQueryResult {
  final List<PharmacyModel> pharmacies;
  final int statusCode;
  final String statusLabel;
  final String provider;

  const _OverpassQueryResult({
    required this.pharmacies,
    required this.statusCode,
    required this.statusLabel,
    required this.provider,
  });
}

/// Service that queries OpenStreetMap's public Overpass API for `amenity=pharmacy`
/// around the user's real device coordinates.
///
/// Centralizes public Overpass endpoint configuration, uses the unified `nwr`
/// spatial query, enforces explicit per-request and total timeouts, and performs
/// bounded sequential retry across configured public endpoints on transient failures.
class OverpassPharmacyService {
  static const String defaultEndpoint =
      'https://overpass-api.de/api/interpreter';
  static const String fallbackEndpoint =
      'https://lz4.overpass-api.de/api/interpreter';
  static const String nominatimEndpoint =
      'https://nominatim.openstreetmap.org/search';

  /// Single source of truth for public Overpass interpreter endpoints tried sequentially.
  static const List<String> defaultEndpoints = [
    defaultEndpoint,
    fallbackEndpoint,
  ];

  static const int defaultRadiusMeters = 5000;

  final http.Client _httpClient;
  final List<String> endpoints;
  final Duration requestTimeout;
  final Duration totalTimeout;
  final Duration retryBackoff;
  final Duration cacheTtl;
  final bool enableNominatimFallback;

  final Map<String, _CachedPharmacyEntry> _cache = {};
  final Map<String, Future<NearbyPharmacyFetchResult>> _inFlightRequests = {};

  OverpassPharmacyService({
    http.Client? httpClient,
    String? endpointUrl,
    List<String>? endpoints,
    this.requestTimeout = const Duration(seconds: 12),
    this.totalTimeout = const Duration(seconds: 28),
    this.retryBackoff = const Duration(milliseconds: 400),
    this.cacheTtl = const Duration(minutes: 10),
    bool? enableNominatimFallback,
  }) : _httpClient = httpClient ?? http.Client(),
       endpoints = endpoints != null && endpoints.isNotEmpty
           ? List.unmodifiable(endpoints)
           : (endpointUrl != null
                 ? List.unmodifiable([endpointUrl])
                 : defaultEndpoints),
       enableNominatimFallback =
           enableNominatimFallback ??
           !Platform.environment.containsKey('FLUTTER_TEST');

  String get endpointUrl => endpoints.first;

  /// Builds the Overpass QL query for nodes, ways, and relations tagged `amenity=pharmacy`
  /// using the single-pass `nwr` spatial filter.
  static String buildOverpassQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int timeoutSeconds = 25,
  }) {
    final safeRadius = radiusMeters.clamp(100, 50000);
    final safeTimeout = timeoutSeconds.clamp(5, 60);
    final latStr = latitude.toStringAsFixed(6);
    final lonStr = longitude.toStringAsFixed(6);
    return '[out:json][timeout:$safeTimeout];'
        'nwr["amenity"="pharmacy"](around:$safeRadius,$latStr,$lonStr);'
        'out center tags;';
  }

  String _cacheKey(double latitude, double longitude, int radiusMeters) {
    // Round to ~110m grid cell so tiny GPS jitter doesn't spam Overpass
    final latKey = latitude.toStringAsFixed(3);
    final lonKey = longitude.toStringAsFixed(3);
    return '$latKey,$lonKey:$radiusMeters';
  }

  void clearCache() => _cache.clear();

  /// Fetches nearby pharmacies from OpenStreetMap Overpass API.
  /// - Deduplicates concurrent identical requests unless [forceRefresh] is true.
  /// - Uses in-memory cache when fresh unless [forceRefresh] is true.
  /// - Performs bounded sequential retry across [endpoints] on transient timeouts/5xx.
  /// - If all live attempts fail and a previous cache entry exists for this location+radius,
  ///   returns the cached data clearly labeled as stale (`isStaleCache: true`).
  Future<NearbyPharmacyFetchResult> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    int radiusMeters = defaultRadiusMeters,
    bool forceRefresh = false,
  }) async {
    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0 ||
        (latitude == 0.0 && longitude == 0.0)) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Invalid device coordinates supplied for pharmacy search.',
      );
    }

    final key = _cacheKey(latitude, longitude, radiusMeters);
    final now = DateTime.now();
    final existingCache = _cache[key];

    if (!forceRefresh && existingCache != null) {
      final age = now.difference(existingCache.timestamp);
      if (age <= cacheTtl) {
        return NearbyPharmacyFetchResult(
          pharmacies: existingCache.pharmacies,
          radiusMeters: radiusMeters,
          userLatitude: latitude,
          userLongitude: longitude,
          fetchedAt: existingCache.timestamp,
          isFromCache: true,
          isStaleCache: false,
        );
      }
    }

    if (!forceRefresh && _inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key]!;
    }

    final requestFuture = _executeWithCacheFallback(
      key: key,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      existingCache: existingCache,
    );

    _inFlightRequests[key] = requestFuture;
    try {
      return await requestFuture;
    } finally {
      if (identical(_inFlightRequests[key], requestFuture)) {
        _inFlightRequests.remove(key);
      }
    }
  }

  Future<NearbyPharmacyFetchResult> _executeWithCacheFallback({
    required String key,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required _CachedPharmacyEntry? existingCache,
  }) async {
    final query = buildOverpassQuery(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final queryResult = await _postQueryWithBoundedRetry(
        query: query,
        userLatitude: latitude,
        userLongitude: longitude,
        radiusMeters: radiusMeters,
      );
      stopwatch.stop();

      final fetchedAt = DateTime.now();
      _cache[key] = _CachedPharmacyEntry(
        pharmacies: queryResult.pharmacies,
        radiusMeters: radiusMeters,
        latitude: latitude,
        longitude: longitude,
        timestamp: fetchedAt,
      );

      return NearbyPharmacyFetchResult(
        pharmacies: queryResult.pharmacies,
        radiusMeters: radiusMeters,
        userLatitude: latitude,
        userLongitude: longitude,
        fetchedAt: fetchedAt,
        isFromCache: false,
        isStaleCache: false,
        sourceProvider: queryResult.provider,
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: queryResult.statusCode,
        httpStatusLabel: queryResult.statusLabel,
      );
    } on OverpassPharmacyException catch (e) {
      stopwatch.stop();
      if (existingCache != null) {
        return NearbyPharmacyFetchResult(
          pharmacies: existingCache.pharmacies,
          radiusMeters: radiusMeters,
          userLatitude: latitude,
          userLongitude: longitude,
          fetchedAt: existingCache.timestamp,
          isFromCache: true,
          isStaleCache: true,
          cacheNotice:
              'Showing cached results from an earlier search because the live map service failed: ${e.message}',
          sourceProvider: 'osm_cache',
          requestDurationMs: stopwatch.elapsedMilliseconds,
          httpStatusCode: e.statusCode,
          httpStatusLabel: 'Cached (${e.statusCode ?? 'Offline'})',
        );
      }
      rethrow;
    }
  }

  Future<_OverpassQueryResult> _postQueryWithBoundedRetry({
    required String query,
    required double userLatitude,
    required double userLongitude,
    required int radiusMeters,
  }) async {
    final stopwatch = Stopwatch()..start();
    OverpassPharmacyException? lastException;

    for (int i = 0; i < endpoints.length; i++) {
      final currentEndpoint = endpoints[i];
      final elapsed = stopwatch.elapsed;
      final remainingBudget = totalTimeout - elapsed;

      if (i > 0 && remainingBudget <= const Duration(seconds: 1)) {
        break;
      }

      // For 25km radius queries, Overpass cluster workers frequently time out.
      // Use bounded attemptTimeout (max 7s for large radius >= 20km) so we don't block
      // for 24s before switching to bounded Nominatim search.
      Duration attemptTimeout =
          remainingBudget < requestTimeout && remainingBudget > Duration.zero
          ? remainingBudget
          : requestTimeout;
      if (radiusMeters >= 20000 &&
          attemptTimeout > const Duration(seconds: 7)) {
        attemptTimeout = const Duration(seconds: 7);
      }

      try {
        final uri = Uri.parse(currentEndpoint);
        final response = await _httpClient
            .post(
              uri,
              headers: const {
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=utf-8',
                'Accept': 'application/json',
                'User-Agent': 'MedScanPro-FYP/1.0 (Android; Flutter)',
              },
              body: {'data': query},
            )
            .timeout(attemptTimeout);

        if (response.statusCode == 429) {
          throw const OverpassPharmacyException(
            type: OverpassErrorType.rateLimited,
            statusCode: 429,
            message:
                'The public OpenStreetMap Overpass service is temporarily rate-limiting requests (HTTP 429). Please wait 15–30 seconds and tap Retry.',
          );
        }

        if (response.statusCode == 504) {
          throw const OverpassPharmacyException(
            type: OverpassErrorType.timeout,
            statusCode: 504,
            message:
                'The OpenStreetMap Overpass server timed out while searching this area (HTTP 504). Try a smaller search radius (5 km) or tap Retry.',
          );
        }

        if (response.statusCode == 500 ||
            response.statusCode == 502 ||
            response.statusCode == 503) {
          throw OverpassPharmacyException(
            type: OverpassErrorType.serverUnavailable,
            statusCode: response.statusCode,
            message:
                'The public OpenStreetMap Overpass server is currently busy (HTTP ${response.statusCode}). Please tap Retry in a few seconds.',
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw OverpassPharmacyException(
            type: OverpassErrorType.serverUnavailable,
            statusCode: response.statusCode,
            message:
                'Pharmacy map service returned an unexpected status (HTTP ${response.statusCode}).',
          );
        }

        final pharmacies = parseOverpassResponseBody(
          response.body,
          userLatitude: userLatitude,
          userLongitude: userLongitude,
        );

        final label = i == 0 ? '200 OK (Overpass)' : '200 OK (Overpass Mirror)';
        return _OverpassQueryResult(
          pharmacies: pharmacies,
          statusCode: response.statusCode,
          statusLabel: label,
          provider: 'osm_overpass',
        );
      } on OverpassPharmacyException catch (e) {
        lastException = e;
        // Do not retry on explicit rate-limit (429) or malformed payload
        final shouldRetry =
            (e.type == OverpassErrorType.timeout ||
                e.type == OverpassErrorType.serverUnavailable ||
                e.type == OverpassErrorType.networkError) &&
            i + 1 < endpoints.length;
        if (!shouldRetry) {
          break;
        }
      } on TimeoutException {
        lastException = const OverpassPharmacyException(
          type: OverpassErrorType.timeout,
          message:
              'The OpenStreetMap Overpass request timed out. The public map server may be busy — try a 5 km radius or tap Retry.',
        );
        if (i + 1 >= endpoints.length) {
          break;
        }
      } on SocketException {
        lastException = const OverpassPharmacyException(
          type: OverpassErrorType.offline,
          message:
              'Unable to reach the OpenStreetMap server. Please check your Wi-Fi or mobile data connection and tap Retry.',
        );
        if (i + 1 >= endpoints.length) {
          break;
        }
      } on http.ClientException {
        lastException = const OverpassPharmacyException(
          type: OverpassErrorType.networkError,
          message:
              'A network transport error occurred while contacting the OpenStreetMap pharmacy service. Please tap Retry.',
        );
        if (i + 1 >= endpoints.length) {
          break;
        }
      } catch (_) {
        lastException = const OverpassPharmacyException(
          type: OverpassErrorType.networkError,
          message:
              'Unable to reach the OpenStreetMap pharmacy service. Please check your connection and tap Retry.',
        );
        if (i + 1 >= endpoints.length) {
          break;
        }
      }

      if (retryBackoff > Duration.zero &&
          stopwatch.elapsed + retryBackoff < totalTimeout) {
        await Future<void>.delayed(retryBackoff);
      }
    }

    // When Overpass interpreter workers are at capacity (502/503/504 or timeout),
    // fall back once to bounded OpenStreetMap Nominatim amenity=pharmacy search
    if (enableNominatimFallback &&
        lastException != null &&
        (lastException.type == OverpassErrorType.timeout ||
            lastException.type == OverpassErrorType.serverUnavailable)) {
      try {
        final nominatimList = await _fetchBoundedNominatimPharmacies(
          userLatitude: userLatitude,
          userLongitude: userLongitude,
          radiusMeters: radiusMeters,
        );
        return _OverpassQueryResult(
          pharmacies: nominatimList,
          statusCode: 200,
          statusLabel: '200 OK (Nominatim Fallback)',
          provider: 'osm_nominatim',
        );
      } catch (_) {
        // Rethrow original Overpass exception if Nominatim fallback also fails
      }
    }

    throw lastException ??
        const OverpassPharmacyException(
          type: OverpassErrorType.timeout,
          message:
              'The OpenStreetMap Overpass request timed out. The public map server may be busy — try a 5 km radius or tap Retry.',
        );
  }

  /// Queries OpenStreetMap's bounded Nominatim API (`q=pharmacy`, `bounded=1`)
  /// when Overpass interpreter workers are overloaded, filtering strictly to [radiusMeters].
  Future<List<PharmacyModel>> _fetchBoundedNominatimPharmacies({
    required double userLatitude,
    required double userLongitude,
    required int radiusMeters,
  }) async {
    final safeRadius = radiusMeters.clamp(100, 50000).toDouble();
    final latDelta = safeRadius / 111320.0;
    final cosLat = math
        .cos(userLatitude * (math.pi / 180.0))
        .abs()
        .clamp(0.01, 1.0);
    final lonDelta = safeRadius / (111320.0 * cosLat);

    final leftLon = (userLongitude - lonDelta).clamp(-180.0, 180.0);
    final rightLon = (userLongitude + lonDelta).clamp(-180.0, 180.0);
    final topLat = (userLatitude + latDelta).clamp(-90.0, 90.0);
    final bottomLat = (userLatitude - latDelta).clamp(-90.0, 90.0);

    final viewbox =
        '${leftLon.toStringAsFixed(6)},'
        '${topLat.toStringAsFixed(6)},'
        '${rightLon.toStringAsFixed(6)},'
        '${bottomLat.toStringAsFixed(6)}';

    final uri = Uri.parse(nominatimEndpoint).replace(
      queryParameters: {
        'q': 'pharmacy',
        'format': 'jsonv2',
        'addressdetails': '1',
        'extratags': '1',
        'accept-language': 'en',
        'limit': '50',
        'viewbox': viewbox,
        'bounded': '1',
      },
    );

    final response = await _httpClient
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'MedScanPro-FYP/1.0 (Android; Flutter)',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OverpassPharmacyException(
        type: OverpassErrorType.serverUnavailable,
        statusCode: response.statusCode,
        message:
            'OpenStreetMap Nominatim fallback returned HTTP ${response.statusCode}.',
      );
    }

    return parseNominatimResponseBody(
      response.body,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      maxRadiusMeters: radiusMeters,
    );
  }

  /// Parses OpenStreetMap Nominatim `jsonv2` pharmacy results, filtering strictly
  /// to [maxRadiusMeters], deduplicating, and sorting nearest-first.
  static List<PharmacyModel> parseNominatimResponseBody(
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
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Malformed JSON from OpenStreetMap Nominatim service.',
      );
    }

    if (decoded is! List) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Unexpected JSON root from OpenStreetMap Nominatim service.',
      );
    }

    final results = <PharmacyModel>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final model = PharmacyModel.fromNominatimElement(
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

  /// Defensively parses raw Overpass JSON, inspects server error remarks even on HTTP 200,
  /// deduplicates records, computes straight-line distances from [userLatitude]/[userLongitude],
  /// and sorts nearest-first.
  static List<PharmacyModel> parseOverpassResponseBody(
    String responseBody, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Received an empty response from the Overpass server.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      final lower = trimmed.toLowerCase();
      if (lower.contains('gateway time-out') ||
          lower.contains('query timed out') ||
          lower.contains('timeout')) {
        throw const OverpassPharmacyException(
          type: OverpassErrorType.timeout,
          message:
              'The OpenStreetMap Overpass server timed out while processing the query. Try a 5 km radius or tap Retry.',
        );
      }
      if (lower.contains('too many requests') || lower.contains('rate limit')) {
        throw const OverpassPharmacyException(
          type: OverpassErrorType.rateLimited,
          message:
              'The OpenStreetMap Overpass server is temporarily rate-limiting requests. Please wait a moment and tap Retry.',
        );
      }
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message:
            'Received a malformed response from the OpenStreetMap Overpass server.',
      );
    }

    if (decoded is! Map) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Unexpected JSON structure from Overpass server.',
      );
    }

    final remark = decoded['remark']?.toString().trim() ?? '';
    final rawElements = decoded['elements'];

    if (remark.isNotEmpty &&
        (rawElements == null || (rawElements is List && rawElements.isEmpty))) {
      final lowerRemark = remark.toLowerCase();
      if (lowerRemark.contains('timed out') ||
          lowerRemark.contains('timeout')) {
        throw OverpassPharmacyException(
          type: OverpassErrorType.timeout,
          message:
              'The OpenStreetMap Overpass server timed out while searching this radius ($remark). Try a smaller radius (5 km) or tap Retry.',
        );
      }
      if (lowerRemark.contains('too many') ||
          lowerRemark.contains('rate') ||
          lowerRemark.contains('slot')) {
        throw OverpassPharmacyException(
          type: OverpassErrorType.rateLimited,
          message:
              'The OpenStreetMap Overpass server is busy with too many requests ($remark). Please wait a moment and tap Retry.',
        );
      }
      throw OverpassPharmacyException(
        type: OverpassErrorType.serverUnavailable,
        message: 'Overpass server could not complete query: $remark',
      );
    }

    if (rawElements == null) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Overpass JSON response is missing the "elements" list.',
      );
    }

    if (rawElements is! List) {
      throw const OverpassPharmacyException(
        type: OverpassErrorType.malformedResponse,
        message: 'Overpass "elements" field is not a list.',
      );
    }

    final seenKeys = <String>{};
    final results = <PharmacyModel>[];

    for (final item in rawElements) {
      if (item is! Map) continue;
      final elementMap = Map<String, dynamic>.from(item);
      final model = PharmacyModel.fromOverpassElement(
        elementMap,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      if (model == null) continue;
      if (model.isDemo) continue; // Never allow demo entries in live parsing

      final dedupKey = model.deduplicationKey;
      if (seenKeys.contains(dedupKey)) continue;

      // Also deduplicate identical-named pharmacies mapped as both a node and a way within 20m
      final isNearDuplicate = results.any((existing) {
        if (existing.name.toLowerCase() != model.name.toLowerCase()) {
          return false;
        }
        if (!existing.hasCoordinates || !model.hasCoordinates) {
          return false;
        }
        final d = PharmacyModel.calculateStraightLineDistanceMeters(
          startLatitude: existing.latitude!,
          startLongitude: existing.longitude!,
          endLatitude: model.latitude!,
          endLongitude: model.longitude!,
        );
        return d < 20.0;
      });
      if (isNearDuplicate) continue;

      seenKeys.add(dedupKey);
      results.add(model);
    }

    // Sort by nearest straight-line distance first
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }
}
