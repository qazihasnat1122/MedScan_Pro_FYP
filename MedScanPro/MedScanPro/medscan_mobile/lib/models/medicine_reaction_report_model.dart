/// Represents a user-reported adverse drug reaction.
///
/// NOTE: In accordance with clinical pharmacovigilance standards, unverified
/// user reports are marked as "Pending Review" and are NEVER converted into
/// confirmed manufacturer recalls or causal relationship claims without
/// regulatory agency (DRAP) verification.
class MedicineReactionReportModel {
  final String id;
  final String userId;
  final String medicineName;
  final String suspectedReaction;
  final String onsetTime;
  final String severity; // Mild, Moderate, Severe
  final List<String> localPhotoPaths;
  final bool consentGiven;
  final String status; // Pending Review, Reviewed, Closed
  final DateTime submittedAt;
  final String additionalNotes;

  const MedicineReactionReportModel({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.suspectedReaction,
    required this.onsetTime,
    required this.severity,
    required this.localPhotoPaths,
    required this.consentGiven,
    required this.status,
    required this.submittedAt,
    this.additionalNotes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicineName': medicineName,
      'suspectedReaction': suspectedReaction,
      'onsetTime': onsetTime,
      'severity': severity,
      'localPhotoPaths': localPhotoPaths,
      'consentGiven': consentGiven,
      'status': status,
      'submittedAt': submittedAt.toIso8601String(),
      'additionalNotes': additionalNotes,
    };
  }

  factory MedicineReactionReportModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return MedicineReactionReportModel(
      id: id,
      userId: data['userId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      suspectedReaction: data['suspectedReaction'] ?? '',
      onsetTime: data['onsetTime'] ?? 'Within 1 hour',
      severity: data['severity'] ?? 'Mild',
      localPhotoPaths: List<String>.from(data['localPhotoPaths'] ?? []),
      consentGiven: data['consentGiven'] ?? false,
      status: data['status'] ?? 'Pending Review',
      submittedAt: data['submittedAt'] != null
          ? DateTime.tryParse(data['submittedAt']) ?? DateTime.now()
          : DateTime.now(),
      additionalNotes: data['additionalNotes'] ?? '',
    );
  }
}
