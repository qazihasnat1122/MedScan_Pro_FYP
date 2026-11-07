class PrescriptionModel {
  final String id;
  final String userId;
  final String imagePath;
  final List<String> extractedMedicines;
  final List<Map<String, dynamic>> structuredMedicines;
  final String prescriptionDate;
  final String rawText;
  final String mimeType;
  final bool isConfirmedByUser;
  final DateTime uploadedAt;

  PrescriptionModel({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.extractedMedicines,
    this.structuredMedicines = const [],
    this.prescriptionDate = '',
    this.rawText = '',
    this.mimeType = 'image/jpeg',
    this.isConfirmedByUser = true,
    required this.uploadedAt,
  });

  factory PrescriptionModel.fromMap(Map<String, dynamic> data, String id) {
    final rawStructured = data['structuredMedicines'];
    final parsedStructured = <Map<String, dynamic>>[];
    if (rawStructured is List) {
      for (final item in rawStructured) {
        if (item is Map) {
          parsedStructured.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return PrescriptionModel(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      imagePath: (data['imagePath'] ?? '').toString(),
      extractedMedicines: List<String>.from(
        data['extractedMedicines'] ?? const [],
      ),
      structuredMedicines: parsedStructured,
      prescriptionDate: (data['prescriptionDate'] ?? '').toString(),
      rawText: (data['rawText'] ?? '').toString(),
      mimeType: (data['mimeType'] ?? 'image/jpeg').toString(),
      isConfirmedByUser: data['isConfirmedByUser'] != false,
      uploadedAt: data['uploadedAt'] != null
          ? (DateTime.tryParse(data['uploadedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imagePath': imagePath,
      'extractedMedicines': extractedMedicines,
      'structuredMedicines': structuredMedicines,
      'prescriptionDate': prescriptionDate,
      'rawText': rawText,
      'mimeType': mimeType,
      'isConfirmedByUser': isConfirmedByUser,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}
