class BatchModel {
  final String id;
  final String medicineId;
  final String medicineName;
  final String manufacturerId;
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final String status; // 'Active' | 'Recalled' | 'Quarantine' | 'Expired'
  final int totalUnitsReleased;
  final int reportedScans;
  final bool hasActiveAlert;
  final DateTime createdAt;

  BatchModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.manufacturerId,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.status,
    required this.totalUnitsReleased,
    required this.reportedScans,
    required this.hasActiveAlert,
    required this.createdAt,
  });

  factory BatchModel.fromMap(Map<String, dynamic> data, String docId) {
    return BatchModel(
      id: docId,
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      manufacturerId: data['manufacturerId'] ?? '',
      batchNumber: data['batchNumber'] ?? '',
      manufacturingDate: data['manufacturingDate'] ?? '',
      expiryDate: data['expiryDate'] ?? '',
      status: data['status'] ?? 'Active',
      totalUnitsReleased: data['totalUnitsReleased'] ?? 0,
      reportedScans: data['reportedScans'] ?? 0,
      hasActiveAlert: data['hasActiveAlert'] ?? false,
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'manufacturerId': manufacturerId,
      'batchNumber': batchNumber,
      'manufacturingDate': manufacturingDate,
      'expiryDate': expiryDate,
      'status': status,
      'totalUnitsReleased': totalUnitsReleased,
      'reportedScans': reportedScans,
      'hasActiveAlert': hasActiveAlert,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
