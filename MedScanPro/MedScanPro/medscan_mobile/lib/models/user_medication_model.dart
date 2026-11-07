class UserMedicationModel {
  final String id;
  final String userId;
  final String name;
  final String strength;
  final String dosage;
  final String frequency;
  final String genericName;
  final String form;
  final String unit;
  final String category;
  final List<String> reminderTimes;
  final List<String> repeatDays;
  final String mealInstruction;
  final int stockCount;
  final DateTime createdAt;

  UserMedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.strength,
    required this.dosage,
    required this.frequency,
    this.genericName = '',
    this.form = 'Tablet',
    this.unit = 'mg',
    this.category = 'Pain Relief',
    this.reminderTimes = const [],
    this.repeatDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.mealInstruction = 'After Meal',
    this.stockCount = 30,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'strength': strength,
      'dosage': dosage,
      'frequency': frequency,
      'genericName': genericName,
      'form': form,
      'unit': unit,
      'category': category,
      'reminderTimes': reminderTimes,
      'repeatDays': repeatDays,
      'mealInstruction': mealInstruction,
      'stockCount': stockCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserMedicationModel.fromMap(Map<String, dynamic> data, String id) {
    return UserMedicationModel(
      id: id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      strength: data['strength'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      genericName: data['genericName'] ?? '',
      form: data['form'] ?? 'Tablet',
      unit: data['unit'] ?? 'mg',
      category: data['category'] ?? 'Pain Relief',
      reminderTimes: List<String>.from(data['reminderTimes'] ?? []),
      repeatDays: List<String>.from(
        data['repeatDays'] ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
      mealInstruction: data['mealInstruction'] ?? 'After Meal',
      stockCount: data['stockCount'] ?? 30,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }
}
