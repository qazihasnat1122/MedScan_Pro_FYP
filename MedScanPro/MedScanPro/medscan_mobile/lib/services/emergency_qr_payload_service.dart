import 'dart:convert';
import '../models/emergency_profile_model.dart';

/// Decoded emergency health profile extracted from a MedScan Pro QR code.
class EmergencyQrData {
  final int schemaVersion;
  final String displayName;
  final int? age;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> medicalConditions;
  final List<String> emergencyContacts;
  final bool isUserReported;
  final String? rawPayload;

  const EmergencyQrData({
    required this.schemaVersion,
    required this.displayName,
    this.age,
    required this.bloodGroup,
    required this.allergies,
    required this.medicalConditions,
    required this.emergencyContacts,
    this.isUserReported = true,
    this.rawPayload,
  });

  bool get isEmpty =>
      displayName.trim().isEmpty &&
      bloodGroup.trim().isEmpty &&
      allergies.isEmpty &&
      medicalConditions.isEmpty &&
      emergencyContacts.isEmpty;
}

enum EmergencyQrDecodeStatus {
  success,
  emptyProfile,
  invalidCode,
  unsupportedVersion,
  error,
}

/// Result of decoding and validating an emergency QR payload.
class EmergencyQrDecodeResult {
  final EmergencyQrDecodeStatus status;
  final EmergencyQrData? data;
  final String message;

  const EmergencyQrDecodeResult._({
    required this.status,
    this.data,
    required this.message,
  });

  factory EmergencyQrDecodeResult.success(EmergencyQrData data) =>
      EmergencyQrDecodeResult._(
        status: EmergencyQrDecodeStatus.success,
        data: data,
        message: 'Emergency profile loaded.',
      );

  factory EmergencyQrDecodeResult.emptyProfile() =>
      const EmergencyQrDecodeResult._(
        status: EmergencyQrDecodeStatus.emptyProfile,
        message: 'No emergency information is available in this QR code.',
      );

  factory EmergencyQrDecodeResult.invalidCode([String? detail]) =>
      EmergencyQrDecodeResult._(
        status: EmergencyQrDecodeStatus.invalidCode,
        message: 'This QR code is not a valid MedScan Pro emergency code.',
      );

  factory EmergencyQrDecodeResult.unsupportedVersion([int? version]) =>
      EmergencyQrDecodeResult._(
        status: EmergencyQrDecodeStatus.unsupportedVersion,
        message: 'This QR code uses an unsupported format.',
      );

  factory EmergencyQrDecodeResult.error(String msg) =>
      EmergencyQrDecodeResult._(
        status: EmergencyQrDecodeStatus.error,
        message: msg,
      );
}

/// Single source of truth for Emergency QR serialization, deserialization,
/// versioning, and validation in MedScan Pro.
class EmergencyQrPayloadService {
  static const String payloadType = 'medscan_emergency';
  static const int currentSchemaVersion = 1;

  /// Encodes a user's emergency profile into a versioned, privacy-filtered JSON payload.
  ///
  /// Strictly respects privacy checkboxes:
  /// - If sharing is disabled, returns an empty string.
  /// - Only includes user-approved fields.
  /// - Excludes sensitive account tokens, passwords, database IDs, and emails.
  static String encodePayload(EmergencyProfileModel profile) {
    if (!profile.isSharingEnabled) {
      return '';
    }

    final Map<String, dynamic> profileMap = {
      if (profile.name.trim().isNotEmpty) 'displayName': profile.name.trim(),
      if (profile.age > 0) 'age': profile.age,
      if (profile.bloodGroup.trim().isNotEmpty)
        'bloodGroup': profile.bloodGroup.trim(),
      if (profile.shareAllergiesInQr && profile.allergiesList.isNotEmpty)
        'allergies': profile.allergiesList
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      if (profile.shareConditionsInQr && profile.medicalConditionsList.isNotEmpty)
        'medicalConditions': profile.medicalConditionsList
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      if (profile.shareContactInQr && profile.emergencyContact.trim().isNotEmpty)
        'emergencyContacts': [profile.emergencyContact.trim()],
      'isUserReported': true,
    };

    final Map<String, dynamic> rootMap = {
      'schemaVersion': currentSchemaVersion,
      'type': payloadType,
      'profile': profileMap,
    };

    return jsonEncode(rootMap);
  }

