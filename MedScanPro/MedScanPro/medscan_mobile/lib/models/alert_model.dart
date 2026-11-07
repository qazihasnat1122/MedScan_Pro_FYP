class AlertModel {
  final String id;
  final String title;
  final String message;
  final String level; // INFO, WARNING, CRITICAL
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    required this.createdAt,
  });
}
