import 'dart:math' as math;

/// Model representing a pharmacy location retrieved from OpenStreetMap (Overpass API)
/// or an explicitly isolated demo entry.
///
/// SAFETY & DATA ACCURACY RULES (§Phase 6):
/// - OpenStreetMap appearance does NOT prove official DRAP or provincial licensing.
/// - Recorded `operatingHours` from map tags do NOT guarantee the pharmacy is currently open.
/// - Map data does NOT indicate live medicine stock availability.
/// - `distanceMeters` is straight-line (great-circle) distance, not driving/walking route distance.
class PharmacyModel {
  final String id;
  final String osmType;
  final int? osmId;
  final String name;
  final String chainName;
  final String licenseNumber;
  final String city;
  final String area;
  final String fullAddress;
  final String phone;
  final String operatingHours;
  final bool is24Hours;
  final bool isDrapLicensed;
  final double? latitude;
  final double? longitude;
  final double distanceMeters;
  final double approximateDistanceKm;
  final String stockNotice;
  final bool isDemo;
  final String dataSource;
  final String verificationStatus;
  final List<String> phoneNumbers;
  final String? coordinatesSource;
  final String? coordinateSource;
  final String? coordinatesAccuracy;
  final String? geocodingStatus;
  final String? verificationEvidence;
  final List<String> sourceUrls;
  final String? sourceRecordId;

  final String? placeId;
  final String? mapsUri;
  final bool isGroundedWithGoogleMaps;

  const PharmacyModel({
    required this.id,
    this.osmType = 'node',
    this.osmId,
    required this.name,
    this.chainName = '',
    this.licenseNumber = '',
    this.city = '',
    this.area = '',
    this.fullAddress = '',
    this.phone = '',
    this.operatingHours = '',
    this.is24Hours = false,
    this.isDrapLicensed = false,
    this.latitude,
    this.longitude,
    double? distanceMeters,
    double? approximateDistanceKm,
    this.stockNotice =
        'Map listing only. Licensing and live medicine stock are not verified — call ahead to confirm availability.',
    this.isDemo = false,
    this.dataSource = 'osm',
    this.verificationStatus = 'unverified',
    this.phoneNumbers = const [],
    this.coordinatesSource,
    this.coordinateSource,
    this.coordinatesAccuracy,
    this.geocodingStatus,
    this.verificationEvidence,
    this.sourceUrls = const [],
    this.sourceRecordId,
    this.placeId,
    this.mapsUri,
    this.isGroundedWithGoogleMaps = false,
  }) : distanceMeters =
           distanceMeters ??
           (approximateDistanceKm != null
               ? approximateDistanceKm * 1000.0
               : (latitude != null && longitude != null ? 0.0 : double.infinity)),
       approximateDistanceKm =
           approximateDistanceKm ??
           (distanceMeters != null
               ? distanceMeters / 1000.0
               : (latitude != null && longitude != null ? 0.0 : double.infinity));

  /// Returns true if coordinates are present and non-zero.
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      !latitude!.isNaN &&
      !longitude!.isNaN &&
      !(latitude == 0.0 && longitude == 0.0);

  /// Returns true if distance was successfully calculated and is valid.
  bool get hasDistance =>
      hasCoordinates &&
      !distanceMeters.isNaN &&
      !distanceMeters.isInfinite &&
      distanceMeters >= 0;

  /// User-facing label describing coordinate accuracy and level of certainty
  String get accuracyBadgeLabel {
    if (isGroundedWithGoogleMaps) {
      return hasDistance ? shortDistanceLabel : 'Google Maps';
    }
    if (!hasCoordinates) return 'GPS Pending';
    return formattedStraightLineDistance;
  }

  /// Action button label
  String get directionsButtonLabel {
    if (isGroundedWithGoogleMaps) return 'Open in Maps';
    if (!hasCoordinates) return 'Copy Address';
    return 'Directions';
  }

