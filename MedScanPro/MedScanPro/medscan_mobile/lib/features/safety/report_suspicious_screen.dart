import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/safety_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/storage_providers.dart';
import '../../models/suspicious_report_model.dart';
import '../../shared/widgets/primary_button.dart';

class ReportSuspiciousScreen extends ConsumerStatefulWidget {
  const ReportSuspiciousScreen({super.key});

  @override
  ConsumerState<ReportSuspiciousScreen> createState() =>
      _ReportSuspiciousScreenState();
}

class _ReportSuspiciousScreenState
    extends ConsumerState<ReportSuspiciousScreen> {
  final _medController = TextEditingController();
  final _batchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _purchaseController = TextEditingController();
  final List<String> _photos = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _medController.dispose();
    _batchController.dispose();
    _reasonController.dispose();
    _purchaseController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _photos.add(picked.path));
    }
  }

  Future<void> _submit() async {
    final medName = _medController.text.trim();
    final reason = _reasonController.text.trim();

    if (medName.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter medicine name and reason for suspicion.'),
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a safety report.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upload evidence photos to Firebase Storage
      List<String> uploadedUrls = [];
      if (_photos.isNotEmpty) {
        final storage = ref.read(storageServiceProvider);
        uploadedUrls = await storage.uploadReportImages(
          userId: user.uid,
          localPaths: _photos,
        );
      }

      final report = SuspiciousReportModel(
        id: '',
        userId: user.uid,
        medicineName: medName,
        batchNumber: _batchController.text.trim(),
        localPhotoPaths: uploadedUrls.isNotEmpty ? uploadedUrls : _photos,
        reason: reason,
        purchaseInfo: _purchaseController.text.trim(),
        status: 'Submitted',
        submittedAt: DateTime.now(),
      );

      await ref.read(safetyServiceProvider).submitReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suspicious medicine report submitted successfully.'),
            backgroundColor: Color(0xFF087F8C),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF087F8C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Medicine'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.report_problem_outlined, color: Color(0xFFD97706)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your safety report will be reviewed by regulatory authorities and manufacturers.',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _medController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'e.g. Panadol 500mg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _batchController,
              decoration: const InputDecoration(
                labelText: 'Batch Number',
                hintText: 'e.g. B12345',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for Suspicion *',
                hintText:
                    'e.g. Packaging texture looks faded, spelling mistakes, capsule broken...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purchaseController,
              decoration: const InputDecoration(
                labelText: 'Where did you buy it?',
                hintText: 'Pharmacy name, city, or online store',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTeal,
                      side: const BorderSide(color: primaryTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Add Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTeal,
                      side: const BorderSide(color: primaryTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_photos.length} photo(s) selected (Uploaded securely to Firebase Storage)',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryTeal),
                  )
                : PrimaryButton(text: 'Submit Report', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