  /// Decodes and validates any scanned QR payload.
  ///
  /// Supports:
  /// - Versioned JSON payloads (Schema v1)
  /// - Legacy plain-text MedScan emergency payloads (Schema v0)
  ///
  /// Returns validated status and clear, user-facing error messages.
  static EmergencyQrDecodeResult decodePayload(String? rawInput) {
    if (rawInput == null) {
      return EmergencyQrDecodeResult.invalidCode('Null payload');
    }

    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return EmergencyQrDecodeResult.invalidCode('Empty payload');
    }

    // 1. Try structured JSON decoding
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) {
          return EmergencyQrDecodeResult.invalidCode('JSON is not an object');
        }

        final type = decoded['type'];
        if (type != payloadType) {
          return EmergencyQrDecodeResult.invalidCode('Type mismatch: $type');
        }

        final version = decoded['schemaVersion'];
        if (version is! int) {
          return EmergencyQrDecodeResult.invalidCode('Invalid schema version');
        }

        if (version > currentSchemaVersion) {
          return EmergencyQrDecodeResult.unsupportedVersion(version);
        }

        final profileRaw = decoded['profile'];
        if (profileRaw is! Map<String, dynamic>) {
          return EmergencyQrDecodeResult.invalidCode('Missing profile block');
        }

        final displayName = (profileRaw['displayName'] ?? '').toString().trim();
        final bloodGroup = (profileRaw['bloodGroup'] ?? '').toString().trim();

        int? age;
        final rawAge = profileRaw['age'];
        if (rawAge is int) {
          age = rawAge;
        } else if (rawAge != null) {
          age = int.tryParse('$rawAge');
        }

        final allergies = _parseStringList(profileRaw['allergies']);
        final conditions = _parseStringList(profileRaw['medicalConditions']);
        final contacts = _parseStringList(
          profileRaw['emergencyContacts'] ?? profileRaw['emergencyContact'],
        );

        final isUserReported = profileRaw['isUserReported'] != false;

        final qrData = EmergencyQrData(
          schemaVersion: version,
          displayName: displayName,
          age: age,
          bloodGroup: bloodGroup,
          allergies: allergies,
          medicalConditions: conditions,
          emergencyContacts: contacts,
          isUserReported: isUserReported,
          rawPayload: trimmed,
        );

        if (qrData.isEmpty) {
          return EmergencyQrDecodeResult.emptyProfile();
        }

        return EmergencyQrDecodeResult.success(qrData);
      } catch (e) {
        return EmergencyQrDecodeResult.invalidCode('Malformed JSON: $e');
      }
    }

    // 2. Check for legacy MedScan plain-text emergency payload
    if (trimmed.startsWith('MEDSCAN PRO EMERGENCY MEDICAL ID') ||
        trimmed.startsWith('medscan://emergency/')) {
      return _decodeLegacyPlainText(trimmed);
    }

    return EmergencyQrDecodeResult.invalidCode('Unrecognized payload format');
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Parses legacy line-oriented emergency QR payloads for backward compatibility.
  static EmergencyQrDecodeResult _decodeLegacyPlainText(String raw) {
    try {
      final lines = raw.split('\n');
      final map = <String, String>{};
      for (final line in lines) {
        final cleanLine = line.trim();
        if (cleanLine.contains(':')) {
          final idx = cleanLine.indexOf(':');
          final key = cleanLine.substring(0, idx).trim().toLowerCase();
          final val = cleanLine.substring(idx + 1).trim();
          map[key] = val;
        }
      }

      final name = map['name'] ?? '';
      final blood = map['blood group'] ?? map['blood'] ?? '';
      final ageStr = map['age'];
      final age = ageStr != null ? int.tryParse(ageStr) : null;

      final allergiesRaw = map['allergies'] ?? '';
      final allergies = allergiesRaw.isNotEmpty
          ? allergiesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      final conditionsRaw = map['conditions'] ?? map['medical conditions'] ?? '';
      final conditions = conditionsRaw.isNotEmpty
          ? conditionsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      final contact = map['emergency contact'] ?? map['contact'] ?? '';
      final contacts = contact.isNotEmpty ? [contact] : <String>[];

      final qrData = EmergencyQrData(
        schemaVersion: 0,
        displayName: name,
        age: age,
        bloodGroup: blood,
        allergies: allergies,
        medicalConditions: conditions,
        emergencyContacts: contacts,
        isUserReported: true,
        rawPayload: raw,
      );

      if (qrData.isEmpty) {
        return EmergencyQrDecodeResult.emptyProfile();
      }

      return EmergencyQrDecodeResult.success(qrData);
    } catch (_) {
      return EmergencyQrDecodeResult.invalidCode('Failed to parse legacy payload');
    }
  }
}
