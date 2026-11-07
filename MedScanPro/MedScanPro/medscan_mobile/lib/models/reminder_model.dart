class ReminderModel {
  final String id;
  final String userId;
  final String medicationId;
  final String medicationName;
  final DateTime time;
  final String frequency;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.medicationName,
    required this.time,
    required this.frequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'time': time.toIso8601String(),
      'frequency': frequency,
    };
  }
}
