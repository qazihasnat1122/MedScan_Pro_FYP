class PackagingModel {
  final String referenceId;
  final String medicineId;
  final String manufacturerId;
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? sideImageUrl;
  final List<String> otherImageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  PackagingModel({
    required this.referenceId,
    required this.medicineId,
    required this.manufacturerId,
    this.frontImageUrl,
    this.backImageUrl,
    this.sideImageUrl,
    required this.otherImageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackagingModel.fromMap(Map<String, dynamic> data, String id) {
    return PackagingModel(
      referenceId: id,
      medicineId: data['medicineId'] ?? '',
      manufacturerId: data['manufacturerId'] ?? '',
      frontImageUrl: data['frontImageUrl'],
      backImageUrl: data['backImageUrl'],
      sideImageUrl: data['sideImageUrl'],
      otherImageUrls: List<String>.from(data['otherImageUrls'] ?? []),
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
      'frontImageUrl': frontImageUrl,
      'backImageUrl': backImageUrl,
      'sideImageUrl': sideImageUrl,
      'otherImageUrls': otherImageUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
