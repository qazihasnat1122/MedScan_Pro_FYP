import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medscan_mobile/features/pharmacies/nearby_pharmacies_screen.dart';
import 'package:medscan_mobile/providers/pharmacy_providers.dart';
import 'package:medscan_mobile/repositories/pharmacy_repository.dart';
import 'package:medscan_mobile/services/location_service.dart';
import 'package:medscan_mobile/services/mapbox_pharmacy_service.dart';
import 'package:medscan_mobile/services/overpass_pharmacy_service.dart';

class _FakeLocationAdapter implements LocationProviderAdapter {
  bool serviceEnabled;
  LocationPermission initialPermission;
  LocationPermission requestedPermission;
  bool shouldTimeout;

  _FakeLocationAdapter({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.shouldTimeout = false,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    if (shouldTimeout) {
      throw TimeoutException('GPS timeout');
    }
    return Position(
      latitude: 33.6844,
      longitude: 73.0479,
      timestamp: DateTime(2026, 10, 23, 12, 0),
      accuracy: 10.0,
      altitude: 500.0,
      altitudeAccuracy: 5.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  const double userLat = 33.6844;
  const double userLon = 73.0479;

  group('Phase 2 — DeviceLocationService Tests', () {
    test(
      'Returns granted status and actual coordinates when permission is allowed',
      () async {
        final adapter = _FakeLocationAdapter(
          serviceEnabled: true,
          initialPermission: LocationPermission.whileInUse,
        );
        final service = DeviceLocationService(adapter: adapter);

        final result = await service.getCurrentDeviceLocation();
        expect(result.isSuccess, isTrue);
        expect(result.status, equals(DeviceLocationStatus.granted));
        expect(result.coordinates?.latitude, closeTo(userLat, 0.0001));
        expect(result.coordinates?.longitude, closeTo(userLon, 0.0001));
      },
    );

    test('Handles location services disabled', () async {
      final adapter = _FakeLocationAdapter(serviceEnabled: false);
      final service = DeviceLocationService(adapter: adapter);

      final result = await service.getCurrentDeviceLocation();
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(DeviceLocationStatus.serviceDisabled));
    });

    test('Handles location permission denied and permanently denied', () async {
      final deniedAdapter = _FakeLocationAdapter(
        initialPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );
      final deniedService = DeviceLocationService(adapter: deniedAdapter);
      final deniedResult = await deniedService.getCurrentDeviceLocation();
      expect(
        deniedResult.status,
        equals(DeviceLocationStatus.permissionDenied),
      );

      final foreverAdapter = _FakeLocationAdapter(
        initialPermission: LocationPermission.deniedForever,
      );
      final foreverService = DeviceLocationService(adapter: foreverAdapter);
      final foreverResult = await foreverService.getCurrentDeviceLocation();
      expect(
        foreverResult.status,
        equals(DeviceLocationStatus.permissionPermanentlyDenied),
      );
    });

    test('Handles GPS timeout gracefully', () async {
      final timeoutAdapter = _FakeLocationAdapter(shouldTimeout: true);
      final service = DeviceLocationService(adapter: timeoutAdapter);

      final result = await service.getCurrentDeviceLocation();
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(DeviceLocationStatus.timeout));
    });
  });

  group('Phase 3 & 4 — Overpass API Parsing, Deduplication, Distance & Errors', () {
    test(
      'buildOverpassQuery generates unified nwr["amenity"="pharmacy"](around:RADIUS,LAT,LON) query with timeout:25',
      () {
        final query = OverpassPharmacyService.buildOverpassQuery(
          latitude: 33.6844,
          longitude: 73.0479,
          radiusMeters: 5000,
        );
        expect(
          query,
          equals(
            '[out:json][timeout:25];nwr["amenity"="pharmacy"](around:5000,33.684400,73.047900);out center tags;',
          ),
        );
      },
    );

    test(
      'Parses valid Overpass response with node, way/relation center coordinates, missing optional fields, and sorts nearest-first',
      () async {
        final mockPayload = {
          'version': 0.6,
          'elements': [
            // Farther pharmacy (way with center coordinates, ~2.5 km north)
            {
              'type': 'way',
              'id': 2002,
              'center': {'lat': 33.7070, 'lon': 73.0479},
              'tags': {
                'amenity': 'pharmacy',
                'name': 'City Care Pharmacy',
                'addr:street': 'Jinnah Avenue',
                'addr:city': 'Islamabad',
                'phone': '+92 51 2824310',
                'opening_hours': '09:00-23:00',
              },
            },
            // Nearest pharmacy (node with direct coordinates, ~350 m north, missing name & optional fields)
            {
              'type': 'node',
              'id': 1001,
              'lat': 33.6875,
              'lon': 73.0479,
              'tags': {'amenity': 'pharmacy'},
            },
            // Relation with center coordinates (~1.1 km north)
            {
              'type': 'relation',
              'id': 3003,
              'center': {'lat': 33.6944, 'lon': 73.0479},
              'tags': {
                'amenity': 'pharmacy',
                'name:en': 'Al-Shifa Medical Store',
                'contact:phone': '051-5487821',
              },
            },
          ],
        };

        final client = MockClient((request) async {
          expect(request.method, equals('POST'));
          final decodedBody = Uri.decodeQueryComponent(request.body);
          expect(decodedBody, contains('nwr["amenity"="pharmacy"]'));
          expect(decodedBody, contains('5000'));
          return http.Response(jsonEncode(mockPayload), 200);
        });

        final service = OverpassPharmacyService(httpClient: client);
        final res = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
        );

        expect(res.pharmacies.length, equals(3));

        // 1. Nearest first (node 1001, unnamed)
        final first = res.pharmacies[0];
        expect(first.osmType, equals('node'));
        expect(first.osmId, equals(1001));
        expect(first.name, equals('Unnamed pharmacy'));
        expect(first.phone, isEmpty);
        expect(first.hasValidPhone, isFalse);
        expect(first.fullAddress, isEmpty);
        expect(first.operatingHours, isEmpty);
        expect(first.isDrapLicensed, isFalse);
        expect(first.licenseNumber, isEmpty);
        expect(first.distanceMeters, greaterThan(300));
        expect(first.distanceMeters, lessThan(400));
        expect(
          first.formattedStraightLineDistance,
          contains('m (straight-line)'),
        );

        // 2. Second nearest (relation 3003)
        final second = res.pharmacies[1];
        expect(second.osmType, equals('relation'));
        expect(second.name, equals('Al-Shifa Medical Store'));
        expect(second.hasValidPhone, isTrue);

        // 3. Farthest (way 2002)
        final third = res.pharmacies[2];
        expect(third.osmType, equals('way'));
        expect(third.name, equals('City Care Pharmacy'));
        expect(third.fullAddress, contains('Jinnah Avenue'));
        expect(third.operatingHours, equals('09:00-23:00'));
        expect(
          third.formattedStraightLineDistance,
          contains('km (straight-line)'),
        );
        expect(first.distanceMeters, lessThan(second.distanceMeters));
        expect(second.distanceMeters, lessThan(third.distanceMeters));
      },
    );

    test(
      'Handles empty Overpass result without inventing pharmacies',
      () async {
        final client = MockClient((_) async {
          return http.Response(jsonEncode({'elements': []}), 200);
        });
        final service = OverpassPharmacyService(httpClient: client);
        final res = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
        );
        expect(res.pharmacies, isEmpty);
      },
    );

    test(
      'Skips records with missing or invalid coordinates and deduplicates identical OSM or co-located entries',
      () {
        final rawJson = jsonEncode({
          'elements': [
            // Missing coordinates
            {
              'type': 'way',
              'id': 501,
              'tags': {'name': 'No Coords Pharmacy'},
            },
            // Out-of-range coordinates
            {
              'type': 'node',
              'id': 502,
              'lat': 195.0,
              'lon': 73.0,
              'tags': {'name': 'Invalid Lat Pharmacy'},
            },
            // Zero coordinates (0, 0)
            {
              'type': 'node',
              'id': 503,
              'lat': 0.0,
              'lon': 0.0,
              'tags': {'name': 'Null Island Pharmacy'},
            },
            // Valid node
            {
              'type': 'node',
              'id': 600,
              'lat': 33.6850,
              'lon': 73.0480,
              'tags': {'name': 'MedCare Pharmacy'},
            },
            // Exact duplicate OSM ID
            {
              'type': 'node',
              'id': 600,
              'lat': 33.6850,
              'lon': 73.0480,
              'tags': {'name': 'MedCare Pharmacy'},
            },
            // Co-located way representing same building within 5 metres
            {
              'type': 'way',
              'id': 601,
              'center': {'lat': 33.68502, 'lon': 73.04802},
              'tags': {'name': 'MedCare Pharmacy'},
            },
          ],
        });

        final parsed = OverpassPharmacyService.parseOverpassResponseBody(
          rawJson,
          userLatitude: userLat,
          userLongitude: userLon,
        );

        expect(parsed.length, equals(1));
        expect(parsed.first.name, equals('MedCare Pharmacy'));
      },
    );

    test(
      'Handles HTTP error (503), rate-limit (429), timeout, offline SocketException, malformed JSON, and Overpass HTTP 200 timeout remark',
      () async {
        // 1. Rate-limit 429 (fails fast without hammering fallback mirrors)
        int rateLimitCalls = 0;
        final rateLimitService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient((_) async {
            rateLimitCalls++;
            return http.Response('Too Many Requests', 429);
          }),
        );
        await expectLater(
          () => rateLimitService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.rateLimited,
            ),
          ),
        );
        expect(rateLimitCalls, equals(1));

