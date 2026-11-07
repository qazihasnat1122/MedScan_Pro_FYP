import os

base_path = r'd:\medscan\MedScanPro\medscan_mobile\lib'

files = {
    'services/ocr_service.dart': '''
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
''',
    'repositories/medicine_lookup_repository.dart': '''
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';

class MedicineLookupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<MedicineModel>> searchMedicines(String nameQuery) async {
    // Basic search simulation. In a real scenario, this would use a robust search mechanism (e.g. Algolia/Typesense)
    // Here we just do a simple query
    final snapshot = await _firestore
        .collection('medicines')
        .where('status', isEqualTo: 'approved')
        .get();
        
    return snapshot.docs
        .map((doc) => MedicineModel.fromMap(doc.data(), doc.id))
        .where((med) => med.medicineName.toLowerCase().contains(nameQuery.toLowerCase()) || 
                        nameQuery.toLowerCase().contains(med.medicineName.toLowerCase()))
        .toList();
  }

  Future<List<BatchModel>> searchBatches(String medicineId, String batchNumber) async {
    final snapshot = await _firestore
        .collection('batches')
        .where('medicineId', isEqualTo: medicineId)
        .where('batchNumber', isEqualTo: batchNumber)
        .where('status', isEqualTo: 'active')
        .get();
        
    return snapshot.docs.map((doc) => BatchModel.fromMap(doc.data(), doc.id)).toList();
  }
}
''',
    'providers/scan_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ocr_service.dart';
import '../repositories/medicine_lookup_repository.dart';

final ocrServiceProvider = Provider((ref) => OcrService());
final medicineLookupProvider = Provider((ref) => MedicineLookupRepository());

class ScanData {
  String? frontImagePath;
  String? backImagePath;
  String? sideImagePath;

  String extractedName = '';
  String extractedManufacturer = '';
  String extractedBatch = '';
  String extractedExpiry = '';
  String extractedRegistrationInfo = '';
  String extractedBarcode = '';
  String rawText = '';
}

final scanStateProvider = StateProvider<ScanData>((ref) => ScanData());
''',
    'features/scan/capture_images_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/scan_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';

class CaptureImagesScreen extends ConsumerStatefulWidget {
  const CaptureImagesScreen({super.key});

  @override
  ConsumerState<CaptureImagesScreen> createState() => _CaptureImagesScreenState();
}

class _CaptureImagesScreenState extends ConsumerState<CaptureImagesScreen> {
  final ImagePicker _picker = ImagePicker();
  
  String? frontPath;
  String? backPath;
  String? sidePath;

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        if (type == 'front') frontPath = image.path;
        if (type == 'back') backPath = image.path;
        if (type == 'side') sidePath = image.path;
      });
    }
  }

  void _proceed() {
    if (frontPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Front image is required')));
      return;
    }
    final scanData = ref.read(scanStateProvider.notifier).state;
    scanData.frontImagePath = frontPath;
    scanData.backImagePath = backPath;
    scanData.sideImagePath = sidePath;
    
    context.push('/scan/processing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Medicine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Capture clear images of the medicine packaging. Front image is mandatory.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            _buildImagePicker('Front Image (Required)', frontPath, () => _pickImage('front')),
            const SizedBox(height: 16),
            _buildImagePicker('Back Image (Optional)', backPath, () => _pickImage('back')),
            const SizedBox(height: 16),
            _buildImagePicker('Side Image (Optional)', sidePath, () => _pickImage('side')),
            const SizedBox(height: 32),
            PrimaryButton(text: 'Process Images', onPressed: _proceed),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(String label, String? path, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: path != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover))
                : const Center(child: Icon(Icons.camera_alt, size: 40, color: Colors.grey)),
          ),
        ),
      ],
    );
  }
}
''',
    'features/scan/processing_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _processImages();
  }

  Future<void> _processImages() async {
    try {
      final ocr = ref.read(ocrServiceProvider);
      final scanData = ref.read(scanStateProvider);
      
      String combinedText = '';
      if (scanData.frontImagePath != null) {
        combinedText += await ocr.extractTextFromImage(scanData.frontImagePath!) + '\\n';
      }
      if (scanData.backImagePath != null) {
        combinedText += await ocr.extractTextFromImage(scanData.backImagePath!) + '\\n';
      }
      if (scanData.sideImagePath != null) {
        combinedText += await ocr.extractTextFromImage(scanData.sideImagePath!) + '\\n';
      }

      scanData.rawText = combinedText;
      
      // Extremely basic extraction logic for demonstration
      final lines = combinedText.split('\\n');
      if (lines.isNotEmpty) {
        scanData.extractedName = lines.firstWhere((l) => l.isNotEmpty, orElse: () => '');
        scanData.extractedManufacturer = lines.firstWhere((l) => l.toLowerCase().contains('mfg') || l.toLowerCase().contains('pharma'), orElse: () => '');
        scanData.extractedBatch = lines.firstWhere((l) => l.toLowerCase().contains('batch') || l.toLowerCase().contains('lot'), orElse: () => '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        scanData.extractedExpiry = lines.firstWhere((l) => l.toLowerCase().contains('exp'), orElse: () => '');
      }

      if (mounted) {
        context.pushReplacement('/scan/confirm');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Reading medicine details...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Please hold on while we process the images.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
''',
    'features/scan/live_barcode_scanner.dart': '''
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';

class LiveBarcodeScannerScreen extends StatefulWidget {
  const LiveBarcodeScannerScreen({super.key});

  @override
  State<LiveBarcodeScannerScreen> createState() => _LiveBarcodeScannerScreenState();
}

class _LiveBarcodeScannerScreenState extends State<LiveBarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (_isDisposed) return;
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              context.pop(code);
            }
          }
        },
      ),
    );
  }
}
''',
    'features/scan/confirmation_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';
import '../../shared/widgets/primary_button.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _mfgCtrl;
  late TextEditingController _batchCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _barcodeCtrl;

  @override
  void initState() {
    super.initState();
    final data = ref.read(scanStateProvider);
    _nameCtrl = TextEditingController(text: data.extractedName);
    _mfgCtrl = TextEditingController(text: data.extractedManufacturer);
    _batchCtrl = TextEditingController(text: data.extractedBatch);
    _expCtrl = TextEditingController(text: data.extractedExpiry);
    _regCtrl = TextEditingController(text: data.extractedRegistrationInfo);
    _barcodeCtrl = TextEditingController(text: data.extractedBarcode);
  }

  void _proceed() {
    final data = ref.read(scanStateProvider);
    data.extractedName = _nameCtrl.text;
    data.extractedManufacturer = _mfgCtrl.text;
    data.extractedBatch = _batchCtrl.text;
    data.extractedExpiry = _expCtrl.text;
    data.extractedRegistrationInfo = _regCtrl.text;
    data.extractedBarcode = _barcodeCtrl.text;

    context.push('/scan/result');
  }
  
  Future<void> _scanLiveBarcode() async {
    final result = await context.push('/scan/live_barcode');
    if (result != null && result is String) {
      setState(() {
        _barcodeCtrl.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawText = ref.watch(scanStateProvider).rawText;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Please verify the extracted information. Tap to edit if necessary.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name')),
            const SizedBox(height: 16),
            TextField(controller: _mfgCtrl, decoration: const InputDecoration(labelText: 'Manufacturer')),
            const SizedBox(height: 16),
            TextField(controller: _batchCtrl, decoration: const InputDecoration(labelText: 'Batch Number')),
            const SizedBox(height: 16),
            TextField(controller: _expCtrl, decoration: const InputDecoration(labelText: 'Expiry Date')),
            const SizedBox(height: 16),
            TextField(controller: _regCtrl, decoration: const InputDecoration(labelText: 'Registration Info')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode/QR Data'))),
                IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanLiveBarcode, color: Theme.of(context).primaryColor),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Raw OCR Text (For Reference):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: Text(rawText, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 32),
            PrimaryButton(text: 'Lookup Medicine', onPressed: _proceed),
          ],
        ),
      ),
    );
  }
}
''',
    'features/scan/lookup_result_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scan_providers.dart';
