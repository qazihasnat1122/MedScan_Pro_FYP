import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:medscan_mobile/features/pharmacies/nearby_pharmacies_screen.dart';
import 'package:medscan_mobile/providers/pharmacy_providers.dart';
import 'package:medscan_mobile/repositories/pharmacy_repository.dart';
import 'package:medscan_mobile/services/ai_rag_service.dart';
import 'package:medscan_mobile/services/gemini_api_config.dart';
import 'package:medscan_mobile/services/gemini_maps_pharmacy_service.dart';
import 'package:medscan_mobile/services/location_service.dart';
import 'package:medscan_mobile/services/overpass_pharmacy_service.dart';

class _FakeLocationAdapter implements LocationProviderAdapter {
  final double lat;
  final double lng;
  _FakeLocationAdapter({this.lat = 30.6682, this.lng = 73.1114});

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({required LocationSettings locationSettings}) async {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 26, 12, 0),
      accuracy: 5.0,
      altitude: 180.0,
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
  const double userLat = 30.6682;
  const double userLng = 73.1114;
  final testCoords = DeviceCoordinates(
    latitude: userLat,
    longitude: userLng,
    timestamp: DateTime(2026, 10, 26, 12, 0),
  );

  final sampleGroundedResponse = {
    'candidates': [
      {
        'content': {
          'parts': [
            {
              'text':
                  'Here are nearby pharmacies found in Google Maps:\n1. Servaid Pharmacy\n2. Fazal Din\'s Pharma Plus\n3. Clinix Pharmacy',
            },
          ],
        },
        'groundingMetadata': {
          'groundingChunks': [
            {
              'maps': {
                'title': 'Servaid Pharmacy High Street',
                'placeId': 'ChIJ_Servaid123',
                'uri': 'https://maps.google.com/?cid=11111',
                'latLng': {'latitude': 30.6690, 'longitude': 73.1120},
                'address': 'High Street, Sahiwal',
              },
            },
            {
              'maps': {
                'title': 'Fazal Din\'s Pharma Plus',
                'placeId': 'ChIJ_FazalDin456',
                'uri': 'https://maps.google.com/?cid=22222',
                'latLng': {'latitude': 30.6720, 'longitude': 73.1150},
                'address': 'College Road, Sahiwal',
              },
            },
            {
              'maps': {
                'title': 'Clinix Pharmacy',
                'placeId': 'ChIJ_Clinix789',
                'uri': 'https://maps.google.com/?cid=33333',
              },
            },
          ],
          'groundingSupports': [
            {
              'groundingChunkIndices': [0, 1, 2],
            },
          ],
        },
      },
    ],
  };

  final sampleInteractionsResponse = {
    'id': 'interaction_test_123',
    'status': 'completed',
    'steps': [
      {
        'type': 'model_output',
        'content': [
          {
            'type': 'text',
            'text':
                'Here are nearby pharmacies found in Google Maps:\n1. Servaid Pharmacy\n2. Fazal Din\'s Pharma Plus\n3. Clinix Pharmacy',
            'annotations': [
              {
                'type': 'place_citation',
                'name': 'Servaid Pharmacy High Street',
                'place_id': 'ChIJ_Servaid123',
                'url': 'https://maps.google.com/?cid=11111',
                'latLng': {'latitude': 30.6690, 'longitude': 73.1120},
                'address': 'High Street, Sahiwal',
              },
              {
                'type': 'place_citation',
                'name': 'Fazal Din\'s Pharma Plus',
                'place_id': 'ChIJ_FazalDin456',
                'url': 'https://maps.google.com/?cid=22222',
                'latLng': {'latitude': 30.6720, 'longitude': 73.1150},
                'address': 'College Road, Sahiwal',
              },
              {
                'type': 'place_citation',
                'name': 'Clinix Pharmacy',
                'place_id': 'ChIJ_Clinix789',
                'url': 'https://maps.google.com/?cid=33333',
              },
            ],
          },
        ],
      },
    ],
  };