        // 2. Server error 503 across configured endpoints
        final serverErrService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient((_) async => http.Response('Busy', 503)),
        );
        await expectLater(
          () => serverErrService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.serverUnavailable,
            ),
          ),
        );

        // 3. Malformed JSON
        final malformedService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient(
            (_) async => http.Response('<html>Error</html>', 200),
          ),
        );
        await expectLater(
          () => malformedService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.malformedResponse,
            ),
          ),
        );

        // 4. Timeout across configured endpoints
        final timeoutService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient(
            (_) async => throw TimeoutException('Timed out'),
          ),
        );
        await expectLater(
          () => timeoutService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.timeout,
            ),
          ),
        );

        // 5. Offline SocketException
        final offlineService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient(
            (_) async =>
                throw const SocketException('Failed host lookup: overpass'),
          ),
        );
        await expectLater(
          () => offlineService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.offline,
            ),
          ),
        );

        // 6. Overpass HTTP 200 with runtime timeout remark inside JSON
        final remarkTimeoutService = OverpassPharmacyService(
          retryBackoff: Duration.zero,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'elements': [],
                'remark':
                    'runtime error: Query timed out in "around" at line 1 after 25 seconds.',
              }),
              200,
            ),
          ),
        );
        await expectLater(
          () => remarkTimeoutService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<OverpassPharmacyException>().having(
              (e) => e.type,
              'type',
              OverpassErrorType.timeout,
            ),
          ),
        );
      },
    );

    test(
      'Bounded sequential retry recovers when primary Overpass endpoint times out and secondary endpoint succeeds',
      () async {
        final calledUrls = <String>[];
        final client = MockClient((request) async {
          calledUrls.add(request.url.toString());
          if (calledUrls.length == 1) {
            throw TimeoutException('Primary Overpass endpoint timed out');
          }
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 777,
                  'lat': 33.6855,
                  'lon': 73.0485,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'Fallback Mirror Pharmacy',
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = OverpassPharmacyService(
          httpClient: client,
          retryBackoff: Duration.zero,
        );

        final res = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
        );

        expect(calledUrls.length, equals(2));
        expect(calledUrls[0], equals(OverpassPharmacyService.defaultEndpoint));
        expect(calledUrls[1], equals(OverpassPharmacyService.fallbackEndpoint));
        expect(res.pharmacies.length, equals(1));
        expect(res.pharmacies.first.name, equals('Fallback Mirror Pharmacy'));
      },
    );

    test(
      'Prevents duplicate concurrent requests for identical location/radius and returns clearly labeled cached results on subsequent transient failure',
      () async {
        int networkCalls = 0;
        bool shouldFail = false;
        final completer = Completer<http.Response>();

        final client = MockClient((_) {
          networkCalls++;
          if (shouldFail) {
            return Future.error(TimeoutException('Timed out on refresh'));
          }
          return completer.future;
        });

        final service = OverpassPharmacyService(
          httpClient: client,
          retryBackoff: Duration.zero,
        );

        // Fire two concurrent identical requests
        final future1 = service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
        );
        final future2 = service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
        );

        completer.complete(
          http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 888,
                  'lat': 33.6860,
                  'lon': 73.0490,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'Cached Safety Pharmacy',
                  },
                },
              ],
            }),
            200,
          ),
        );

        final results = await Future.wait([future1, future2]);
        // Only 1 network call was made for the two concurrent identical requests
        expect(networkCalls, equals(1));
        expect(
          results[0].pharmacies.first.name,
          equals('Cached Safety Pharmacy'),
        );
        expect(
          results[1].pharmacies.first.name,
          equals('Cached Safety Pharmacy'),
        );

        // Now forceRefresh when network fails: should return cached data labeled isStaleCache: true
        shouldFail = true;
        final fallbackRes = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
          forceRefresh: true,
        );
        expect(fallbackRes.isFromCache, isTrue);
        expect(fallbackRes.isStaleCache, isTrue);
        expect(fallbackRes.cacheNotice, contains('Showing cached results'));
        expect(
          fallbackRes.pharmacies.first.name,
          equals('Cached Safety Pharmacy'),
        );
      },
    );

    test(
      'Radius changes (5 km -> 10 km -> 25 km) supersede in-flight searches so stale responses cannot overwrite newer searches',
      () async {
        final completer25km = Completer<http.Response>();
        final completer5km = Completer<http.Response>();

        final client = MockClient((request) {
          final body = Uri.decodeQueryComponent(request.body);
          if (body.contains('around:25000')) {
            return completer25km.future;
          }
          return completer5km.future;
        });

        final container = ProviderContainer(
          overrides: [
            deviceLocationServiceProvider.overrideWithValue(
              DeviceLocationService(
                adapter: _FakeLocationAdapter(
                  serviceEnabled: true,
                  initialPermission: LocationPermission.whileInUse,
                ),
              ),
            ),
            overpassPharmacyServiceProvider.overrideWithValue(
              OverpassPharmacyService(
                httpClient: client,
                endpoints: const [OverpassPharmacyService.defaultEndpoint],
                retryBackoff: Duration.zero,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(nearbyPharmaciesProvider.notifier);

        // 1. Start a slow 25 km search
        final slow25kmFuture = notifier.discoverNearbyPharmacies(
          newRadiusMeters: 25000,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(nearbyPharmaciesProvider).radiusMeters,
          equals(25000),
        );

        // 2. User immediately switches to 5 km before 25 km finishes
        final fast5kmFuture = notifier.discoverNearbyPharmacies(
          newRadiusMeters: 5000,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(nearbyPharmaciesProvider).radiusMeters,
          equals(5000),
        );

        // 3. Complete the newer 5 km request first
        completer5km.complete(
          http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 505,
                  'lat': 33.6850,
                  'lon': 73.0480,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'Five Km Fresh Pharmacy',
                  },
                },
              ],
            }),
            200,
          ),
        );
        await fast5kmFuture;

        expect(
          container.read(nearbyPharmaciesProvider).status,
          equals(NearbyPharmaciesViewStatus.loaded),
        );
        expect(
          container.read(nearbyPharmaciesProvider).radiusMeters,
          equals(5000),
        );
        expect(
          container.read(nearbyPharmaciesProvider).pharmacies.single.name,
          equals('Five Km Fresh Pharmacy'),
        );

        // 4. Now the stale 25 km response arrives late — it MUST NOT overwrite the 5 km state
        completer25km.complete(
          http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 2525,
                  'lat': 33.7500,
                  'lon': 73.1000,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'Stale TwentyFive Km Pharmacy',
                  },
                },
              ],
            }),
            200,
          ),
        );
        await slow25kmFuture;

        final finalState = container.read(nearbyPharmaciesProvider);
        expect(finalState.radiusMeters, equals(5000));
        expect(
          finalState.pharmacies.single.name,
          equals('Five Km Fresh Pharmacy'),
        );
      },
    );

    test(
      'No sample/demo entries ever leak into real repository results',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 9001,
                  'lat': 33.6860,
                  'lon': 73.0490,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'Real Street Pharmacy',
                  },
                },
              ],
            }),
            200,
          );
        });

        final repo = PharmacyRepository(
          overpassService: OverpassPharmacyService(httpClient: client),
        );
        final realResult = await repo.fetchNearbyRealPharmacies(
          latitude: userLat,
          longitude: userLon,
        );

        expect(realResult.pharmacies.length, equals(1));
        expect(realResult.pharmacies.every((p) => !p.isDemo), isTrue);
        expect(
          realResult.pharmacies.first.name,
          equals('Real Street Pharmacy'),
        );

        // Demo list is completely separate and explicitly flagged isDemo: true
        final demos = repo.getDemoPharmacies();
        expect(demos.every((p) => p.isDemo), isTrue);
      },
    );
  });

  group('Mapbox Search Box Evaluation, Token Security & Provider Comparison', () {
    test(
      'Rejects empty token and explicitly blocks secret tokens (sk.*) in client code',
      () async {
        final unconfiguredService = MapboxPharmacyService(accessToken: '');
        await expectLater(
          () => unconfiguredService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<MapboxPharmacyException>().having(
              (e) => e.type,
              'type',
              MapboxErrorType.notConfigured,
            ),
          ),
        );

        final secretTokenService = MapboxPharmacyService(
          accessToken: 'sk.test_placeholder_do_not_use_in_client',
        );
        await expectLater(
          () => secretTokenService.fetchNearbyPharmacies(
            latitude: userLat,
            longitude: userLon,
          ),
          throwsA(
            isA<MapboxPharmacyException>().having(
              (e) => e.type,
              'type',
              MapboxErrorType.insecureSecretToken,
            ),
          ),
        );
      },
    );

    test(
      'Queries Mapbox Search Box /category/pharmacy with proximity=lon,lat and bbox, parses GeoJSON features, filters to radius, and sorts nearest-first',
      () async {
        final mapboxPayload = {
          'type': 'FeatureCollection',
          'features': [
            // Farther pharmacy (~1.2 km north)
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [73.0479, 33.6950], // [lon, lat]
              },
              'properties': {
                'mapbox_id': 'poi.mbx.202',
                'name': 'Shaheen Chemist & Druggist',
                'full_address': 'F-6 Markaz, Islamabad',
                'context': {
                  'locality': {'name': 'F-6'},
                  'place': {'name': 'Islamabad'},
                },
                'metadata': {
                  'phone': '+92 51 2829999',
                  'open_hours': '08:00-23:00',
                },
              },
            },
            // Nearest pharmacy (~350 m north)
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [73.0479, 33.6875], // [lon, lat]
              },
              'properties': {
                'mapbox_id': 'poi.mbx.101',
                'name': 'D-Watson Blue Area',
                'address': 'Jinnah Avenue',
              },
            },
            // Out-of-radius pharmacy (~12 km away, should be filtered out for 5000m radius)
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [73.0479, 33.7950],
              },
              'properties': {
                'mapbox_id': 'poi.mbx.999',
                'name': 'Far Away Pharmacy',
              },
            },
          ],
        };

        final client = MockClient((request) async {
          expect(request.method, equals('GET'));
          expect(
            request.url.path,
            contains('/search/searchbox/v1/category/pharmacy'),
          );
          expect(
            request.url.queryParameters['proximity'],
            equals('73.047900,33.684400'),
          );
          expect(request.url.queryParameters['bbox'], isNotNull);
          expect(request.url.queryParameters['limit'], equals('25'));
          return http.Response(jsonEncode(mapboxPayload), 200);
        });

        final service = MapboxPharmacyService(
          httpClient: client,
          accessToken: 'pk.mock_public_token_for_unit_test',
        );

        final res = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
        );

        expect(res.pharmacies.length, equals(2));
        expect(res.pharmacies[0].name, equals('D-Watson Blue Area'));
        expect(res.pharmacies[0].dataSource, equals('mapbox'));
        expect(res.pharmacies[0].isDrapLicensed, isFalse);
        expect(res.pharmacies[1].name, equals('Shaheen Chemist & Druggist'));
        expect(res.pharmacies[1].hasValidPhone, isTrue);
        expect(
          res.pharmacies[0].distanceMeters,
          lessThan(res.pharmacies[1].distanceMeters),
        );
      },
    );

    test(
      'Compares Mapbox vs Overpass for the same GPS location and deduplicates overlapping pharmacies without losing contact fields',
      () async {
        final mapboxClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [73.0480, 33.6850],
                  },
                  'properties': {
                    'mapbox_id': 'mbx.1',
                    'name': 'MedCare Pharmacy',
                    'full_address': 'Blue Area, Islamabad',
                    // Phone missing in Mapbox
                  },
                },
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [73.0500, 33.6890],
                  },
                  'properties': {
                    'mapbox_id': 'mbx.2',
                    'name': 'Mapbox Exclusive Chemist',
                    'metadata': {'phone': '051-1112223'},
                  },
                },
              ],
            }),
            200,
          );
        });

        final overpassClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 600,
                  'lat': 33.68502,
                  'lon': 73.04802,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'MedCare Pharmacy',
                    'phone': '+92 51 2824310', // Phone present in OSM
                  },
                },
                {
                  'type': 'node',
                  'id': 601,
                  'lat': 33.6920,
                  'lon': 73.0520,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'OSM Community Medical Store',
                  },
                },
              ],
            }),
            200,
          );
        });

        final repo = PharmacyRepository(
          mapboxService: MapboxPharmacyService(
            httpClient: mapboxClient,
            accessToken: 'pk.mock_public_token_for_unit_test',
          ),
          overpassService: OverpassPharmacyService(
            httpClient: overpassClient,
            retryBackoff: Duration.zero,
          ),
        );

        final comparison = await repo.compareProviders(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 5000,
        );

        expect(comparison.isMapboxConfigured, isTrue);
        expect(comparison.mapboxCount, equals(2));
        expect(comparison.overpassCount, equals(2));
        expect(comparison.overlappingDuplicateCount, equals(1));
        // 2 + 2 - 1 overlap = 3 unique pharmacies
        expect(comparison.mergedDeduplicatedPharmacies.length, equals(3));

        // Verify that the overlapping "MedCare Pharmacy" was enriched with OSM's phone number and Mapbox's address
        final medCare = comparison.mergedDeduplicatedPharmacies.firstWhere(
          (p) => p.name == 'MedCare Pharmacy',
        );
        expect(medCare.fullAddress, equals('Blue Area, Islamabad'));
        expect(medCare.phone, equals('+92 51 2824310'));
      },
    );
  });

  group('Phase 5 & 7 — NearbyPharmaciesScreen Widget State Tests', () {
    testWidgets(
      'Renders loading state and transitions to populated real pharmacy list with Call button only when phone exists',
      (tester) async {
        final completer = Completer<http.Response>();
        final client = MockClient((_) => completer.future);
        final locationAdapter = _FakeLocationAdapter(
          serviceEnabled: true,
          initialPermission: LocationPermission.whileInUse,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(
                DeviceLocationService(adapter: locationAdapter),
              ),
              overpassPharmacyServiceProvider.overrideWithValue(
                OverpassPharmacyService(httpClient: client),
              ),
            ],
            child: const MaterialApp(home: NearbyPharmaciesScreen()),
          ),
        );

        // Pump post-frame callback so discovery starts and enters loading state
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the HTTP request with 2 pharmacies: one with phone, one without phone/name
        completer.complete(
          http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 11,
                  'lat': 33.6850,
                  'lon': 73.0480,
                  'tags': {
                    'amenity': 'pharmacy',
                    'name': 'HealthFirst Chemist',
                    'phone': '051-2824310',
                    'addr:street': 'Blue Area',
                  },
                },
                {
                  'type': 'node',
                  'id': 12,
                  'lat': 33.6900,
                  'lon': 73.0500,
                  'tags': {'amenity': 'pharmacy'},
                },
              ],
            }),
            200,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('HealthFirst Chemist'), findsOneWidget);
        expect(find.text('Unnamed pharmacy'), findsOneWidget);
        // Directions appears for both pharmacies (2), Call appears ONLY for the 1 pharmacy with a phone
        expect(find.text('Directions'), findsNWidgets(2));
        expect(find.text('Call'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders empty state with radius expansion buttons when 0 pharmacies found',
      (tester) async {
        final client = MockClient(
          (_) async => http.Response(jsonEncode({'elements': []}), 200),
        );
        final locationAdapter = _FakeLocationAdapter(
          serviceEnabled: true,
          initialPermission: LocationPermission.whileInUse,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(
                DeviceLocationService(adapter: locationAdapter),
              ),
              overpassPharmacyServiceProvider.overrideWithValue(
                OverpassPharmacyService(httpClient: client),
              ),
            ],
            child: const MaterialApp(home: NearbyPharmaciesScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('No Mapped Pharmacies Within 5 km'),
          findsOneWidget,
        );
        expect(find.text('Expand Search to 10 km'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders location permission denied and location services disabled states',
      (tester) async {
        final disabledAdapter = _FakeLocationAdapter(serviceEnabled: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(
                DeviceLocationService(adapter: disabledAdapter),
              ),
            ],
            child: const MaterialApp(home: NearbyPharmaciesScreen()),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Location Services Disabled'), findsOneWidget);
        expect(find.text('Enable Location Services'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders network/API error state with Retry button on Overpass failure',
      (tester) async {
        final client = MockClient(
          (_) async => http.Response('Service Unavailable', 503),
        );
        final locationAdapter = _FakeLocationAdapter(
          serviceEnabled: true,
          initialPermission: LocationPermission.whileInUse,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(
                DeviceLocationService(adapter: locationAdapter),
              ),
              overpassPharmacyServiceProvider.overrideWithValue(
                OverpassPharmacyService(httpClient: client),
              ),
            ],
            child: const MaterialApp(home: NearbyPharmaciesScreen()),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Unable to Load Nearby Pharmacies'), findsOneWidget);
        expect(find.text('Retry Search'), findsOneWidget);
      },
    );

    testWidgets('Renders empty state with "Search in External Maps" button', (
      tester,
    ) async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'version': 0.6, 'elements': []}), 200),
      );
      final locationAdapter = _FakeLocationAdapter(
        serviceEnabled: true,
        initialPermission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceLocationServiceProvider.overrideWithValue(
              DeviceLocationService(adapter: locationAdapter),
            ),
            overpassPharmacyServiceProvider.overrideWithValue(
              OverpassPharmacyService(httpClient: client),
            ),
          ],
          child: const MaterialApp(home: NearbyPharmaciesScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Search in External Maps'), findsOneWidget);
    });

    testWidgets(
      'Renders temporary debug diagnostic banner in debug mode with coordinates, radius, and results',
      (tester) async {
        final mockPayload = {
          'version': 0.6,
          'elements': [
            {
              'type': 'node',
              'id': 7001,
              'lat': 33.6890,
              'lon': 73.0479,
              'tags': {'amenity': 'pharmacy', 'name': 'Capital Chemist'},
            },
          ],
        };

        final client = MockClient(
          (_) async => http.Response(jsonEncode(mockPayload), 200),
        );
        final locationAdapter = _FakeLocationAdapter(
          serviceEnabled: true,
          initialPermission: LocationPermission.whileInUse,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(
                DeviceLocationService(adapter: locationAdapter),
              ),
              overpassPharmacyServiceProvider.overrideWithValue(
                OverpassPharmacyService(httpClient: client),
              ),
            ],
            child: const MaterialApp(home: NearbyPharmaciesScreen()),
          ),
        );

        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('nearby_pharmacies_debug_diagnostic_banner')),
          findsOneWidget,
        );
        expect(find.text('DEBUG DIAGNOSTIC'), findsOneWidget);
        expect(find.text('Coords: '), findsOneWidget);
        expect(find.text('Radius: '), findsOneWidget);
        expect(find.text('Provider: '), findsOneWidget);
        expect(find.text('HTTP Status: '), findsOneWidget);
        expect(find.text('Results: '), findsOneWidget);
      },
    );

    test(
      'Parses OpenStreetMap Nominatim response at 25 km radius, respects radius bounds, and sorts nearest-first',
      () {
        final nominatimPayload = [
          // Near pharmacy (~2.2 km north)
          {
            'place_id': 101,
            'osm_type': 'node',
            'osm_id': 5001,
            'lat': '33.7044',
            'lon': '73.0479',
            'name': 'Shaheen Chemist',
            'category': 'amenity',
            'type': 'pharmacy',
            'display_name': 'Shaheen Chemist, F-8, Islamabad',
            'extratags': {'phone': '051-2254321', 'brand': 'Shaheen'},
            'address': {
              'road': 'Kaghan Road',
              'suburb': 'F-8 Markaz',
              'city': 'Islamabad',
            },
          },
          // Far pharmacy (~15.2 km south)
          {
            'place_id': 102,
            'osm_type': 'node',
            'osm_id': 5002,
            'lat': '33.5475',
            'lon': '73.0479',
            'name': 'Al-Madina Medical Store',
            'category': 'shop',
            'type': 'chemist',
            'display_name': 'Al-Madina Medical Store, Rawalpindi',
            'extratags': {'contact:phone': '051-4422110'},
            'address': {
              'road': 'Murree Road',
              'suburb': 'Saddar',
              'city': 'Rawalpindi',
            },
          },
          // Out of 25km radius pharmacy (~30 km away)
          {
            'place_id': 103,
            'osm_type': 'node',
            'osm_id': 5003,
            'lat': '33.4000',
            'lon': '73.0479',
            'category': 'amenity',
            'type': 'pharmacy',
            'display_name': 'Remote Country Chemist',
          },
        ];

        final parsed = OverpassPharmacyService.parseNominatimResponseBody(
          jsonEncode(nominatimPayload),
          userLatitude: userLat,
          userLongitude: userLon,
          maxRadiusMeters: 25000,
        );

        // Remote 30km pharmacy excluded by 25km radius limit
        expect(parsed.length, equals(2));
        expect(parsed[0].name, equals('Shaheen Chemist'));
        expect(parsed[0].chainName, equals('Shaheen'));
        expect(parsed[0].phone, equals('051-2254321'));
        expect(parsed[0].distanceMeters, lessThan(parsed[1].distanceMeters));
        expect(parsed[1].name, equals('Al-Madina Medical Store'));
        expect(parsed[1].phone, equals('051-4422110'));
      },
    );

    test(
      'Mapbox Tilequery clamps radius to 10000m to prevent HTTP 422 errors at 25km radius',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.contains('/category/pharmacy')) {
            // Search Box category search returns 0 in Pakistan
            return http.Response(
              jsonEncode({'type': 'FeatureCollection', 'features': []}),
              200,
            );
          }
          if (req.url.path.contains('/tilequery')) {
            // Verify radius query param is clamped to max 10000m
            expect(req.url.queryParameters['radius'], equals('10000'));
            return http.Response(
              jsonEncode({
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'id': 9901,
                    'geometry': {
                      'type': 'Point',
                      'coordinates': [73.0479, 33.6900],
                    },
                    'properties': {
                      'type': 'pharmacy',
                      'name': 'D-Watson Blue Area',
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final service = MapboxPharmacyService(
          httpClient: client,
          accessToken:
              'pk.eyJ1IjoiZXhhbXBsZSIsImEiOiJjbGV4YW1wbGUwMDAwIn0.abcdef',
        );

        final result = await service.fetchNearbyPharmacies(
          latitude: userLat,
          longitude: userLon,
          radiusMeters: 25000,
        );

        expect(result.pharmacies.length, equals(1));
        expect(result.pharmacies.first.name, equals('D-Watson Blue Area'));
      },
    );

    test(
      'Real device coordinates are passed through to provider queries without hardcoding',
      () async {
        const double karachiLat = 24.8607;
        const double karachiLon = 67.0011;

        final client = MockClient((req) async {
          final body = req.body;
          expect(body, contains('24.860700'));
          expect(body, contains('67.001100'));
          expect(body, contains('25000'));
          return http.Response(
            jsonEncode({'version': 0.6, 'elements': []}),
            200,
          );
        });

        final service = OverpassPharmacyService(httpClient: client);
        await service.fetchNearbyPharmacies(
          latitude: karachiLat,
          longitude: karachiLon,
          radiusMeters: 25000,
        );
      },
    );
  });
}
