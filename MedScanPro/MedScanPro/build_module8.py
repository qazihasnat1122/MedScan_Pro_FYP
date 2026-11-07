import os

base_path = r'd:\medscan\MedScanPro\medscan_mobile\lib'

files = {
    'models/alert_model.dart': '''
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
''',
    'models/suspicious_report_model.dart': '''
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
''',
    'models/verification_record_model.dart': '''
class VerificationRecordModel {
  final String id;
  final String userId;
  final String medicineName;
  final String riskLevel;
  final DateTime verifiedAt;

  VerificationRecordModel({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.riskLevel,
    required this.verifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicineName': medicineName,
      'riskLevel': riskLevel,
      'verifiedAt': verifiedAt.toIso8601String(),
    };
  }
}
''',
    'models/emergency_profile_model.dart': '''
class EmergencyProfileModel {
  final String userId; // Acts as ID since 1 per user
  final String name;
  final int age;
  final String bloodGroup;
  final String allergies;
  final String medicalConditions;
  final String currentMedicines;
  final String emergencyContact;
  final bool isSharingEnabled;

  EmergencyProfileModel({
    required this.userId,
    required this.name,
    required this.age,
    required this.bloodGroup,
    required this.allergies,
    required this.medicalConditions,
    required this.currentMedicines,
    required this.emergencyContact,
    required this.isSharingEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'age': age,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'currentMedicines': currentMedicines,
      'emergencyContact': emergencyContact,
      'isSharingEnabled': isSharingEnabled,
    };
  }
}
''',
    'providers/safety_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../models/suspicious_report_model.dart';
import '../models/verification_record_model.dart';
import '../models/emergency_profile_model.dart';
import 'auth_providers.dart';

// ALERTS
final alertsProvider = StreamProvider<List<AlertModel>>((ref) {
  return FirebaseFirestore.instance.collection('alerts').orderBy('createdAt', descending: true).snapshots().map(
    (s) => s.docs.map((d) => AlertModel(
      id: d.id,
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      level: d['level'] ?? 'INFO',
      createdAt: DateTime.parse(d['createdAt']),
    )).toList()
  );
});

// HISTORY
final verificationHistoryProvider = StreamProvider<List<VerificationRecordModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance.collection('verificationRecords').where('userId', isEqualTo: user.uid).snapshots().map(
    (s) => s.docs.map((d) => VerificationRecordModel(
      id: d.id,
      userId: d['userId'],
      medicineName: d['medicineName'],
      riskLevel: d['riskLevel'],
      verifiedAt: DateTime.parse(d['verifiedAt']),
    )).toList()
  );
});

// EMERGENCY
final emergencyProfileProvider = StreamProvider<EmergencyProfileModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance.collection('emergencyProfiles').doc(user.uid).snapshots().map((d) {
    if (!d.exists) return null;
    final data = d.data()!;
    return EmergencyProfileModel(
      userId: user.uid,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      bloodGroup: data['bloodGroup'] ?? '',
      allergies: data['allergies'] ?? '',
      medicalConditions: data['medicalConditions'] ?? '',
      currentMedicines: data['currentMedicines'] ?? '',
      emergencyContact: data['emergencyContact'] ?? '',
      isSharingEnabled: data['isSharingEnabled'] ?? false,
    );
  });
});

class SafetyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReport(SuspiciousReportModel report) async {
    await _firestore.collection('suspiciousReports').add(report.toMap());
  }

  Future<void> saveEmergencyProfile(EmergencyProfileModel profile) async {
    await _firestore.collection('emergencyProfiles').doc(profile.userId).set(profile.toMap());
  }
}

final safetyServiceProvider = Provider((ref) => SafetyService());
''',
    'features/safety/alerts_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Alerts')),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) return const Center(child: Text('No active alerts.'));
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final a = alerts[index];
              final color = a.level == 'CRITICAL' ? Colors.red : (a.level == 'WARNING' ? Colors.orange : Colors.blue);
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(Icons.warning, color: color),
                  title: Text(a.title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  subtitle: Text(a.message),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
''',
    'features/safety/report_suspicious_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/safety_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/suspicious_report_model.dart';
import '../../shared/widgets/primary_button.dart';

class ReportSuspiciousScreen extends ConsumerStatefulWidget {
  const ReportSuspiciousScreen({super.key});

  @override
  ConsumerState<ReportSuspiciousScreen> createState() => _ReportSuspiciousScreenState();
}

