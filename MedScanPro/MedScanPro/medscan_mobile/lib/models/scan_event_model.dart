class ScanEventModel {
  final String eventId;
  final String userId;
  final String identifier;
  final String medicineId;
  final String? medicineName;
  final String manufacturerId;
  final String batchNumber;
  final DateTime timestamp;
  final String resultCode; // Section 8 Code
  final String? verificationResult; // Section 8 Label
  final String? approximateLocation;
  final List<String> reasons;
  final Map<String, String> observedData;
  final Map<String, String> referenceMatch;
  final List<String> unresolvedUncertainty;

  ScanEventModel({
    required this.eventId,
    required this.userId,
    required this.identifier,
    required this.medicineId,
    this.medicineName,
    required this.manufacturerId,
    required this.batchNumber,
    required this.timestamp,
    required this.resultCode,
    this.verificationResult,
    this.approximateLocation,
    required this.reasons,
    this.observedData = const {},
    this.referenceMatch = const {},
    this.unresolvedUncertainty = const [],
  });

  static String resolveResultLabel(String code) {
    switch (code) {
      case 'MANUFACTURER_SUPPORTED':
        return 'Manufacturer-supported verification';
      case 'REFERENCE_AVAILABLE':
        return 'Reference information available';
      case 'LIMITED_VERIFICATION':
        return 'Limited verification';
      case 'SUSPICIOUS_DETECTED':
        return 'Suspicious indicators detected';
      case 'NO_REFERENCE_FOUND':
        return 'No reference found';
      default:
        return 'Reference information available';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'identifier': identifier,
      'medicineId': medicineId,
      'medicineName': medicineName ?? medicineId,
      'manufacturerId': manufacturerId,
      'batchNumber': batchNumber,
      'timestamp': timestamp.toIso8601String(),
      'resultCode': resultCode,
      'verificationResult':
          verificationResult ?? resolveResultLabel(resultCode),
      'approximateLocation':
          approximateLocation ?? 'Pakistan (Consumer Mobile Device)',
      'reasons': reasons,
      'observedData': observedData,
      'referenceMatch': referenceMatch,
      'unresolvedUncertainty': unresolvedUncertainty,
    };
  }

  factory ScanEventModel.fromMap(Map<String, dynamic> map, String id) {
    final code = map['resultCode'] ?? 'LIMITED_VERIFICATION';
    return ScanEventModel(
      eventId: id,
      userId: map['userId'] ?? '',
      identifier: map['identifier'] ?? '',
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'],
      manufacturerId: map['manufacturerId'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resultCode: code,
      verificationResult: map['verificationResult'] ?? resolveResultLabel(code),
      approximateLocation: map['approximateLocation'],
      reasons: List<String>.from(map['reasons'] ?? []),
      observedData: map['observedData'] != null
          ? Map<String, String>.from(map['observedData'])
          : const {},
      referenceMatch: map['referenceMatch'] != null
          ? Map<String, String>.from(map['referenceMatch'])
          : const {},
      unresolvedUncertainty: map['unresolvedUncertainty'] != null
          ? List<String>.from(map['unresolvedUncertainty'])
          : const [],
    );
  }
}
