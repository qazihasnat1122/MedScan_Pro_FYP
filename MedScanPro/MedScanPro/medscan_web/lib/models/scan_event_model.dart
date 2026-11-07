class ScanEventModel {
  final String id;
  final String identifier;
  final String medicineId;
  final String manufacturerId;
  final String batchNumber;
  final DateTime timestamp;
  final String verificationResult;
  final String? approximateLocation;

  ScanEventModel({
    required this.id,
    required this.identifier,
    required this.medicineId,
    required this.manufacturerId,
    required this.batchNumber,
    required this.timestamp,
    required this.verificationResult,
    this.approximateLocation,
  });
}
