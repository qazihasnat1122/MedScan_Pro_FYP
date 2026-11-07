import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_model.dart';
import '../repositories/pharmacy_repository.dart';
import '../services/gemini_maps_pharmacy_service.dart';
import '../services/location_service.dart';
import '../services/mapbox_pharmacy_service.dart';
import '../services/overpass_pharmacy_service.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return const DeviceLocationService();
});

final geminiMapsPharmacyServiceProvider =
    Provider<GeminiMapsPharmacyService>((ref) {
      return GeminiMapsPharmacyService();
    });

final overpassPharmacyServiceProvider = Provider<OverpassPharmacyService>((
  ref,
) {
  return OverpassPharmacyService();
});

final mapboxPharmacyServiceProvider = Provider<MapboxPharmacyService>((ref) {
  return MapboxPharmacyService();
});

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) {
  final geminiMaps = ref.watch(geminiMapsPharmacyServiceProvider);
  final overpass = ref.watch(overpassPharmacyServiceProvider);
  final mapbox = ref.watch(mapboxPharmacyServiceProvider);
  return PharmacyRepository(
    geminiMapsService: geminiMaps,
    overpassService: overpass,
    mapboxService: mapbox,
  );
});

enum NearbyPharmaciesViewStatus {
  initial,
  loadingLocation,
  loadingPharmacies,
  loaded,
  empty,
  locationServiceDisabled,
  locationPermissionDenied,
  locationPermissionPermanentlyDenied,
  locationTimeout,
  networkOrApiError,
}

class NearbyPharmaciesState {
  final NearbyPharmaciesViewStatus status;
  final List<PharmacyModel> pharmacies;
  final String searchQuery;
  final int radiusMeters;
  final DeviceCoordinates? userCoordinates;
  final String errorMessage;
  final OverpassErrorType errorType;
  final bool isFromCache;
  final bool isStaleCache;
  final String? cacheNotice;
  final DateTime? lastUpdated;
  final String activeDataSource;
  final int? requestDurationMs;
  final String? httpStatus;
  final String? resolvedProviderName;
  final int? geminiStatusCode;
  final String? geminiErrorMessage;
  final int? geminiCandidateCount;
  final bool? geminiHasGroundingMetadata;
  final int? geminiGroundedPlaceCount;
  final String? geminiFallbackReason;
  final String? geminiModelAttempted;
  final bool isQuotaExhausted;

  const NearbyPharmaciesState({
    this.status = NearbyPharmaciesViewStatus.initial,
    this.pharmacies = const [],
    this.searchQuery = '',
    this.radiusMeters = OverpassPharmacyService.defaultRadiusMeters,
    this.userCoordinates,
    this.errorMessage = '',
    this.errorType = OverpassErrorType.none,
    this.isFromCache = false,
    this.isStaleCache = false,
    this.cacheNotice,
    this.lastUpdated,
    this.activeDataSource = 'osm',
    this.requestDurationMs,
    this.httpStatus,
    this.resolvedProviderName,
    this.geminiStatusCode,
    this.geminiErrorMessage,
    this.geminiCandidateCount,
    this.geminiHasGroundingMetadata,
    this.geminiGroundedPlaceCount,
    this.geminiFallbackReason,
    this.geminiModelAttempted,
    this.isQuotaExhausted = false,
  });

  bool get isLoading =>
      status == NearbyPharmaciesViewStatus.loadingLocation ||
      status == NearbyPharmaciesViewStatus.loadingPharmacies;