  /// Stable deduplication key based on OSM element type and ID, source record ID, or coordinates fallback.
  String get deduplicationKey {
    if (osmId != null && osmType.isNotEmpty) {
      return '$osmType/$osmId';
    }
    if (sourceRecordId != null && sourceRecordId!.isNotEmpty) {
      return sourceRecordId!;
    }
    if (id.isNotEmpty) return id;
    if (hasCoordinates) {
      return '${latitude!.toStringAsFixed(5)},${longitude!.toStringAsFixed(5)}:${name.toLowerCase().trim()}';
    }
    return 'unresolved:${name.toLowerCase().trim()}:${city.toLowerCase().trim()}';
  }

  /// Normalizes a pharmacy name for cross-provider duplicate detection.
  static String normalizeNameForComparison(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns true when [other] represents the same physical pharmacy (same ID or
  /// matching normalized name within [distanceThresholdMeters]).
  bool isNearDuplicateOf(
    PharmacyModel other, {
    double distanceThresholdMeters = 35.0,
  }) {
    if (deduplicationKey == other.deduplicationKey) return true;

    // If both have coordinates, evaluate spatial distance
    if (hasCoordinates && other.hasCoordinates) {
      final dist = calculateStraightLineDistanceMeters(
        startLatitude: latitude!,
        startLongitude: longitude!,
        endLatitude: other.latitude!,
        endLongitude: other.longitude!,
      );
      if (dist > distanceThresholdMeters) return false;

      final normA = normalizeNameForComparison(name);
      final normB = normalizeNameForComparison(other.name);
      if (normA.isEmpty || normB.isEmpty) return false;
      if (normA == normB) return true;
      if (normA != 'unnamed pharmacy' &&
          normB != 'unnamed pharmacy' &&
          (normA.contains(normB) || normB.contains(normA))) {
        return true;
      }
      return false;
    }

    // If both lack coordinates, check matching name and area
    if (!hasCoordinates && !other.hasCoordinates) {
      final normA = normalizeNameForComparison(name);
      final normB = normalizeNameForComparison(other.name);
      if (normA.isNotEmpty && normA == normB) {
        if (area.isNotEmpty && other.area.isNotEmpty) {
          return area.toLowerCase().trim() == other.area.toLowerCase().trim();
        }
        return true;
      }
    }

    return false;
  }

  /// True when a usable phone number is present and contains at least 6 digits.
  bool get hasValidPhone {
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (digits.replaceAll('+', '').length >= 6) return true;
    }
    for (final p in phoneNumbers) {
      final digits = p.replaceAll(RegExp(r'[^0-9+]'), '');
      if (digits.replaceAll('+', '').length >= 6) return true;
    }
    return false;
  }

  /// Sanitized phone string suitable for `tel:` URI launching.
  String get dialablePhone {
    if (!hasValidPhone) return '';
    final target = phone.isNotEmpty
        ? phone
        : (phoneNumbers.isNotEmpty ? phoneNumbers.first : '');
    final firstNumber = target.split(RegExp(r'[;,\/]')).first.trim();
    return firstNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  /// Formats straight-line distance in metres (< 1000 m) or kilometres (>= 1000 m),
  /// explicitly labeled as straight-line distance.
  String get formattedStraightLineDistance {
    if (!hasDistance) {
      return 'Coordinates awaiting verification';
    }
    return formatStraightLineDistance(distanceMeters);
  }

  /// Short distance label (e.g. "450 m" or "1.8 km").
  String get shortDistanceLabel {
    if (!hasDistance) {
      return 'GPS unverified';
    }
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000.0).toStringAsFixed(1)} km';
  }

  static String formatStraightLineDistance(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) {
      return 'Distance unavailable';
    }
    if (meters < 1000) {
      return '${meters.round()} m (straight-line)';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km (straight-line)';
  }

  /// Calculates straight-line (Haversine) distance in metres between two WGS84 coordinates.
  static double calculateStraightLineDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(endLatitude - startLatitude);
    final double dLon = _degToRad(endLongitude - startLongitude);

