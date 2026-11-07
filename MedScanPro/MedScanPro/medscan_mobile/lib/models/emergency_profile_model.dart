import '../services/emergency_qr_payload_service.dart';

/// Model representing the user's emergency medical profile.
///
/// Supports multiple allergies and medical conditions as managed lists,
/// with backwards-compatible string accessors and automated migration from
/// legacy single-value/comma-separated strings.
class EmergencyProfileModel {
  final String userId;
  final String name;
  final int age;
  final String bloodGroup;
  final List<String> allergiesList;
  final List<String> medicalConditionsList;
  final String currentMedicines;
  final String emergencyContact;
  final bool isSharingEnabled;
  final bool shareAllergiesInQr;
  final bool shareConditionsInQr;
  final bool shareContactInQr;
  final bool isUserReported;

  EmergencyProfileModel({
    required this.userId,
    required this.name,
    required this.age,
    required this.bloodGroup,
    required this.allergiesList,
    required this.medicalConditionsList,
    required this.currentMedicines,
    required this.emergencyContact,
    required this.isSharingEnabled,
    this.shareAllergiesInQr = true,
    this.shareConditionsInQr = true,
    this.shareContactInQr = true,
    this.isUserReported = true,
  });

  /// Backwards compatibility accessor returning comma-separated allergies.
  String get allergies => allergiesList.join(', ');

  /// Backwards compatibility accessor returning comma-separated conditions.
  String get medicalConditions => medicalConditionsList.join(', ');

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'age': age,
      'bloodGroup': bloodGroup,
      'allergiesList': allergiesList,
      'medicalConditionsList': medicalConditionsList,
      // Retain legacy keys for backwards compatibility with existing documents
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'currentMedicines': currentMedicines,
      'emergencyContact': emergencyContact,
      'isSharingEnabled': isSharingEnabled,
      'shareAllergiesInQr': shareAllergiesInQr,
      'shareConditionsInQr': shareConditionsInQr,
      'shareContactInQr': shareContactInQr,
      'isUserReported': isUserReported,
    };
  }

  factory EmergencyProfileModel.fromMap(Map<String, dynamic> data) {
    // Migrate legacy allergies (string or list)
    final rawAllergies = data['allergiesList'] ?? data['allergies'];
    List<String> parsedAllergies = [];
    if (rawAllergies is List) {
      parsedAllergies = rawAllergies
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawAllergies is String && rawAllergies.trim().isNotEmpty) {
      parsedAllergies = rawAllergies
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Migrate legacy medicalConditions (string or list)
    final rawConditions =
        data['medicalConditionsList'] ?? data['medicalConditions'];
    List<String> parsedConditions = [];
    if (rawConditions is List) {
      parsedConditions = rawConditions
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawConditions is String && rawConditions.trim().isNotEmpty) {
      parsedConditions = rawConditions
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return EmergencyProfileModel(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] is int
          ? data['age']
          : (int.tryParse('${data['age']}') ?? 0),
      bloodGroup: data['bloodGroup'] ?? '',
      allergiesList: parsedAllergies,
      medicalConditionsList: parsedConditions,
      currentMedicines: data['currentMedicines'] ?? '',
      emergencyContact: data['emergencyContact'] ?? '',
      isSharingEnabled: data['isSharingEnabled'] ?? false,
      shareAllergiesInQr: data['shareAllergiesInQr'] ?? true,
      shareConditionsInQr: data['shareConditionsInQr'] ?? true,
      shareContactInQr: data['shareContactInQr'] ?? true,
      isUserReported: data['isUserReported'] ?? true,
    );
  }

  bool get isEmpty =>
      name.trim().isEmpty &&
      bloodGroup.trim().isEmpty &&
      allergiesList.isEmpty &&
      medicalConditionsList.isEmpty &&
      emergencyContact.trim().isEmpty;

  /// Generates a standardized, versioned, privacy-controlled emergency JSON payload
  /// using [EmergencyQrPayloadService].
  String generateQrPayload() {
    return EmergencyQrPayloadService.encodePayload(this);
  }
}
