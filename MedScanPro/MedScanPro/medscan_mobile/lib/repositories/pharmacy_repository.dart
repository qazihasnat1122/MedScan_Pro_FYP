import 'package:flutter/foundation.dart';
import '../models/pharmacy_model.dart';
import '../services/gemini_maps_pharmacy_service.dart';
import '../services/location_service.dart';
import '../services/mapbox_pharmacy_service.dart';
import '../services/overpass_pharmacy_service.dart';

/// Structured evaluation report comparing Mapbox Search Box API and OpenStreetMap
/// Overpass API for the same real device coordinates and search radius.
class PharmacyProviderComparisonReport {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isMapboxConfigured;
  final int mapboxCount;
  final int mapboxWithPhoneCount;
  final int mapboxWithAddressCount;
  final int? mapboxLatencyMs;
  final String? mapboxError;
  final int overpassCount;
  final int overpassWithPhoneCount;
  final int overpassWithAddressCount;
  final int? overpassLatencyMs;
  final String? overpassError;
  final int overlappingDuplicateCount;
  final List<PharmacyModel> mergedDeduplicatedPharmacies;

  const PharmacyProviderComparisonReport({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isMapboxConfigured,
    required this.mapboxCount,
    required this.mapboxWithPhoneCount,
    required this.mapboxWithAddressCount,
    this.mapboxLatencyMs,
    this.mapboxError,
    required this.overpassCount,
    required this.overpassWithPhoneCount,
    required this.overpassWithAddressCount,
    this.overpassLatencyMs,
    this.overpassError,
    required this.overlappingDuplicateCount,
    required this.mergedDeduplicatedPharmacies,
  });
}

/// Repository supplying real nearby pharmacy locations via Mapbox Search Box API
/// (when a valid public `pk.*` token is configured) and OpenStreetMap Overpass API.
/// Strictly isolates any legacy demonstration records (`isDemo: true`) so they NEVER
/// appear in normal nearby-pharmacy results.
class PharmacyRepository {
  final GeminiMapsPharmacyService _geminiMapsService;
  final OverpassPharmacyService _overpassService;
  final MapboxPharmacyService _mapboxService;

  PharmacyRepository({
    GeminiMapsPharmacyService? geminiMapsService,
    OverpassPharmacyService? overpassService,
    MapboxPharmacyService? mapboxService,
  }) : _geminiMapsService = geminiMapsService ?? GeminiMapsPharmacyService(),
       _overpassService = overpassService ?? OverpassPharmacyService(),
       _mapboxService = mapboxService ?? MapboxPharmacyService();

  GeminiMapsPharmacyService get geminiMapsService => _geminiMapsService;
  OverpassPharmacyService get overpassService => _overpassService;
  MapboxPharmacyService get mapboxService => _mapboxService;


  /// Merges pharmacy lists from multiple providers without displaying duplicate
  /// physical pharmacies (within 35m with matching normalized names), preferring
  /// richer contact/address metadata when merging duplicates and sorting nearest-first.
  static List<PharmacyModel> mergeAndDeduplicatePharmacies(
    List<PharmacyModel> primary,
    List<PharmacyModel> secondary,
  ) {
    final merged = <PharmacyModel>[];

    for (final p in primary) {
      if (p.isDemo) continue;
      if (!merged.any((existing) => existing.isNearDuplicateOf(p))) {
        merged.add(p);
      }
    }

    for (final s in secondary) {
      if (s.isDemo) continue;
      final existingIdx = merged.indexWhere((e) => e.isNearDuplicateOf(s));
      if (existingIdx == -1) {
        merged.add(s);
      } else {
        // Enrich missing phone/address/hours from secondary if primary lacked them
        final existing = merged[existingIdx];
        final enrichedPhone = existing.hasValidPhone ? existing.phone : s.phone;
        final enrichedAddress = existing.fullAddress.isNotEmpty
            ? existing.fullAddress
            : s.fullAddress;
        final enrichedHours = existing.operatingHours.isNotEmpty
            ? existing.operatingHours
            : s.operatingHours;
        if (enrichedPhone != existing.phone ||
            enrichedAddress != existing.fullAddress ||
            enrichedHours != existing.operatingHours) {
          merged[existingIdx] = PharmacyModel(
            id: existing.id,
            osmType: existing.osmType,
            osmId: existing.osmId,
            name: existing.name,
            chainName: existing.chainName.isNotEmpty
                ? existing.chainName
                : s.chainName,
            licenseNumber: '',
            city: existing.city.isNotEmpty ? existing.city : s.city,
            area: existing.area.isNotEmpty ? existing.area : s.area,
            fullAddress: enrichedAddress,
            phone: enrichedPhone,
            operatingHours: enrichedHours,
            is24Hours: existing.is24Hours || s.is24Hours,
            isDrapLicensed: false,
            latitude: existing.latitude,
            longitude: existing.longitude,
            distanceMeters: existing.distanceMeters,
            approximateDistanceKm: existing.approximateDistanceKm,
            isDemo: false,
            dataSource: existing.dataSource,
          );
        }
      }
    }

    merged.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return merged;
  }

