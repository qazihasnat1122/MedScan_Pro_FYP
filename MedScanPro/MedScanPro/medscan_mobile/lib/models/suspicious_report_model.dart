class SuspiciousReportModel {
  final String id;
  final String userId;
  final String medicineName;
  final String batchNumber;
  final List<String> localPhotoPaths;
  final String reason;
  final String purchaseInfo;
  final String status; // Submitted, Under Review, Reviewed, Closed
  final DateTime submittedAt;

  SuspiciousReportModel({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.batchNumber,
    required this.localPhotoPaths,
    required this.reason,
    required this.purchaseInfo,
    required this.status,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicineName': medicineName,
      'batchNumber': batchNumber,
      'localPhotoPaths': localPhotoPaths,
      'reason': reason,
      'purchaseInfo': purchaseInfo,
      'status': status,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}