import '../../models/medicine_model.dart';
import '../../models/batch_model.dart';

class LookupResultScreen extends ConsumerStatefulWidget {
  const LookupResultScreen({super.key});

  @override
  ConsumerState<LookupResultScreen> createState() => _LookupResultScreenState();
}

class _LookupResultScreenState extends ConsumerState<LookupResultScreen> {
  bool _isLoading = true;
  List<MedicineModel> _medicines = [];
  List<BatchModel> _batches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _performLookup();
  }

  Future<void> _performLookup() async {
    try {
      final repo = ref.read(medicineLookupProvider);
      final data = ref.read(scanStateProvider);
      
      final meds = await repo.searchMedicines(data.extractedName);
      
      List<BatchModel> matchingBatches = [];
      if (meds.isNotEmpty && data.extractedBatch.isNotEmpty) {
        for (var m in meds) {
          final b = await repo.searchBatches(m.medicineId, data.extractedBatch);
          matchingBatches.addAll(b);
        }
      }

      if (mounted) {
        setState(() {
          _medicines = meds;
          _batches = matchingBatches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lookup Results')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? Center(child: Text('Error: $_error'))
              : _medicines.isEmpty
                  ? const Center(child: Text('No approved medicines found matching this data.'))
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Matches Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ..._medicines.map((m) => Card(
                          child: ListTile(
                            title: Text(m.medicineName),
                            subtitle: Text('Generic: ${m.genericName}\\nStatus: ${m.status}'),
                          ),
                        )),
                        const SizedBox(height: 24),
                        const Text('Batch Matches', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (_batches.isEmpty) const Text('No matching active batches found.'),
                        ..._batches.map((b) => Card(
                          child: ListTile(
                            title: Text('Batch: ${b.batchNumber}'),
                            subtitle: Text('Status: ${b.status}'),
                          ),
                        )),
                      ],
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

print("Files generated for Module 5")