  group('GeminiMapsPharmacyService — Request & Grounding Protocol', () {
    test('Constructs request with Google Maps tool and user coordinates', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;

      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          capturedUri = endpoint;
          capturedBody = body;
          return sampleInteractionsResponse;
        },
      );

      final pharmacies = await service.discoverPharmacies(
        userCoordinates: testCoords,
        radiusMeters: 5000,
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, contains('interactions'));

      expect(capturedBody, isNotNull);
      expect(capturedBody!['model'], equals(GeminiMapsPharmacyService.defaultModel));
      final tools = capturedBody!['tools'] as List<dynamic>;
      expect(tools.any((t) => (t as Map)['type'] == 'google_maps'), isTrue);

      final mapsTool = tools.firstWhere((t) => (t as Map)['type'] == 'google_maps') as Map;
      expect(mapsTool['latitude'], closeTo(userLat, 0.0001));
      expect(mapsTool['longitude'], closeTo(userLng, 0.0001));

      expect(pharmacies.length, equals(3));
      expect(pharmacies[0].name, equals('Servaid Pharmacy High Street'));
      expect(pharmacies[0].placeId, equals('ChIJ_Servaid123'));
      expect(pharmacies[0].mapsUri, equals('https://maps.google.com/?cid=11111'));
      expect(pharmacies[0].isGroundedWithGoogleMaps, isTrue);
      expect(pharmacies[0].hasCoordinates, isTrue);
      expect(pharmacies[0].latitude, closeTo(30.6690, 0.0001));
      expect(pharmacies[0].distanceMeters, greaterThan(0));
      expect(pharmacies[0].dataSource, equals('gemini_google_maps'));

      expect(pharmacies[1].name, equals('Fazal Din\'s Pharma Plus'));
      expect(pharmacies[1].placeId, equals('ChIJ_FazalDin456'));

      expect(pharmacies[2].name, equals('Clinix Pharmacy'));
      expect(pharmacies[2].placeId, equals('ChIJ_Clinix789'));
      expect(pharmacies[2].hasCoordinates, isFalse);
    });

    test('Parses legacy generateContent response for backwards compatibility', () async {
      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return sampleGroundedResponse;
        },
      );

      final pharmacies = await service.discoverPharmacies(
        userCoordinates: testCoords,
      );
      expect(pharmacies.length, equals(3));
      expect(pharmacies[0].name, equals('Servaid Pharmacy High Street'));
    });

    test('Deduplicates duplicate places with matching placeId or normalized name', () async {
      final duplicatePayload = {
        'candidates': [
          {
            'groundingMetadata': {
              'groundingChunks': [
                {
                  'maps': {
                    'title': 'D-Watson Chemist',
                    'placeId': 'ChIJ_DWatson1',
                    'uri': 'https://maps.google.com/?cid=100',
                  },
                },
                {
                  'maps': {
                    'title': 'D-Watson Chemist',
                    'placeId': 'ChIJ_DWatson1', // Duplicate place ID
                    'uri': 'https://maps.google.com/?cid=100',
                  },
                },
                {
                  'maps': {
                    'title': 'd watson chemist', // Duplicate normalized name
                    'placeId': 'ChIJ_DWatson2',
                    'uri': 'https://maps.google.com/?cid=101',
                  },
                },
                {
                  'maps': {
                    'title': 'Shaheen Chemist',
                    'placeId': 'ChIJ_Shaheen1',
                    'uri': 'https://maps.google.com/?cid=200',
                  },
                },
              ],
            },
          },
        ],
      };

      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return duplicatePayload;
        },
      );

      final result = await service.discoverPharmacies(userCoordinates: testCoords);
      expect(result.length, equals(2));
      expect(result[0].name, equals('D-Watson Chemist'));
      expect(result[1].name, equals('Shaheen Chemist'));
    });

    test('Handles missing grounding chunks and empty candidate list gracefully', () async {
      final emptyPayload = {
        'candidates': [
          {
            'content': {'parts': [{'text': 'No pharmacies nearby.'}]},
          },
        ],
      };

      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return emptyPayload;
        },
      );

      final result = await service.discoverPharmacies(userCoordinates: testCoords);
      expect(result, isEmpty);
    });

    test('Handles response without candidates gracefully', () async {
      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return <String, dynamic>{};
        },
      );

      final result = await service.discoverPharmacies(userCoordinates: testCoords);
      expect(result, isEmpty);
    });

    test('Throws GeminiMapsException on HTTP or transport error', () async {
      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          throw const GeminiMapsException('Resource exhausted', statusCode: 429);
        },
      );

      expect(
        () => service.discoverPharmacies(userCoordinates: testCoords),
        throwsA(isA<GeminiMapsException>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('discoverPharmaciesWithDiagnostics captures complete diagnostics on success', () async {
      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return sampleGroundedResponse;
        },
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isTrue);
      expect(diag.statusCode, equals(200));
      expect(diag.candidateCount, equals(1));
      expect(diag.hasGroundingMetadata, isTrue);
      expect(diag.groundedPlaceCount, equals(3));
      expect(diag.fallbackReason, isNull);
      expect(diag.pharmacies.length, equals(3));
    });

    test('discoverPharmaciesWithDiagnostics captures fallback when grounding metadata missing', () async {
      final textOnlyPayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'There is a pharmacy on Jinnah Chowk.'},
              ],
            },
          },
        ],
      };

      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return textOnlyPayload;
        },
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isFalse);
      expect(diag.statusCode, equals(200));
      expect(diag.candidateCount, equals(1));
      expect(diag.hasGroundingMetadata, isFalse);
      expect(diag.groundedPlaceCount, equals(0));
      expect(diag.fallbackReason, contains('without Google Maps grounding chunks'));
      expect(diag.pharmacies, isEmpty);
    });

    test('discoverPharmaciesWithDiagnostics handles HTTP 400 error safely', () async {
      final service = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          throw const GeminiMapsException(
            'Invalid request payload or unsupported toolConfig',
            statusCode: 400,
          );
        },
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isFalse);
      expect(diag.statusCode, equals(400));
      expect(diag.fallbackReason, contains('HTTP 400'));
      expect(diag.errorMessage, contains('Invalid request payload'));
    });

    test('sanitizeError strips API keys and sensitive tokens', () {
      const raw =
          'Error calling https://generativelanguage.googleapis.com?key=AIzaSyA1234567890abcdefghijklmnopqrstuv '
          'with header x-goog-api-key: AIzaSyA1234567890abcdefghijklmnopqrstuv';
      final sanitized = GeminiMapsPharmacyService.sanitizeError(raw);
      expect(sanitized, isNot(contains('AIzaSyA1234567890abcdefghijklmnopqrstuv')));
      expect(sanitized, contains('key=***'));
      expect(sanitized, contains('x-goog-api-key: ***'));
    });

    test('Supported models are verified per official docs and exclude unsupported models', () {
      expect(GeminiMapsPharmacyService.defaultModel, equals('gemini-3.8-flash'));
      final models = GeminiMapsPharmacyService.supportedModels;
      expect(models, contains('gemini-3.8-flash'));
      expect(models, isNot(contains('gemini-1.5-flash')));
      expect(models, isNot(contains('gemini-3.5-flash')));
    });

    test('discoverPharmaciesWithDiagnostics handles HTTP 404 Model Not Found without guessing', () async {
      final service = GeminiMapsPharmacyService(
        apiKey: 'test_key',
        transport: ({required endpoint, required headers, required body}) async {
          throw const GeminiMapsException(
            'models/gemini-unsupported is not found for API version v1beta',
            statusCode: 404,
          );
        },
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isFalse);
      expect(diag.statusCode, equals(404));
      expect(diag.fallbackReason, contains('HTTP 404'));
      expect(diag.fallbackReason, contains('not found or is unsupported'));
    });

    test('discoverPharmaciesWithDiagnostics handles HTTP 429 Quota Exhausted and does not cycle models', () async {
      int transportCallCount = 0;
      final service = GeminiMapsPharmacyService(
        apiKey: 'test_key',
        transport: ({required endpoint, required headers, required body}) async {
          transportCallCount++;
          throw const GeminiMapsException(
            'Resource has been exhausted (check quota).',
            statusCode: 429,
            isQuotaExhausted: true,
          );
        },
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isFalse);
      expect(diag.statusCode, equals(429));
      expect(diag.isQuotaExhausted, isTrue);
      expect(diag.fallbackReason, contains('quota/rate limit exhausted (HTTP 429)'));
      // Verifies that it stopped immediately and did not cycle through additional models
      expect(transportCallCount, equals(1));
    });

    test('discoverPharmaciesWithDiagnostics handles missing API key cleanly', () async {
      final service = GeminiMapsPharmacyService(
        apiKey: '',
      );

      final diag = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(diag.isSuccess, isFalse);
      expect(diag.statusCode, equals(401));
      expect(diag.fallbackReason, contains('Missing API Key'));
    });
  });

  group('PharmacyRepository — Dynamic Discovery Priority', () {
    test('Prioritizes Gemini Google Maps Grounding as primary provider', () async {
      final geminiService = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return sampleGroundedResponse;
        },
      );

      final repo = PharmacyRepository(
        geminiMapsService: geminiService,
      );

      final result = await repo.fetchNearbyRealPharmacies(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 5000,
      );

      expect(result.sourceProvider, equals('gemini_google_maps'));
      expect(result.httpStatusLabel, equals('Grounded with Google Maps'));
      expect(result.pharmacies.length, equals(3));
      expect(result.pharmacies.first.isGroundedWithGoogleMaps, isTrue);
    });

    test('Falls back to Overpass when Gemini Maps returns 0 pharmacies', () async {
      final geminiService = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return {'candidates': []};
        },
      );

      final mockOverpass = OverpassPharmacyService(
        httpClient: FakeOverpassClient([
          {
            'type': 'node',
            'id': 1001,
            'lat': 30.6685,
            'lon': 73.1118,
            'tags': {'name': 'OSM Pharmacy', 'amenity': 'pharmacy'},
          },
        ]),
      );

      final repo = PharmacyRepository(
        geminiMapsService: geminiService,
        overpassService: mockOverpass,
      );

      final result = await repo.fetchNearbyRealPharmacies(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 5000,
      );

      expect(result.sourceProvider, contains('osm'));
      expect(result.pharmacies.length, equals(1));
      expect(result.pharmacies.first.name, equals('OSM Pharmacy'));
      expect(result.geminiFallbackReason, isNotNull);
    });

    test('Falls back and preserves Gemini error diagnostics when Gemini throws exception', () async {
      final geminiService = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          throw const GeminiMapsException('API quota exceeded', statusCode: 429);
        },
      );

      final mockOverpass = OverpassPharmacyService(
        httpClient: FakeOverpassClient([
          {
            'type': 'node',
            'id': 1002,
            'lat': 30.6690,
            'lon': 73.1120,
            'tags': {'name': 'Fallback Chemist', 'amenity': 'pharmacy'},
          },
        ]),
      );

      final repo = PharmacyRepository(
        geminiMapsService: geminiService,
        overpassService: mockOverpass,
      );

      final result = await repo.fetchNearbyRealPharmacies(
        latitude: userLat,
        longitude: userLng,
        radiusMeters: 5000,
      );

      expect(result.sourceProvider, contains('osm'));
      expect(result.geminiStatusCode, equals(429));
      expect(result.geminiFallbackReason, contains('HTTP 429'));
      expect(result.isQuotaExhausted, isTrue);
      expect(result.pharmacies.length, equals(1));
    });
  });

  group('NearbyPharmaciesScreen — Widget Rendering with Grounded Places', () {
    testWidgets('Renders Grounded with Google Maps badge and cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final geminiService = GeminiMapsPharmacyService(
        transport: ({required endpoint, required headers, required body}) async {
          return sampleGroundedResponse;
        },
      );

      final repo = PharmacyRepository(geminiMapsService: geminiService);
      final fakeLocation = DeviceLocationService(
        adapter: _FakeLocationAdapter(lat: userLat, lng: userLng),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geminiMapsPharmacyServiceProvider.overrideWithValue(geminiService),
            pharmacyRepositoryProvider.overrideWithValue(repo),
            deviceLocationServiceProvider.overrideWithValue(fakeLocation),
          ],
          child: const MaterialApp(
            home: NearbyPharmaciesScreen(),
          ),
        ),
      );

      // Advance initial loading
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify Grounded with Google Maps attribution text
      expect(find.text('Grounded with Google Maps'), findsWidgets);

      // Verify pharmacy card titles
      expect(find.text('Servaid Pharmacy High Street'), findsOneWidget);
      expect(find.text('Fazal Din\'s Pharma Plus'), findsOneWidget);
      expect(find.text('Clinix Pharmacy'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Open in Maps'), findsWidgets);
    });
  });

  group('GeminiApiKeyProvider & Unified Key Architecture', () {
    setUp(() {
      GeminiApiKeyProvider.resetForTesting();
    });

    tearDown(() {
      GeminiApiKeyProvider.resetForTesting();
    });

    test('GeminiApiKeyProvider resolves dynamically configured key', () async {
      GeminiApiKeyProvider.setApiKey('test_dynamic_key_123');
      expect(GeminiApiKeyProvider.currentKey, equals('test_dynamic_key_123'));
      expect(AiRagService.geminiApiKey, equals('test_dynamic_key_123'));

      final resolved = await GeminiApiKeyProvider.resolveApiKey();
      expect(resolved, equals('test_dynamic_key_123'));
    });

    test('AiRagService.geminiApiKey delegates to GeminiApiKeyProvider', () async {
      AiRagService.geminiApiKey = 'chat_dialog_key_456';
      expect(GeminiApiKeyProvider.currentKey, equals('chat_dialog_key_456'));

      final resolvedFromPharmacy = await GeminiMapsPharmacyService.resolveApiKey();
      expect(resolvedFromPharmacy, equals('chat_dialog_key_456'));
    });

    test('GeminiMapsPharmacyService returns 401 when no key is configured', () async {
      GeminiApiKeyProvider.resetForTesting();
      final service = GeminiMapsPharmacyService();
      final result = await service.discoverPharmaciesWithDiagnostics(
        userCoordinates: testCoords,
      );

      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('Gemini API key is not configured'));
      expect(result.fallbackReason, contains('GEMINI_API_KEY not configured'));
      expect(result.isSuccess, isFalse);
    });

    test('GeminiMapsPharmacyService.sanitizeError strips API keys from logs', () {
      const dirty = 'Error on https://endpoint?key=AIzaSyA123456789012345678901234567890 with x-goog-api-key: secret_key';
      final sanitized = GeminiMapsPharmacyService.sanitizeError(dirty);
      expect(sanitized, isNot(contains('AIzaSyA123456789012345678901234567890')));
      expect(sanitized, isNot(contains('secret_key')));
      expect(sanitized, contains('key=***'));
    });
  });
}

class FakeOverpassClient extends http.BaseClient {
  final List<Map<String, dynamic>> elements;
  FakeOverpassClient(this.elements);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({'version': 0.6, 'elements': elements});
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