  /// Compares Mapbox Search Box API and OpenStreetMap Overpass API results for the
  /// exact same GPS coordinates and radius.
  Future<PharmacyProviderComparisonReport> compareProviders({
    required double latitude,
    required double longitude,
    int radiusMeters = OverpassPharmacyService.defaultRadiusMeters,
  }) async {
    final isMapboxConfigured = await _mapboxService
        .isConfiguredWithValidPublicToken();

    List<PharmacyModel> mapboxList = const [];
    int? mapboxMs;
    String? mapboxErr;

    final mapboxWatch = Stopwatch()..start();
    try {
      final res = await _mapboxService.fetchNearbyPharmacies(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      mapboxWatch.stop();
      mapboxMs = mapboxWatch.elapsedMilliseconds;
      mapboxList = res.pharmacies.where((p) => !p.isDemo).toList();
    } catch (e) {
      mapboxWatch.stop();
      mapboxMs = mapboxWatch.elapsedMilliseconds;
      mapboxErr = e.toString();
    }

    List<PharmacyModel> overpassList = const [];
    int? overpassMs;
    String? overpassErr;

    final overpassWatch = Stopwatch()..start();
    try {
      final res = await _overpassService.fetchNearbyPharmacies(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      overpassWatch.stop();
      overpassMs = overpassWatch.elapsedMilliseconds;
      overpassList = res.pharmacies.where((p) => !p.isDemo).toList();
    } catch (e) {
      overpassWatch.stop();
      overpassMs = overpassWatch.elapsedMilliseconds;
      overpassErr = e.toString();
    }

    int overlapCount = 0;
    for (final m in mapboxList) {
      if (overpassList.any((o) => o.isNearDuplicateOf(m))) {
        overlapCount++;
      }
    }

    final merged = mergeAndDeduplicatePharmacies(mapboxList, overpassList);

    return PharmacyProviderComparisonReport(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      isMapboxConfigured: isMapboxConfigured,
      mapboxCount: mapboxList.length,
      mapboxWithPhoneCount: mapboxList.where((p) => p.hasValidPhone).length,
      mapboxWithAddressCount: mapboxList
          .where((p) => p.fullAddress.trim().isNotEmpty)
          .length,
      mapboxLatencyMs: mapboxMs,
      mapboxError: mapboxErr,
      overpassCount: overpassList.length,
      overpassWithPhoneCount: overpassList.where((p) => p.hasValidPhone).length,
      overpassWithAddressCount: overpassList
          .where((p) => p.fullAddress.trim().isNotEmpty)
          .length,
      overpassLatencyMs: overpassMs,
      overpassError: overpassErr,
      overlappingDuplicateCount: overlapCount,
      mergedDeduplicatedPharmacies: merged,
    );
  }

  /// Fetches real nearby pharmacies around the device's actual coordinates.
  ///
  /// Based on live local evaluation in Pakistan:
  /// - OpenStreetMap (Overpass + bounded Nominatim fallback) provides the primary
  ///   comprehensive pharmacy listings (33–40 pharmacies per 5 km in major cities).
  /// - When a valid public Mapbox token (`pk.*`) is configured, Mapbox Search Box /
  ///   Tilequery is also queried and merged/deduplicated with OpenStreetMap results
  ///   so zero duplicate pharmacies are displayed and Mapbox acts as an immediate
  ///   supplement or fallback if OpenStreetMap is unreachable.
  /// - Guarantees that no demo or hard-coded records are ever included.
  Future<NearbyPharmacyFetchResult> fetchNearbyRealPharmacies({
    required double latitude,
    required double longitude,
    int radiusMeters = OverpassPharmacyService.defaultRadiusMeters,
    bool forceRefresh = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Primary Dynamic Discovery: Gemini with Google Maps Grounding
    GeminiMapsDiscoveryResult? geminiDiagnostic;
    try {
      geminiDiagnostic = await _geminiMapsService.discoverPharmaciesWithDiagnostics(
        userCoordinates: DeviceCoordinates(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
        ),
        radiusMeters: radiusMeters,
      );
      if (geminiDiagnostic.isSuccess && geminiDiagnostic.pharmacies.isNotEmpty) {
        stopwatch.stop();
        return NearbyPharmacyFetchResult(
          pharmacies: geminiDiagnostic.pharmacies,
          radiusMeters: radiusMeters,
          userLatitude: latitude,
          userLongitude: longitude,
          fetchedAt: DateTime.now(),
          sourceProvider: 'gemini_google_maps',
          requestDurationMs: geminiDiagnostic.latencyMs ?? stopwatch.elapsedMilliseconds,
          httpStatusCode: geminiDiagnostic.statusCode ?? 200,
          httpStatusLabel: 'Grounded with Google Maps',
          geminiStatusCode: geminiDiagnostic.statusCode,
          geminiErrorMessage: geminiDiagnostic.errorMessage,
          geminiCandidateCount: geminiDiagnostic.candidateCount,
          geminiHasGroundingMetadata: geminiDiagnostic.hasGroundingMetadata,
          geminiGroundedPlaceCount: geminiDiagnostic.groundedPlaceCount,
          geminiFallbackReason: null,
          geminiModelAttempted: geminiDiagnostic.modelAttempted,
          isQuotaExhausted: false,
        );
      }
    } catch (e) {
      debugPrint('Gemini Maps discovery diagnostic catch: $e');
    }

    final mapboxReady = await _mapboxService.isConfiguredWithValidPublicToken();

    if (!mapboxReady) {
      final result = await _overpassService.fetchNearbyPharmacies(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        forceRefresh: forceRefresh,
      );
      stopwatch.stop();
      final realOnly = result.pharmacies.where((p) => !p.isDemo).toList();

      return NearbyPharmacyFetchResult(
        pharmacies: realOnly,
        radiusMeters: result.radiusMeters,
        userLatitude: result.userLatitude,
        userLongitude: result.userLongitude,
        fetchedAt: result.fetchedAt,
        isFromCache: result.isFromCache,
        isStaleCache: result.isStaleCache,
        cacheNotice: result.cacheNotice,
        sourceProvider: result.sourceProvider,
        requestDurationMs:
            result.requestDurationMs ?? stopwatch.elapsedMilliseconds,
        httpStatusCode: result.httpStatusCode ?? 200,
        httpStatusLabel: result.httpStatusLabel ?? '200 OK (OSM)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    // Both providers available: run OpenStreetMap and Mapbox concurrently in parallel
    // to minimize latency and provide optimal resilient coverage.
    NearbyPharmacyFetchResult? osmResult;
    Object? osmError;
    NearbyPharmacyFetchResult? mapboxResult;

    await Future.wait([
      _overpassService
          .fetchNearbyPharmacies(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          )
          .then((res) {
            osmResult = res;
          })
          .catchError((e) {
            osmError = e;
          }),
      _mapboxService
          .fetchNearbyPharmacies(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
          )
          .then((res) {
            mapboxResult = res;
          })
          .catchError((_) {
            // Ignore Mapbox errors if OSM is available
          }),
    ]);
    stopwatch.stop();

    final osmPharmacies =
        osmResult?.pharmacies.where((p) => !p.isDemo).toList() ?? const [];
    final mapboxPharmacies =
        mapboxResult?.pharmacies.where((p) => !p.isDemo).toList() ?? const [];

    if (osmPharmacies.isNotEmpty && mapboxPharmacies.isNotEmpty) {
      final merged = mergeAndDeduplicatePharmacies(
        osmPharmacies,
        mapboxPharmacies,
      );
      return NearbyPharmacyFetchResult(
        pharmacies: merged,
        radiusMeters: radiusMeters,
        userLatitude: latitude,
        userLongitude: longitude,
        fetchedAt: DateTime.now(),
        isFromCache: osmResult?.isFromCache ?? false,
        isStaleCache: osmResult?.isStaleCache ?? false,
        cacheNotice: osmResult?.cacheNotice,
        sourceProvider: 'mapbox+osm',
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: 200,
        httpStatusLabel: '200 OK (Merged OSM + Mapbox)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    if (osmResult != null && osmPharmacies.isNotEmpty) {
      return NearbyPharmacyFetchResult(
        pharmacies: osmPharmacies,
        radiusMeters: osmResult!.radiusMeters,
        userLatitude: osmResult!.userLatitude,
        userLongitude: osmResult!.userLongitude,
        fetchedAt: osmResult!.fetchedAt,
        isFromCache: osmResult!.isFromCache,
        isStaleCache: osmResult!.isStaleCache,
        cacheNotice: osmResult!.cacheNotice,
        sourceProvider: osmResult!.sourceProvider,
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: osmResult!.httpStatusCode ?? 200,
        httpStatusLabel: osmResult!.httpStatusLabel ?? '200 OK (OSM)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    if (mapboxResult != null && mapboxPharmacies.isNotEmpty) {
      return NearbyPharmacyFetchResult(
        pharmacies: mapboxPharmacies,
        radiusMeters: mapboxResult!.radiusMeters,
        userLatitude: mapboxResult!.userLatitude,
        userLongitude: mapboxResult!.userLongitude,
        fetchedAt: mapboxResult!.fetchedAt,
        isFromCache: false,
        isStaleCache: false,
        sourceProvider: 'mapbox',
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: mapboxResult!.httpStatusCode ?? 200,
        httpStatusLabel: mapboxResult!.httpStatusLabel ?? '200 OK (Mapbox)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    // If both returned zero but OSM succeeded
    if (osmResult != null && osmError == null) {
      return NearbyPharmacyFetchResult(
        pharmacies: const [],
        radiusMeters: radiusMeters,
        userLatitude: latitude,
        userLongitude: longitude,
        fetchedAt: DateTime.now(),
        sourceProvider: osmResult!.sourceProvider,
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: osmResult!.httpStatusCode ?? 200,
        httpStatusLabel: osmResult!.httpStatusLabel ?? '200 OK (0 found)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    // If both returned zero and Mapbox succeeded without error
    if (mapboxResult != null && osmError == null) {
      return NearbyPharmacyFetchResult(
        pharmacies: const [],
        radiusMeters: radiusMeters,
        userLatitude: latitude,
        userLongitude: longitude,
        fetchedAt: DateTime.now(),
        sourceProvider: 'mapbox',
        requestDurationMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: 200,
        httpStatusLabel: '200 OK (0 found)',
        geminiStatusCode: geminiDiagnostic?.statusCode,
        geminiErrorMessage: geminiDiagnostic?.errorMessage,
        geminiCandidateCount: geminiDiagnostic?.candidateCount,
        geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
        geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
        geminiFallbackReason: geminiDiagnostic?.fallbackReason,
        geminiModelAttempted: geminiDiagnostic?.modelAttempted,
        isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
      );
    }

    if (osmError != null) {
      throw osmError!;
    }

    return NearbyPharmacyFetchResult(
      pharmacies: const [],
      radiusMeters: radiusMeters,
      userLatitude: latitude,
      userLongitude: longitude,
      fetchedAt: DateTime.now(),
      sourceProvider: 'osm',
      requestDurationMs: stopwatch.elapsedMilliseconds,
      httpStatusCode: 200,
      httpStatusLabel: '200 OK (0 found)',
      geminiStatusCode: geminiDiagnostic?.statusCode,
      geminiErrorMessage: geminiDiagnostic?.errorMessage,
      geminiCandidateCount: geminiDiagnostic?.candidateCount,
      geminiHasGroundingMetadata: geminiDiagnostic?.hasGroundingMetadata,
      geminiGroundedPlaceCount: geminiDiagnostic?.groundedPlaceCount,
      geminiFallbackReason: geminiDiagnostic?.fallbackReason,
      geminiModelAttempted: geminiDiagnostic?.modelAttempted,
      isQuotaExhausted: geminiDiagnostic?.isQuotaExhausted ?? false,
    );
  }

  /// Explicitly isolated DEMO sample records (only used if the user explicitly toggles
  /// an isolated DEMO preview; never returned in real search results).
  static const List<PharmacyModel> _demoDirectory = [
    PharmacyModel(
      id: 'demo_isb_01',
      name: '[DEMO] D-Watson Chemist (Sample)',
      chainName: 'D-Watson',
      licenseNumber: '',
      city: 'Islamabad',
      area: 'Blue Area (F-7)',
      fullAddress: 'Jinnah Avenue, Blue Area, F-7, Islamabad',
      phone: '051-2824310',
      operatingHours: '09:00-23:00',
      is24Hours: false,
      isDrapLicensed: false,
      latitude: 33.7198,
      longitude: 73.0573,
      approximateDistanceKm: 1.2,
      isDemo: true,
    ),
    PharmacyModel(
      id: 'demo_lhr_01',
      name: '[DEMO] Servaid Pharmacy (Sample)',
      chainName: 'Servaid',
      licenseNumber: '',
      city: 'Lahore',
      area: 'Gulberg III',
      fullAddress: 'Main Boulevard, Gulberg III, Lahore',
      phone: '042-111-737-824',
      operatingHours: '24/7',
      is24Hours: true,
      isDrapLicensed: false,
      latitude: 31.5126,
      longitude: 74.3441,
      approximateDistanceKm: 5.6,
      isDemo: true,
    ),
  ];

  List<PharmacyModel> getDemoPharmacies() => List.unmodifiable(_demoDirectory);
}
