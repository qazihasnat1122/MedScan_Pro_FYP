import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum DeviceLocationStatus {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  error,
}

class DeviceCoordinates {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime timestamp;

  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.timestamp,
  });

  bool get isValid =>
      !latitude.isNaN &&
      !longitude.isNaN &&
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0 &&
      !(latitude == 0.0 && longitude == 0.0);
}

class DeviceLocationResult {
  final DeviceLocationStatus status;
  final DeviceCoordinates? coordinates;
  final String message;

  const DeviceLocationResult({
    required this.status,
    this.coordinates,
    required this.message,
  });

  bool get isSuccess =>
      status == DeviceLocationStatus.granted &&
      coordinates != null &&
      coordinates!.isValid;
}

/// Abstraction over Geolocator so unit/widget tests can deterministically mock
/// GPS availability, permissions, coordinates, and timeouts without platform channels.
abstract class LocationProviderAdapter {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  });
  Future<Position?> getLastKnownPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorAdapter implements LocationProviderAdapter {
  const GeolocatorAdapter();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) => Geolocator.getCurrentPosition(locationSettings: locationSettings);

  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Foreground device location service for Nearby Pharmacies discovery.
/// Never requests background location and never uses hard-coded coordinates.
class DeviceLocationService {
  final LocationProviderAdapter _adapter;
  final Duration timeout;

  const DeviceLocationService({
    LocationProviderAdapter adapter = const GeolocatorAdapter(),
    this.timeout = const Duration(seconds: 15),
  }) : _adapter = adapter;

  Future<DeviceLocationResult> getCurrentDeviceLocation() async {
    try {
      // 1. Check if device GPS / Location services are enabled
      final serviceEnabled = await _adapter.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.serviceDisabled,
          message:
              'Device location services (GPS) are turned off. Please enable Location in your phone settings to find nearby pharmacies.',
        );
      }

      // 2. Check and request foreground location permission
      LocationPermission permission = await _adapter.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _adapter.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.permissionDenied,
          message:
              'Location permission was denied. MedScan Pro needs foreground location access to search for pharmacies near you.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.permissionPermanentlyDenied,
          message:
              'Location permission is permanently denied. Please open App Settings and grant Location access ("While using the app").',
        );
      }

      if (permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.error,
          message:
              'Unable to determine location permission status on this device.',
        );
      }

      // 3. Acquire current foreground coordinates with timeout
      final position = await _adapter
          .getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeout,
            ),
          )
          .timeout(timeout);

      final coords = DeviceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );

      if (!coords.isValid) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.error,
          message: 'Device returned invalid GPS coordinates.',
        );
      }

      return DeviceLocationResult(
        status: DeviceLocationStatus.granted,
        coordinates: coords,
        message: 'Location acquired.',
      );
    } on TimeoutException {
      // Check if a recent last-known position (within 15 minutes) is available on GPS timeout
      try {
        final lastKnown = await _adapter.getLastKnownPosition();
        if (lastKnown != null) {
          final age = DateTime.now().difference(lastKnown.timestamp).abs();
          final fallbackCoords = DeviceCoordinates(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracyMeters: lastKnown.accuracy,
            timestamp: lastKnown.timestamp,
          );
          if (age <= const Duration(minutes: 15) && fallbackCoords.isValid) {
            return DeviceLocationResult(
              status: DeviceLocationStatus.granted,
              coordinates: fallbackCoords,
              message: 'Using recent device location.',
            );
          }
        }
      } catch (_) {}

      return const DeviceLocationResult(
        status: DeviceLocationStatus.timeout,
        message:
            'Timed out while waiting for a GPS signal. Please move near a window or outdoors and tap Retry.',
      );
    } catch (e) {
      final errText = e.toString().toLowerCase();
      if (errText.contains('location service') &&
          errText.contains('disabled')) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.serviceDisabled,
          message:
              'Device location services (GPS) are turned off. Please enable Location in your phone settings.',
        );
      }
      if (errText.contains('permanently') ||
          errText.contains('deniedforever')) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.permissionPermanentlyDenied,
          message:
              'Location permission is permanently denied. Please enable Location permission in App Settings.',
        );
      }
      if (errText.contains('permission') && errText.contains('denied')) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.permissionDenied,
          message:
              'Location permission was denied. Please grant foreground location permission to find nearby pharmacies.',
        );
      }
      return DeviceLocationResult(
        status: DeviceLocationStatus.error,
        message: 'Could not read device location: $e',
      );
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await _adapter.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await _adapter.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
