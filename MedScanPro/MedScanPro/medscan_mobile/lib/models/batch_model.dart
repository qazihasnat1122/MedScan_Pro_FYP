class BatchModel {
  final String batchId;
  final String medicineId;
  final String manufacturerId;
  final String batchNumber;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final String status;
  final List<String> identifiers;
  final DateTime createdAt;
  final DateTime updatedAt;

  BatchModel({
    required this.batchId,
    required this.medicineId,
    required this.manufacturerId,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.status,
    required this.identifiers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BatchModel.fromMap(Map<String, dynamic> data, String id) {
    return BatchModel(
      batchId: id,
      medicineId: data['medicineId'] ?? '',
      manufacturerId: data['manufacturerId'] ?? '',
      batchNumber: data['batchNumber'] ?? '',
      manufacturingDate: data['manufacturingDate'] != null
          ? DateTime.parse(data['manufacturingDate'].toString())
          : DateTime.now(),
      expiryDate: data['expiryDate'] != null
          ? DateTime.parse(data['expiryDate'].toString())
          : DateTime.now(),
      status: data['status'] ?? 'active',
      identifiers: List<String>.from(data['identifiers'] ?? []),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'].toString())
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'batchNumber': batchNumber,
      'manufacturingDate': manufacturingDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'status': status,
      'identifiers': identifiers,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
