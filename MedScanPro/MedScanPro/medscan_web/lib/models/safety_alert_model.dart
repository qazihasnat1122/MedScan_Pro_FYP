class SafetyAlertModel {
  final String id;
  final String alertNumber;
  final String title;
  final String medicineName;
  final String? batchNumber;
  final String manufacturerName;
  final String shortDescription;
  final String detailedReason;
  final String status; // 'Active' | 'Resolved' | 'Archived'
  final DateTime publishedAt;
  final String severity; // 'High' | 'Medium' | 'Low'

  SafetyAlertModel({
    required this.id,
    required this.alertNumber,
    required this.title,
    required this.medicineName,
    this.batchNumber,
    required this.manufacturerName,
    required this.shortDescription,
    required this.detailedReason,
    required this.status,
    required this.publishedAt,
    required this.severity,
  });

  factory SafetyAlertModel.fromMap(Map<String, dynamic> data, String docId) {
    return SafetyAlertModel(
      id: docId,
      alertNumber: data['alertNumber'] ?? '',
      title: data['title'] ?? '',
      medicineName: data['medicineName'] ?? '',
      batchNumber: data['batchNumber'],
      manufacturerName: data['manufacturerName'] ?? '',
      shortDescription: data['shortDescription'] ?? '',
      detailedReason: data['detailedReason'] ?? '',
      status: data['status'] ?? 'Active',
      publishedAt: data['publishedAt'] != null ? DateTime.parse(data['publishedAt'].toString()) : DateTime.now(),
      severity: data['severity'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertNumber': alertNumber,
      'title': title,
      'medicineName': medicineName,
      'batchNumber': batchNumber,
      'manufacturerName': manufacturerName,
      'shortDescription': shortDescription,
      'detailedReason': detailedReason,
      'status': status,
      'publishedAt': publishedAt.toIso8601String(),
      'severity': severity,
    };
  }
}