    final double lat1 = _degToRad(startLatitude);
    final double lat2 = _degToRad(endLatitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Defensively parses a single Overpass JSON element (`node`, `way`, or `relation`).
  /// Returns `null` if the element lacks usable coordinates.
  /// Never fabricates missing names, addresses, phones, hours, licensing, or stock.
  static PharmacyModel? fromOverpassElement(
    Map<String, dynamic> element, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final rawType = element['type']?.toString().trim().toLowerCase() ?? '';
    if (rawType != 'node' && rawType != 'way' && rawType != 'relation') {
      return null;
    }

    final rawId = element['id'];
    final int? osmId = rawId is int
        ? rawId
        : (rawId != null ? int.tryParse(rawId.toString()) : null);

    // Extract coordinates: direct lat/lon for nodes, center.lat/center.lon for ways/relations
    double? lat;
    double? lon;
    if (rawType == 'node') {
      lat = _toDouble(element['lat']);
      lon = _toDouble(element['lon']);
    } else {
      final center = element['center'];
      if (center is Map) {
        lat = _toDouble(center['lat']);
        lon = _toDouble(center['lon']);
      }
      // Fallback if lat/lon are directly on element
      lat ??= _toDouble(element['lat']);
      lon ??= _toDouble(element['lon']);
    }

    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90.0 ||
        lat > 90.0 ||
        lon < -180.0 ||
        lon > 180.0 ||
        (lat == 0.0 && lon == 0.0)) {
      return null;
    }

    final tags = element['tags'] is Map
        ? Map<String, dynamic>.from(element['tags'] as Map)
        : const <String, dynamic>{};

    // 1. Name (only from actual OSM tags; fallback to neutral 'Unnamed pharmacy')
    final rawName = _firstNonEmpty(tags, const [
      'name',
      'name:en',
      'official_name',
      'brand',
      'name:ur',
    ]);
    final name = rawName.isNotEmpty ? rawName : 'Unnamed pharmacy';

    // 2. Brand / Operator (if present)
    final chainName = _firstNonEmpty(tags, const ['brand', 'operator']);

    // 3. Phone (only if present in tags)
    final phone = _firstNonEmpty(tags, const [
      'phone',
      'contact:phone',
      'contact:mobile',
      'mobile',
    ]);

    // 4. Opening hours (only if present in tags; never claim 'Open now')
    final openingHours = _firstNonEmpty(tags, const ['opening_hours']);
    final is24Hours = openingHours.trim().toLowerCase() == '24/7';

    // 5. Address (built only from address tags actually present)
    final fullAddrTag = _firstNonEmpty(tags, const ['addr:full']);
    final houseNumber = _firstNonEmpty(tags, const ['addr:housenumber']);
    final street = _firstNonEmpty(tags, const ['addr:street', 'addr:place']);
    final suburb = _firstNonEmpty(tags, const [
      'addr:suburb',
      'addr:neighbourhood',
      'addr:quarter',
      'addr:sector',
    ]);
    final city = _firstNonEmpty(tags, const [
      'addr:city',
      'addr:town',
      'addr:district',
    ]);
    final postcode = _firstNonEmpty(tags, const ['addr:postcode']);

    String assembledAddress = '';
    if (fullAddrTag.isNotEmpty) {
      assembledAddress = fullAddrTag;
    } else {
      final streetPart = [
        if (houseNumber.isNotEmpty) houseNumber,
        if (street.isNotEmpty) street,
      ].join(' ');
      final parts = <String>[
        if (streetPart.isNotEmpty) streetPart,
        if (suburb.isNotEmpty) suburb,
        if (city.isNotEmpty) city,
        if (postcode.isNotEmpty) postcode,
      ];
      assembledAddress = parts.join(', ');
    }

    final distanceMeters = calculateStraightLineDistanceMeters(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: lat,
      endLongitude: lon,
    );

    final stableId = osmId != null
        ? 'osm_${rawType}_$osmId'
        : 'osm_${rawType}_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    return PharmacyModel(
      id: stableId,
      osmType: rawType,
      osmId: osmId,
      name: name,
      chainName: chainName,
      licenseNumber: '', // Never claim DRAP license from OpenStreetMap
      city: city,
      area: suburb,
      fullAddress: assembledAddress,
      phone: phone,
      operatingHours: openingHours,
      is24Hours: is24Hours,
      isDrapLicensed: false, // Never claim licensed status from OSM
      latitude: lat,
      longitude: lon,
      distanceMeters: distanceMeters,
      approximateDistanceKm: distanceMeters / 1000.0,
      isDemo: false,
      dataSource: 'osm',
    );
  }

  /// Defensively parses a single Mapbox Search Box API v1 GeoJSON feature.
  /// Returns `null` if coordinates are missing or invalid.
  /// Never fabricates missing names, addresses, phones, hours, licensing, or stock.
  static PharmacyModel? fromMapboxFeature(
    Map<String, dynamic> feature, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final properties = feature['properties'] is Map
        ? Map<String, dynamic>.from(feature['properties'] as Map)
        : const <String, dynamic>{};
    final geometry = feature['geometry'] is Map
        ? Map<String, dynamic>.from(feature['geometry'] as Map)
        : const <String, dynamic>{};

    double? lat;
    double? lon;

    // GeoJSON coordinates are [longitude, latitude]
    final coordsList = geometry['coordinates'];
    if (coordsList is List && coordsList.length >= 2) {
      lon = _toDouble(coordsList[0]);
      lat = _toDouble(coordsList[1]);
    }

    // Fallback to properties.coordinates.{latitude, longitude}
    if (lat == null || lon == null) {
      final propCoords = properties['coordinates'];
      if (propCoords is Map) {
        lat ??= _toDouble(propCoords['latitude']);
        lon ??= _toDouble(propCoords['longitude']);
      }
    }

    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90.0 ||
        lat > 90.0 ||
        lon < -180.0 ||
        lon > 180.0 ||
        (lat == 0.0 && lon == 0.0)) {
      return null;
    }

    final rawName = _firstNonEmpty(properties, const [
      'name',
      'name_preferred',
    ]);
    final name = rawName.isNotEmpty ? rawName : 'Unnamed pharmacy';

    final brandList = properties['brand'];
    String chainName = '';
    if (brandList is List && brandList.isNotEmpty) {
      chainName = brandList.first?.toString().trim() ?? '';
    } else if (brandList is String) {
      chainName = brandList.trim();
    }

    final context = properties['context'] is Map
        ? Map<String, dynamic>.from(properties['context'] as Map)
        : const <String, dynamic>{};

    String extractContextName(String key) {
      final entry = context[key];
      if (entry is Map) {
        return entry['name']?.toString().trim() ?? '';
      }
      return '';
    }

    final area = [
      extractContextName('neighborhood'),
      extractContextName('locality'),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final city = [
      extractContextName('place'),
      extractContextName('district'),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');

    final fullAddress = _firstNonEmpty(properties, const [
      'full_address',
      'address',
      'place_formatted',
    ]);

    final metadata = properties['metadata'] is Map
        ? Map<String, dynamic>.from(properties['metadata'] as Map)
        : const <String, dynamic>{};

    final phone = _firstNonEmpty(metadata, const ['phone']);

    String operatingHours = '';
    final rawOpenHours = metadata['open_hours'];
    if (rawOpenHours is String) {
      operatingHours = rawOpenHours.trim();
    } else if (rawOpenHours is Map && rawOpenHours['periods'] is List) {
      operatingHours = 'Hours listed in Mapbox';
    }

    final mapboxId = _firstNonEmpty(properties, const ['mapbox_id']);
    final stableId = mapboxId.isNotEmpty
        ? 'mapbox_$mapboxId'
        : 'mapbox_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    final distanceMeters = calculateStraightLineDistanceMeters(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: lat,
      endLongitude: lon,
    );

    return PharmacyModel(
      id: stableId,
      osmType: 'mapbox_poi',
      osmId: null,
      name: name,
      chainName: chainName,
      licenseNumber: '', // Never claim DRAP license from Mapbox
      city: city,
      area: area,
      fullAddress: fullAddress,
      phone: phone,
      operatingHours: operatingHours,
      is24Hours: operatingHours.toLowerCase() == '24/7',
      isDrapLicensed: false, // Never claim licensed status from Mapbox
      latitude: lat,
      longitude: lon,
      distanceMeters: distanceMeters,
      approximateDistanceKm: distanceMeters / 1000.0,
      isDemo: false,
      dataSource: 'mapbox',
    );
  }

  /// Defensively parses a Mapbox Tilequery API v4 `poi_label` GeoJSON feature
  /// (`mapbox.mapbox-streets-v8`), accepting only genuine pharmacy/chemist POIs.
  static PharmacyModel? fromMapboxTilequeryFeature(
    Map<String, dynamic> feature, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final properties = feature['properties'] is Map
        ? Map<String, dynamic>.from(feature['properties'] as Map)
        : const <String, dynamic>{};
    final geometry = feature['geometry'] is Map
        ? Map<String, dynamic>.from(feature['geometry'] as Map)
        : const <String, dynamic>{};

    final poiType = (properties['type'] ?? '').toString().trim().toLowerCase();
    final maki = (properties['maki'] ?? '').toString().trim().toLowerCase();
    final rawName = _firstNonEmpty(properties, const ['name', 'name_en']);
    final lowerName = rawName.toLowerCase();

    final isPharmacyPoi =
        poiType == 'pharmacy' ||
        poiType == 'chemist' ||
        poiType == 'drugstore' ||
        maki == 'pharmacy' ||
        lowerName.contains('pharmacy') ||
        lowerName.contains('chemist') ||
        lowerName.contains('medical store') ||
        lowerName.contains('medical hall') ||
        lowerName.contains('dawakhana');

    if (!isPharmacyPoi) return null;

    double? lat;
    double? lon;
    final coordsList = geometry['coordinates'];
    if (coordsList is List && coordsList.length >= 2) {
      lon = _toDouble(coordsList[0]);
      lat = _toDouble(coordsList[1]);
    }

    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90.0 ||
        lat > 90.0 ||
        lon < -180.0 ||
        lon > 180.0 ||
        (lat == 0.0 && lon == 0.0)) {
      return null;
    }

    final distanceMeters = calculateStraightLineDistanceMeters(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: lat,
      endLongitude: lon,
    );

    final rawId = feature['id']?.toString().trim() ?? '';
    final stableId = rawId.isNotEmpty
        ? 'mapbox_tq_$rawId'
        : 'mapbox_tq_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    return PharmacyModel(
      id: stableId,
      osmType: 'mapbox_tilequery',
      osmId: int.tryParse(rawId),
      name: rawName.isNotEmpty ? rawName : 'Unnamed pharmacy',
      chainName: '',
      licenseNumber: '',
      city: '',
      area: '',
      fullAddress: '',
      phone: '',
      operatingHours: '',
      is24Hours: false,
      isDrapLicensed: false,
      latitude: lat,
      longitude: lon,
      distanceMeters: distanceMeters,
      approximateDistanceKm: distanceMeters / 1000.0,
      isDemo: false,
      dataSource: 'mapbox',
    );
  }

  /// Defensively parses an OpenStreetMap Nominatim `jsonv2` element (`amenity=pharmacy`).
  static PharmacyModel? fromNominatimElement(
    Map<String, dynamic> item, {
    required double userLatitude,
    required double userLongitude,
  }) {
    final category = (item['category'] ?? '').toString().trim().toLowerCase();
    final type = (item['type'] ?? '').toString().trim().toLowerCase();
    final displayName = (item['display_name'] ?? '').toString().toLowerCase();

    final isPharmacyLike =
        type == 'pharmacy' ||
        type == 'chemist' ||
        category == 'amenity' ||
        category == 'healthcare' ||
        (category == 'shop' && (type == 'chemist' || type == 'pharmacy')) ||
        displayName.contains('pharmacy') ||
        displayName.contains('chemist') ||
        displayName.contains('medical store');

    if (!isPharmacyLike) {
      return null;
    }

    final lat = _toDouble(item['lat']);
    final lon = _toDouble(item['lon']);
    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90.0 ||
        lat > 90.0 ||
        lon < -180.0 ||
        lon > 180.0 ||
        (lat == 0.0 && lon == 0.0)) {
      return null;
    }

    final rawOsmType = (item['osm_type'] ?? 'node')
        .toString()
        .trim()
        .toLowerCase();
    final rawOsmId = item['osm_id'];
    final int? osmId = rawOsmId is int
        ? rawOsmId
        : (rawOsmId != null ? int.tryParse(rawOsmId.toString()) : null);

    final address = item['address'] is Map
        ? Map<String, dynamic>.from(item['address'] as Map)
        : const <String, dynamic>{};
    final extratags = item['extratags'] is Map
        ? Map<String, dynamic>.from(item['extratags'] as Map)
        : const <String, dynamic>{};

    final rawName = [
      (item['name'] ?? '').toString().trim(),
      _firstNonEmpty(address, const ['amenity', 'shop']),
      _firstNonEmpty(extratags, const ['name', 'name:en', 'brand']),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final name = rawName.isNotEmpty ? rawName : 'Unnamed pharmacy';

    final chainName = _firstNonEmpty(extratags, const ['brand', 'operator']);
    final phone = _firstNonEmpty(extratags, const [
      'phone',
      'contact:phone',
      'contact:mobile',
      'mobile',
    ]);
    final openingHours = _firstNonEmpty(extratags, const ['opening_hours']);

    final road = _firstNonEmpty(address, const [
      'road',
      'pedestrian',
      'street',
    ]);
    final suburb = _firstNonEmpty(address, const [
      'suburb',
      'neighbourhood',
      'quarter',
      'city_district',
    ]);
    final city = _firstNonEmpty(address, const [
      'city',
      'town',
      'municipality',
      'county',
    ]);
    final postcode = _firstNonEmpty(address, const ['postcode']);

    final addressParts = <String>[
      if (road.isNotEmpty) road,
      if (suburb.isNotEmpty) suburb,
      if (city.isNotEmpty) city,
      if (postcode.isNotEmpty) postcode,
    ];
    final assembledAddress = addressParts.join(', ');

    final distanceMeters = calculateStraightLineDistanceMeters(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: lat,
      endLongitude: lon,
    );

    final stableId = osmId != null
        ? 'osm_${rawOsmType}_$osmId'
        : 'osm_${rawOsmType}_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';

    return PharmacyModel(
      id: stableId,
      osmType: rawOsmType,
      osmId: osmId,
      name: name,
      chainName: chainName,
      licenseNumber: '',
      city: city,
      area: suburb,
      fullAddress: assembledAddress,
      phone: phone,
      operatingHours: openingHours,
      is24Hours: openingHours.trim().toLowerCase() == '24/7',
      isDrapLicensed: false,
      latitude: lat,
      longitude: lon,
      distanceMeters: distanceMeters,
      approximateDistanceKm: distanceMeters / 1000.0,
      isDemo: false,
      dataSource: 'osm',
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static String _firstNonEmpty(Map<String, dynamic> tags, List<String> keys) {
    for (final k in keys) {
      final val = tags[k]?.toString().trim() ?? '';
      if (val.isNotEmpty &&
          val.toLowerCase() != 'null' &&
          val.toLowerCase() != 'unknown') {
        return val;
      }
    }
    return '';
  }

  /// Factory parsing a grounded pharmacy result returned from Gemini with Google Maps Grounding.
  factory PharmacyModel.fromGoogleMapsGrounding({
    required String name,
    String? placeId,
    String? mapsUri,
    String? address,
    double? latitude,
    double? longitude,
    double? userLatitude,
    double? userLongitude,
  }) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Unnamed Pharmacy';
    final hasCoords = latitude != null &&
        longitude != null &&
        !latitude.isNaN &&
        !longitude.isNaN &&
        !(latitude == 0.0 && longitude == 0.0);

    final dist = (hasCoords && userLatitude != null && userLongitude != null)
        ? calculateStraightLineDistanceMeters(
            startLatitude: userLatitude,
            startLongitude: userLongitude,
            endLatitude: latitude,
            endLongitude: longitude,
          )
        : double.infinity;

    final resolvedUri = (mapsUri != null && mapsUri.trim().isNotEmpty)
        ? mapsUri.trim()
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanName)}';

    final stableId = (placeId != null && placeId.trim().isNotEmpty)
        ? 'gmaps_${placeId.trim()}'
        : 'gmaps_${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    return PharmacyModel(
      id: stableId,
      osmType: 'google_maps_place',
      name: cleanName,
      fullAddress: address?.trim() ?? '',
      placeId: placeId?.trim(),
      mapsUri: resolvedUri,
      isGroundedWithGoogleMaps: true,
      latitude: hasCoords ? latitude : null,
      longitude: hasCoords ? longitude : null,
      distanceMeters: dist,
      approximateDistanceKm: dist.isFinite ? dist / 1000.0 : double.infinity,
      dataSource: 'gemini_google_maps',
      sourceUrls: [resolvedUri],
      verificationStatus: 'unverified',
      stockNotice:
          'Grounded with Google Maps. Operating status and medicine stock are not guaranteed — call or check Google Maps directly.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'osm_type': osmType,
      'osm_id': osmId,
      'name': name,
      'chain_name': chainName,
      'license_number': licenseNumber,
      'city': city,
      'area': area,
      'full_address': fullAddress,
      'phone': phone,
      'phone_numbers': phoneNumbers,
      'operating_hours': operatingHours,
      'is_24_hours': is24Hours,
      'is_drap_licensed': isDrapLicensed,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distanceMeters,
      'approx_distance_km': approximateDistanceKm,
      'stock_notice': stockNotice,
      'is_demo': isDemo,
      'data_source': dataSource,
      'verification_status': verificationStatus,
      'coordinates_source': coordinatesSource,
      'coordinate_source': coordinateSource,
      'coordinates_accuracy': coordinatesAccuracy,
      'geocoding_status': geocodingStatus,
      'verification_evidence': verificationEvidence,
      'source_urls': sourceUrls,
      'source_record_id': sourceRecordId,
      'place_id': placeId,
      'maps_uri': mapsUri,
      'is_grounded_with_google_maps': isGroundedWithGoogleMaps,
    };
  }

  factory PharmacyModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final distMeters = (map['distance_meters'] as num?)?.toDouble();
    final approxKm = (map['approx_distance_km'] as num?)?.toDouble();
    final rawName = map['name']?.toString().trim() ?? '';
    final phoneList = (map['phone_numbers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    return PharmacyModel(
      id: id ?? map['id']?.toString() ?? '',
      osmType: map['osm_type']?.toString() ?? 'node',
      osmId: map['osm_id'] is int
          ? map['osm_id'] as int
          : int.tryParse(map['osm_id']?.toString() ?? ''),
      name: rawName.isNotEmpty ? rawName : 'Unnamed pharmacy',
      chainName: map['chain_name']?.toString() ?? '',
      licenseNumber: map['license_number']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      area: map['area']?.toString() ?? '',
      fullAddress: map['full_address']?.toString() ?? '',
      phone: map['phone']?.toString() ??
          (phoneList.isNotEmpty ? phoneList.first : ''),
      phoneNumbers: phoneList,
      operatingHours: map['operating_hours']?.toString() ?? '',
      is24Hours: map['is_24_hours'] == true,
      isDrapLicensed: map['is_drap_licensed'] == true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      distanceMeters:
          distMeters ?? (approxKm != null ? approxKm * 1000.0 : 0.0),
      approximateDistanceKm:
          approxKm ?? (distMeters != null ? distMeters / 1000.0 : 0.0),
      stockNotice:
          map['stock_notice']?.toString() ??
          'Map listing only. Licensing and live medicine stock are not verified — call ahead to confirm availability.',
      isDemo: map['is_demo'] == true,
      dataSource: map['data_source']?.toString() ?? 'osm',
      verificationStatus: map['verification_status']?.toString() ?? 'unverified',
      coordinatesSource: map['coordinates_source']?.toString() ?? map['coordinate_source']?.toString(),
      coordinateSource: map['coordinate_source']?.toString() ?? map['coordinates_source']?.toString(),
      coordinatesAccuracy: map['coordinates_accuracy']?.toString(),
      geocodingStatus: map['geocoding_status']?.toString(),
      verificationEvidence: map['verification_evidence']?.toString(),
      sourceUrls: (map['source_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sourceRecordId: map['source_record_id']?.toString(),
      placeId: map['place_id']?.toString(),
      mapsUri: map['maps_uri']?.toString(),
      isGroundedWithGoogleMaps: map['is_grounded_with_google_maps'] == true,
    );
  }
}
