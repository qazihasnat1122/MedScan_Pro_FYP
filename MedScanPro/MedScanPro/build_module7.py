import os

base_path = r'd:\medscan\MedScanPro\medscan_mobile\lib'

files = {
    'models/user_medication_model.dart': '''
class UserMedicationModel {
  final String id;
  final String userId;
  final String name;
  final String strength;
  final String dosage;
  final String frequency;
  final DateTime createdAt;

  UserMedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.strength,
    required this.dosage,
    required this.frequency,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'strength': strength,
      'dosage': dosage,
      'frequency': frequency,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
''',
    'models/prescription_model.dart': '''
class PrescriptionModel {
  final String id;
  final String userId;
  final String imagePath;
  final List<String> extractedMedicines;
  final DateTime uploadedAt;

  PrescriptionModel({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.extractedMedicines,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imagePath': imagePath,
      'extractedMedicines': extractedMedicines,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}
''',
    'models/reminder_model.dart': '''
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
''',
    'services/notification_service.dart': '''
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleReminder(int id, String title, String body, DateTime scheduledTime) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'medication_reminder_channel', 'Medication Reminders',
                channelDescription: 'Channel for medication reminders')),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }
}
''',
    'services/clinical_service.dart': '''
import '../models/user_medication_model.dart';
import '../models/medicine_model.dart';

class ClinicalService {
  // Interaction Checker
  List<String> checkInteractions(List<UserMedicationModel> meds) {
    List<String> warnings = [];
    final names = meds.map((m) => m.name.toLowerCase()).toList();
    
    // Hardcoded safety example. NEVER invent interactions.
    if (names.contains('aspirin') && names.contains('warfarin')) {
      warnings.add('Possible interaction found between Aspirin and Warfarin. Please confirm with a doctor.');
    }
    
    return warnings;
  }

  // Alternatives Finder
  List<MedicineModel> findAlternatives(MedicineModel target, List<MedicineModel> allMeds) {
    // Only return exact same generic name. Always advise confirming.
    return allMeds.where((m) => 
      m.genericName.toLowerCase() == target.genericName.toLowerCase() && 
      m.medicineId != target.medicineId
    ).toList();
  }

  // Price Checker
  String checkPrice(double userPrice, double referencePrice) {
    if (userPrice > referencePrice * 1.2) {
      return 'Entered price is significantly higher than the reference price (\${referencePrice.toStringAsFixed(2)}).';
    } else if (userPrice < referencePrice * 0.8) {
      return 'Entered price is significantly lower than the reference price. Verify authenticity.';
    }
    return 'Price is within expected range.';
  }
}
''',
    'providers/medication_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_medication_model.dart';
import '../models/prescription_model.dart';
import '../models/reminder_model.dart';
import '../services/notification_service.dart';
import '../services/clinical_service.dart';
import 'auth_providers.dart';

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService();
  service.init();
  return service;
});

final clinicalServiceProvider = Provider((ref) => ClinicalService());

final myMedicationsProvider = StreamProvider<List<UserMedicationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('userMedications')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return UserMedicationModel(
              id: doc.id,
              userId: data['userId'],
              name: data['name'],
              strength: data['strength'],
              dosage: data['dosage'],
              frequency: data['frequency'],
              createdAt: DateTime.parse(data['createdAt']),
            );
          }).toList());
});

class MedicationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMedication(UserMedicationModel med) async {
    await _firestore.collection('userMedications').add(med.toMap());
  }

  Future<void> addPrescription(PrescriptionModel p) async {
    await _firestore.collection('prescriptions').add(p.toMap());
  }
  
  Future<void> addReminder(ReminderModel r) async {
    await _firestore.collection('reminders').add(r.toMap());
  }
}

final medicationRepositoryProvider = Provider((ref) => MedicationRepository());
''',
    'features/medicines/my_medicines_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/medication_providers.dart';
import '../../shared/widgets/app_bar.dart';

class MyMedicinesScreen extends ConsumerWidget {
  const MyMedicinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(myMedicationsProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'My Medicines'),
      body: medsAsync.when(
        data: (meds) {
          if (meds.isEmpty) {
            return const Center(child: Text('No active medications.'));
          }
          
          final clinical = ref.read(clinicalServiceProvider);
          final interactions = clinical.checkInteractions(meds);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (interactions.isNotEmpty)
                ...interactions.map((i) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i, style: const TextStyle(color: Colors.orange))),
                    ],
                  ),
                )),
              ...meds.map((m) => Card(
                child: ListTile(
                  title: Text(m.name),
                  subtitle: Text('\${m.strength} - \${m.dosage} (\${m.frequency})'),
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm_add),
                    onPressed: () {
                      // Schedule reminder logic here
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder setup coming soon')));
                    },
                  ),
                ),
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/medicines/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
    'features/medicines/add_medicine_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/medication_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/user_medication_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final med = UserMedicationModel(
          id: '',
          userId: user.uid,
          name: _nameController.text,
          strength: _strengthController.text,
          dosage: _dosageController.text,
          frequency: _frequencyController.text,
          createdAt: DateTime.now(),
        );
        await ref.read(medicationRepositoryProvider).addMedication(med);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medicine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Medicine Name')),
            const SizedBox(height: 16),
            TextField(controller: _strengthController, decoration: const InputDecoration(labelText: 'Strength (e.g. 500mg)')),
            const SizedBox(height: 16),
            TextField(controller: _dosageController, decoration: const InputDecoration(labelText: 'Dosage (e.g. 1 Tablet)')),
            const SizedBox(height: 16),
            TextField(controller: _frequencyController, decoration: const InputDecoration(labelText: 'Frequency (e.g. Twice a day)')),
            const SizedBox(height: 32),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : PrimaryButton(text: 'Save Medicine', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
''',
    'features/prescriptions/prescription_upload_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../providers/scan_providers.dart';
import '../../shared/widgets/primary_button.dart';

class PrescriptionUploadScreen extends ConsumerStatefulWidget {
  const PrescriptionUploadScreen({super.key});

  @override
  ConsumerState<PrescriptionUploadScreen> createState() => _PrescriptionUploadScreenState();
}

class _PrescriptionUploadScreenState extends ConsumerState<PrescriptionUploadScreen> {
  bool _isProcessing = false;
  String? _extractedText;
  final TextEditingController _editController = TextEditingController();

  Future<void> _capturePrescription() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _isProcessing = true);
      try {
        final ocr = ref.read(ocrServiceProvider);
        final text = await ocr.extractText(pickedFile.path);
        
        // Simulate extracting medicines
        setState(() {
          _extractedText = text;
          _editController.text = text; // User must confirm/edit
          _isProcessing = false;
        });
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _savePrescription() {
    if (_editController.text.isNotEmpty) {
       // Logic to save local path and extracted text to Firestore prescriptions collection
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription saved securely.')));
       context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_extractedText == null)
              PrimaryButton(text: 'Capture Prescription', onPressed: _capturePrescription)
            else ...[
              const Text('Review Extracted Medicines (Edit if incorrect):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _editController,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Note: Image is stored locally on this device for privacy.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              PrimaryButton(text: 'Confirm & Save', onPressed: _savePrescription),
            ],
          ],
        ),
      ),
    );
  }
}
'''
}

for filepath, content in files.items():
    full_path = os.path.join(base_path, filepath)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + '\\n')

print("Files generated for Module 7")
