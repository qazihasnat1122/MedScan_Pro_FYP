class MedicineModel {
  final String id;
  final String medicineName;
  final String genericName;
  final String strength;
  final String dosageForm; // 'Tablet' | 'Capsule' | 'Syrup' | 'Injection' | 'Suspension'
  final String manufacturerId;
  final String manufacturerName;
  final String referenceNumber;
  final String registrationStatus; // e.g. "Registered", "Approved"
  final String dataSourceType; // 'general_reference' | 'manufacturer_verified'
  final bool manufacturerVerified;
  final String verificationLevel;
  final String approvedStatus; // "Approved", "Under Review", "Suspended"
  final String description;
  final List<String> indications;
  final String storageConditions;
  final List<String> packagingSidesAvailable;
  final int activeAlertsCount;
  final DateTime updatedAt;

  MedicineModel({
    required this.id,
    required this.medicineName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.manufacturerId,
    required this.manufacturerName,
    required this.referenceNumber,
    required this.registrationStatus,
    required this.dataSourceType,
    required this.manufacturerVerified,
    required this.verificationLevel,
    required this.approvedStatus,
    required this.description,
    required this.indications,
    required this.storageConditions,
    required this.packagingSidesAvailable,
    required this.activeAlertsCount,
    required this.updatedAt,
  });

  factory MedicineModel.fromMap(Map<String, dynamic> data, String docId) {
    return MedicineModel(
      id: docId,
      medicineName: data['medicineName'] ?? '',
      genericName: data['genericName'] ?? '',
      strength: data['strength'] ?? '',
      dosageForm: data['dosageForm'] ?? 'Tablet',
      manufacturerId: data['manufacturerId'] ?? '',
      manufacturerName: data['manufacturerName'] ?? '',
      referenceNumber: data['referenceNumber'] ?? '',
      registrationStatus: data['registrationStatus'] ?? '',
      dataSourceType: data['dataSourceType'] ?? 'general_reference',
      manufacturerVerified: data['manufacturerVerified'] ?? false,
      verificationLevel: data['verificationLevel'] ?? 'limited_verification',
      approvedStatus: data['approvedStatus'] ?? 'Under Review',
      description: data['description'] ?? '',
      indications: List<String>.from(data['indications'] ?? []),
      storageConditions: data['storageConditions'] ?? '',
      packagingSidesAvailable: List<String>.from(data['packagingSidesAvailable'] ?? []),
      activeAlertsCount: data['activeAlertsCount'] ?? 0,
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'genericName': genericName,
      'strength': strength,
      'dosageForm': dosageForm,
      'manufacturerId': manufacturerId,
      'manufacturerName': manufacturerName,
      'referenceNumber': referenceNumber,
      'registrationStatus': registrationStatus,
      'dataSourceType': dataSourceType,
      'manufacturerVerified': manufacturerVerified,
      'verificationLevel': verificationLevel,
      'approvedStatus': approvedStatus,
      'description': description,
      'indications': indications,
      'storageConditions': storageConditions,
      'packagingSidesAvailable': packagingSidesAvailable,
      'activeAlertsCount': activeAlertsCount,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