  /// Returns the real pharmacies filtered by the optional local search query,
  /// preserving nearest-first distance sorting and excluding any demo records.
  List<PharmacyModel> get filteredPharmacies {
    final realOnly = pharmacies.where((p) => !p.isDemo).toList();
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return realOnly;
    return realOnly.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.fullAddress.toLowerCase().contains(q) ||
          p.area.toLowerCase().contains(q) ||
          p.city.toLowerCase().contains(q) ||
          p.chainName.toLowerCase().contains(q);
    }).toList();
  }

  NearbyPharmaciesState copyWith({
    NearbyPharmaciesViewStatus? status,
    List<PharmacyModel>? pharmacies,
    String? searchQuery,
    int? radiusMeters,
    DeviceCoordinates? userCoordinates,
    String? errorMessage,
    OverpassErrorType? errorType,
    bool? isFromCache,
    bool? isStaleCache,
    String? cacheNotice,
    DateTime? lastUpdated,
    String? activeDataSource,
    int? requestDurationMs,
    String? httpStatus,
    String? resolvedProviderName,
    int? geminiStatusCode,
    String? geminiErrorMessage,
    int? geminiCandidateCount,
    bool? geminiHasGroundingMetadata,
    int? geminiGroundedPlaceCount,
    String? geminiFallbackReason,
    String? geminiModelAttempted,
    bool? isQuotaExhausted,
  }) {
    return NearbyPharmaciesState(
      status: status ?? this.status,
      pharmacies: pharmacies ?? this.pharmacies,
      searchQuery: searchQuery ?? this.searchQuery,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      userCoordinates: userCoordinates ?? this.userCoordinates,
      errorMessage: errorMessage ?? this.errorMessage,
      errorType: errorType ?? this.errorType,
      isFromCache: isFromCache ?? this.isFromCache,
      isStaleCache: isStaleCache ?? this.isStaleCache,
      cacheNotice: cacheNotice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      activeDataSource: activeDataSource ?? this.activeDataSource,
      requestDurationMs: requestDurationMs ?? this.requestDurationMs,
      httpStatus: httpStatus ?? this.httpStatus,
      resolvedProviderName: resolvedProviderName ?? this.resolvedProviderName,
      geminiStatusCode: geminiStatusCode ?? this.geminiStatusCode,
      geminiErrorMessage: geminiErrorMessage ?? this.geminiErrorMessage,
      geminiCandidateCount: geminiCandidateCount ?? this.geminiCandidateCount,
      geminiHasGroundingMetadata:
          geminiHasGroundingMetadata ?? this.geminiHasGroundingMetadata,
      geminiGroundedPlaceCount:
          geminiGroundedPlaceCount ?? this.geminiGroundedPlaceCount,
      geminiFallbackReason: geminiFallbackReason ?? this.geminiFallbackReason,
      geminiModelAttempted: geminiModelAttempted ?? this.geminiModelAttempted,
      isQuotaExhausted: isQuotaExhausted ?? this.isQuotaExhausted,
    );
  }
}

class NearbyPharmaciesNotifier extends Notifier<NearbyPharmaciesState> {
  int _activeRequestId = 0;
  bool _isRequestInFlight = false;
  int? _inFlightRadiusMeters;

