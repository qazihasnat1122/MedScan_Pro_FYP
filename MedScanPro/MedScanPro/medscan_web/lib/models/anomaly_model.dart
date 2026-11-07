class AnomalyModel {
  final String id;
  final String identifier;
  final String medicineId;
  final String manufacturerId;
  final String anomalyType; // e.g., "Repeated scans", "Rapid scans"
  final String description; // MUST use "Unusual scan activity detected"
  final DateTime detectedAt;
  final String status; // "New", "Under Review", "Resolved"

  AnomalyModel({
    required this.id,
    required this.identifier,
    required this.medicineId,
    required this.manufacturerId,
    required this.anomalyType,
    required this.description,
    required this.detectedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'anomalyType': anomalyType,
      'description': description,
      'detectedAt': detectedAt.toIso8601String(),
      'status': status,
    };
  }
}
