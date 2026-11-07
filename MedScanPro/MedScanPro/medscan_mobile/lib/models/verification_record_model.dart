class VerificationRecordModel {
  final String id;
  final String userId;
  final String medicineName;
  final String batchNumber;
  final String
  riskLevel; // Section 8 code: MANUFACTURER_SUPPORTED, REFERENCE_AVAILABLE, etc.
  final String? statusLabel; // Human-readable Section 8 state label
  final DateTime verifiedAt;
  final Map<String, String> observedData;
  final Map<String, String> referenceMatch;
  final List<String> unresolvedUncertainty;

  VerificationRecordModel({
    required this.id,
    required this.userId,
    required this.medicineName,
    this.batchNumber = '',
    required this.riskLevel,
    this.statusLabel,
    required this.verifiedAt,
    this.observedData = const {},
    this.referenceMatch = const {},
    this.unresolvedUncertainty = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicineName': medicineName,
      'batchNumber': batchNumber,
      'riskLevel': riskLevel,
      'statusLabel': statusLabel ?? _resolveLabel(riskLevel),
      'verifiedAt': verifiedAt.toIso8601String(),
      'observedData': observedData,
      'referenceMatch': referenceMatch,
      'unresolvedUncertainty': unresolvedUncertainty,
    };
  }

  static String _resolveLabel(String code) {
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
        return 'Limited verification';
    }
  }

  factory VerificationRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return VerificationRecordModel(
      id: id,
      userId: map['userId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      riskLevel: map['riskLevel'] ?? 'LIMITED_VERIFICATION',
      statusLabel: map['statusLabel'] ?? _resolveLabel(map['riskLevel'] ?? ''),
      verifiedAt: map['verifiedAt'] != null
          ? DateTime.tryParse(map['verifiedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