  @override
  NearbyPharmaciesState build() {
    return const NearbyPharmaciesState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, cacheNotice: state.cacheNotice);
  }

  /// Acquires foreground GPS coordinates and queries OpenStreetMap Overpass API
  /// for real pharmacies within [newRadiusMeters] (defaults to current `radiusMeters`).
  ///
  /// - Prevents duplicate identical concurrent requests.
  /// - Allows explicit Retry (`forceRefresh: true`) or radius changes (`newRadiusMeters`)
  ///   to immediately start a fresh request.
  /// - Uses a monotonic `_activeRequestId` token so stale responses from superseded
  ///   requests can never overwrite newer searches.
  Future<void> discoverNearbyPharmacies({
    bool forceRefresh = false,
    int? newRadiusMeters,
    bool forceLocationRefresh = false,
  }) async {
    final targetRadius = newRadiusMeters ?? state.radiusMeters;
    final isRadiusChange =
        newRadiusMeters != null && newRadiusMeters != state.radiusMeters;

    if (_isRequestInFlight &&
        !forceRefresh &&
        !isRadiusChange &&
        _inFlightRadiusMeters == targetRadius) {
      return;
    }

    final requestId = ++_activeRequestId;
    _isRequestInFlight = true;
    _inFlightRadiusMeters = targetRadius;

    try {
      DeviceCoordinates? coords = state.userCoordinates;

      // 1. Obtain real device coordinates if not already available or if explicitly requested
      if (coords == null || !coords.isValid || forceLocationRefresh) {
        state = state.copyWith(
          status: NearbyPharmaciesViewStatus.loadingLocation,
          radiusMeters: targetRadius,
          errorMessage: '',
          errorType: OverpassErrorType.none,
        );

        final locationService = ref.read(deviceLocationServiceProvider);
        final locResult = await locationService.getCurrentDeviceLocation();

        if (requestId != _activeRequestId) return;

        if (!locResult.isSuccess || locResult.coordinates == null) {
          final mappedStatus = switch (locResult.status) {
            DeviceLocationStatus.serviceDisabled =>
              NearbyPharmaciesViewStatus.locationServiceDisabled,
            DeviceLocationStatus.permissionDenied =>
              NearbyPharmaciesViewStatus.locationPermissionDenied,
            DeviceLocationStatus.permissionPermanentlyDenied =>
              NearbyPharmaciesViewStatus.locationPermissionPermanentlyDenied,
            DeviceLocationStatus.timeout =>
              NearbyPharmaciesViewStatus.locationTimeout,
            _ => NearbyPharmaciesViewStatus.networkOrApiError,
          };

          state = state.copyWith(
            status: mappedStatus,
            pharmacies: const [],
            radiusMeters: targetRadius,
            errorMessage: locResult.message,
            errorType: OverpassErrorType.none,
          );
          return;
        }
        coords = locResult.coordinates!;
      }

      // 2. Query Overpass API around real device coordinates
      state = state.copyWith(
        status: NearbyPharmaciesViewStatus.loadingPharmacies,
        userCoordinates: coords,
        radiusMeters: targetRadius,
        errorMessage: '',
        errorType: OverpassErrorType.none,
      );

      final repo = ref.read(pharmacyRepositoryProvider);
      final fetchResult = await repo.fetchNearbyRealPharmacies(
        latitude: coords.latitude,
        longitude: coords.longitude,
        radiusMeters: targetRadius,
        forceRefresh: forceRefresh,
      );

      if (requestId != _activeRequestId) return;

      final friendlyProvider = _friendlyProviderName(
        fetchResult.sourceProvider,
      );
      final httpLabel =
          fetchResult.httpStatusLabel ??
          (fetchResult.httpStatusCode != null
              ? 'HTTP ${fetchResult.httpStatusCode}'
              : '200 OK');

      if (fetchResult.pharmacies.isEmpty) {
        state = state.copyWith(
          status: NearbyPharmaciesViewStatus.empty,
          pharmacies: const [],
          userCoordinates: coords,
          radiusMeters: targetRadius,
          isFromCache: fetchResult.isFromCache,
          isStaleCache: fetchResult.isStaleCache,
          cacheNotice: fetchResult.cacheNotice,
          lastUpdated: fetchResult.fetchedAt,
          errorMessage: '',
          errorType: OverpassErrorType.none,
          activeDataSource: fetchResult.sourceProvider,
          requestDurationMs: fetchResult.requestDurationMs,
          httpStatus: httpLabel,
          resolvedProviderName: friendlyProvider,
          geminiStatusCode: fetchResult.geminiStatusCode,
          geminiErrorMessage: fetchResult.geminiErrorMessage,
          geminiCandidateCount: fetchResult.geminiCandidateCount,
          geminiHasGroundingMetadata: fetchResult.geminiHasGroundingMetadata,
          geminiGroundedPlaceCount: fetchResult.geminiGroundedPlaceCount,
          geminiFallbackReason: fetchResult.geminiFallbackReason,
          geminiModelAttempted: fetchResult.geminiModelAttempted,
          isQuotaExhausted: fetchResult.isQuotaExhausted,
        );
      } else {
        state = state.copyWith(
          status: NearbyPharmaciesViewStatus.loaded,
          pharmacies: fetchResult.pharmacies,
          userCoordinates: coords,
          radiusMeters: targetRadius,
          isFromCache: fetchResult.isFromCache,
          isStaleCache: fetchResult.isStaleCache,
          cacheNotice: fetchResult.cacheNotice,
          lastUpdated: fetchResult.fetchedAt,
          errorMessage: '',
          errorType: OverpassErrorType.none,
          activeDataSource: fetchResult.sourceProvider,
          requestDurationMs: fetchResult.requestDurationMs,
          httpStatus: httpLabel,
          resolvedProviderName: friendlyProvider,
          geminiStatusCode: fetchResult.geminiStatusCode,
          geminiErrorMessage: fetchResult.geminiErrorMessage,
          geminiCandidateCount: fetchResult.geminiCandidateCount,
          geminiHasGroundingMetadata: fetchResult.geminiHasGroundingMetadata,
          geminiGroundedPlaceCount: fetchResult.geminiGroundedPlaceCount,
          geminiFallbackReason: fetchResult.geminiFallbackReason,
          geminiModelAttempted: fetchResult.geminiModelAttempted,
          isQuotaExhausted: fetchResult.isQuotaExhausted,
        );
      }
    } on OverpassPharmacyException catch (e) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        status: NearbyPharmaciesViewStatus.networkOrApiError,
        pharmacies: const [],
        radiusMeters: targetRadius,
        errorMessage: e.message,
        errorType: e.type,
        httpStatus: e.statusCode != null
            ? 'HTTP ${e.statusCode}'
            : 'Timeout / Error',
        resolvedProviderName: 'OSM Overpass',
      );
    } catch (e) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        status: NearbyPharmaciesViewStatus.networkOrApiError,
        pharmacies: const [],
        radiusMeters: targetRadius,
        errorMessage: 'Failed to load nearby pharmacies: $e',
        errorType: OverpassErrorType.networkError,
        httpStatus: 'Transport Error',
      );
    } finally {
      if (requestId == _activeRequestId) {
        _isRequestInFlight = false;
        _inFlightRadiusMeters = null;
      }
    }
  }

  static String _friendlyProviderName(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini_google_maps':
        return 'Google Maps Grounded';
      case 'mapbox+osm':
        return 'OSM + Mapbox Merged';
      case 'mapbox':
        return 'Mapbox Search Box';
      case 'osm_nominatim':
        return 'OSM Nominatim Fallback';
      case 'osm_overpass':
      case 'osm':
        return 'OSM Overpass';
      case 'osm_cache':
        return 'OSM Local Cache';
      default:
        return provider.toUpperCase();
    }
  }
}

final nearbyPharmaciesProvider =
    NotifierProvider<NearbyPharmaciesNotifier, NearbyPharmaciesState>(() {
      return NearbyPharmaciesNotifier();
    });