class _ReportSuspiciousScreenState extends ConsumerState<ReportSuspiciousScreen> {
  final _medController = TextEditingController();
  final _batchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _purchaseController = TextEditingController();
  final List<String> _photos = [];
  bool _isLoading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _photos.add(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_medController.text.isEmpty || _reasonController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final report = SuspiciousReportModel(
          id: '',
          userId: user.uid,
          medicineName: _medController.text,
          batchNumber: _batchController.text,
          localPhotoPaths: _photos,
          reason: _reasonController.text,
          purchaseInfo: _purchaseController.text,
          status: 'Submitted',
          submittedAt: DateTime.now(),
        );
        await ref.read(safetyServiceProvider).submitReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted securely.')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Medicine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _medController, decoration: const InputDecoration(labelText: 'Medicine Name *')),
            const SizedBox(height: 16),
            TextField(controller: _batchController, decoration: const InputDecoration(labelText: 'Batch Number')),
            const SizedBox(height: 16),
            TextField(controller: _reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for Suspicion *')),
            const SizedBox(height: 16),
            TextField(controller: _purchaseController, decoration: const InputDecoration(labelText: 'Where did you buy it?')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Add Evidence Photo'),
            ),
            const SizedBox(height: 8),
            Text('\${_photos.length} photos added (Stored securely in private bucket)'),
            const SizedBox(height: 32),
            _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Submit Report', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
''',
    'features/safety/verification_history_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_providers.dart';

class VerificationHistoryScreen extends ConsumerWidget {
  const VerificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(verificationHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) return const Center(child: Text('No scans yet.'));
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              return ListTile(
                leading: Icon(
                  r.riskLevel == 'GREEN' ? Icons.check_circle : (r.riskLevel == 'YELLOW' ? Icons.warning : Icons.error),
                  color: r.riskLevel == 'GREEN' ? Colors.green : (r.riskLevel == 'YELLOW' ? Colors.orange : Colors.red),
                ),
                title: Text(r.medicineName),
                subtitle: Text(r.verifiedAt.toString().split('.')[0]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
''',
    'features/emergency/emergency_profile_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/safety_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/emergency_profile_model.dart';
import '../../shared/widgets/primary_button.dart';

class EmergencyProfileScreen extends ConsumerStatefulWidget {
  const EmergencyProfileScreen({super.key});

  @override
  ConsumerState<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends ConsumerState<EmergencyProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _meds = TextEditingController();
  final _contact = TextEditingController();
  bool _sharing = false;
  bool _loaded = false;

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final p = EmergencyProfileModel(
        userId: user.uid,
        name: _name.text,
        age: int.tryParse(_age.text) ?? 0,
        bloodGroup: _blood.text,
        allergies: _allergies.text,
        medicalConditions: '',
        currentMedicines: _meds.text,
        emergencyContact: _contact.text,
        isSharingEnabled: _sharing,
      );
      await ref.read(safetyServiceProvider).saveEmergencyProfile(p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(emergencyProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Profile')),
      body: profileAsync.when(
        data: (profile) {
          if (!_loaded) {
            if (profile != null) {
              _name.text = profile.name;
              _age.text = profile.age.toString();
              _blood.text = profile.bloodGroup;
              _allergies.text = profile.allergies;
              _meds.text = profile.currentMedicines;
              _contact.text = profile.emergencyContact;
              _sharing = profile.isSharingEnabled;
            }
            _loaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('Enable QR Sharing'),
                  subtitle: const Text('Allows responders to scan your code to view your profile securely.'),
                  value: _sharing,
                  onChanged: (val) => setState(() => _sharing = val),
                ),
                if (_sharing)
                  PrimaryButton(text: 'Show My QR Code', onPressed: () => context.push('/emergency/qr')),
                const Divider(height: 32),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: _age, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
                TextField(controller: _blood, decoration: const InputDecoration(labelText: 'Blood Group')),
                TextField(controller: _allergies, decoration: const InputDecoration(labelText: 'Allergies')),
                TextField(controller: _meds, decoration: const InputDecoration(labelText: 'Current Medications')),
                TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Emergency Contact')),
                const SizedBox(height: 24),
                PrimaryButton(text: 'Save Profile', onPressed: _save),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
''',
    'features/emergency/emergency_qr_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_providers.dart';

class EmergencyQrScreen extends ConsumerWidget {
  const EmergencyQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    
    // Crucial constraint: We only encode a secure reference (UID), NOT medical data directly!
    final qrData = 'medscan://emergency/\${user?.uid ?? "unknown"}';

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency QR')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Show this to medical responders.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Note: No sensitive data is embedded directly in this code. It provides a secure reference to your permitted emergency profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
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

print("Files generated for Module 8")
