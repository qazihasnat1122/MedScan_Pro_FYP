class MedicineModel {
  final String medicineId;
  final String manufacturerId;
  final String companyName;
  final String brandName;
  final String medicineName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String registrationInfo;
  final double referencePrice;
  final String packSize;
  final String indications;
  final String storageCondition;
  final String precautions;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicineModel({
    required this.medicineId,
    required this.manufacturerId,
    this.companyName = '',
    this.brandName = '',
    required this.medicineName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.registrationInfo,
    required this.referencePrice,
    this.packSize = '',
    this.indications = '',
    this.storageCondition = '',
    this.precautions = '',
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicineModel.fromMap(Map<String, dynamic> data, String id) {
    return MedicineModel(
      medicineId: id,
      manufacturerId: data['manufacturerId'] ?? '',
      companyName: data['companyName'] ?? '',
      brandName: data['brandName'] ?? '',
      medicineName: data['medicineName'] ?? '',
      genericName: data['genericName'] ?? '',
      strength: data['strength'] ?? '',
      dosageForm: data['dosageForm'] ?? '',
      registrationInfo: data['registrationInfo'] ?? '',
      referencePrice: (data['referencePrice'] ?? 0.0).toDouble(),
      packSize: data['packSize'] ?? '',
      indications: data['indications'] ?? '',
      storageCondition: data['storageCondition'] ?? '',
      precautions: data['precautions'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
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
      'manufacturerId': manufacturerId,
      'companyName': companyName,
      'brandName': brandName,
      'medicineName': medicineName,
      'genericName': genericName,
      'strength': strength,
      'dosageForm': dosageForm,
      'registrationInfo': registrationInfo,
      'referencePrice': referencePrice,
      'packSize': packSize,
      'indications': indications,
      'storageCondition': storageCondition,
      'precautions': precautions,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
