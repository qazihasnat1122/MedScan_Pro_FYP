import '../../providers/medication_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/prescription_model.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/scan_providers.dart';
import '../../services/prescription_ai_service.dart';
import '../../services/prescription_parser.dart';

/// Prescription Input & Secure Gemini Extraction Screen.
/// Supports:
/// 1. Camera capture, gallery image selection, and multi-page PDF document upload.
/// 2. File validation (empty, corrupt, or unsupported files handled gracefully).
/// 3. Pre-extraction preview (including multi-page PDF page preview), cancel, and retry.
/// 4. Explicit user privacy & external AI consent dialog before sending data to Gemini.
/// 5. Honest setup/network error reporting without faking extraction results.
class PrescriptionUploadScreen extends ConsumerStatefulWidget {
  final Future<SelectedPrescriptionFile?> Function(ImageSource source)?
  customImagePicker;
  final Future<SelectedPrescriptionFile?> Function()? customPdfPicker;

  const PrescriptionUploadScreen({
    super.key,
    this.customImagePicker,
    this.customPdfPicker,
  });

  @override
  ConsumerState<PrescriptionUploadScreen> createState() =>
      _PrescriptionUploadScreenState();
}

class _PrescriptionUploadScreenState
    extends ConsumerState<PrescriptionUploadScreen> {
  SelectedPrescriptionFile? _selectedFile;
  bool _isValidatingFile = false;
  bool _isExtracting = false;
  String? _errorMessage;
  bool _isSetupError = false;
  int _currentPreviewPage = 0;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _isSetupError = false;
      _isValidatingFile = true;
    });

    try {
      SelectedPrescriptionFile? prepared;
      if (widget.customImagePicker != null) {
        prepared = await widget.customImagePicker!(source);
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (picked != null) {
          final aiService = ref.read(prescriptionAiServiceProvider);
          prepared = await aiService.validateAndPrepareFile(
            File(picked.path),
            explicitFileName: picked.name,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        if (prepared != null) {
          _selectedFile = prepared;
          _currentPreviewPage = 0;
        }
      });
    } on PrescriptionFileException catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        _errorMessage = 'Could not load image file. Please try another file.';
      });
    }
  }

  Future<void> _pickPdf() async {
    setState(() {
      _errorMessage = null;
      _isSetupError = false;
      _isValidatingFile = true;
    });

    try {
      final aiService = ref.read(prescriptionAiServiceProvider);
      final prepared = widget.customPdfPicker != null
          ? await widget.customPdfPicker!()
          : await aiService.pickPdfDocument();

      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        if (prepared != null) {
          _selectedFile = prepared;
          _currentPreviewPage = 0;
        }
      });
    } on PrescriptionFileException catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isValidatingFile = false;
        _errorMessage =
            'Unable to open the selected PDF file. Please verify the file is not corrupted.';
      });
    }
  }

  void _cancelSelection() {
    setState(() {
      _selectedFile = null;
      _errorMessage = null;
      _isSetupError = false;
      _currentPreviewPage = 0;
    });
  }

  Future<bool> _showExternalAiConsentDialog() async {
    final consented = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFF087F8C)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'External AI Processing Consent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before proceeding, please review how your prescription is processed:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              '• Your selected prescription image or PDF will be securely sent to an external AI service (Google Gemini via MedScan Pro\'s authenticated backend) solely to extract visible text and medication details.\n'
              '• AI extraction is for text transcription only — it does NOT provide medical diagnosis, treatment advice, or verify clinical accuracy.\n'
              '• Missing or unclear fields will be highlighted for your manual review. Nothing is saved until you review and confirm.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('ai_consent_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('ai_consent_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF087F8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I Consent & Extract'),
          ),
        ],
      ),
    );
    return consented == true;
  }

  Future<void> _requestConsentAndExtract() async {
    if (_selectedFile == null || _isExtracting) return;

    final consented = await _showExternalAiConsentDialog();
    if (!consented || !mounted) return;

    await _runGeminiExtraction();
  }

  Future<void> _runGeminiExtraction() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _isSetupError = false;
    });

    try {
      final aiService = ref.read(prescriptionAiServiceProvider);
      final result = await aiService.extractPrescription(file);

      if (!mounted) return;
      setState(() => _isExtracting = false);

      context.push(
        '/prescriptions/review',
        extra: <String, dynamic>{
          'items': result.medicines,
          'imagePath': file.path,
          'previewImagePaths': file.previewImagePaths,
          'rawText': result.rawText,
          'prescriptionDate': result.prescriptionDate,
          'mimeType': file.mimeType,
          'fileName': file.fileName,
          'extractionSource': result.extractionSource,
        },
      );
    } on PrescriptionExtractionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = e.message;
        _isSetupError = e.isSetupError;
      });
    } on PrescriptionFileException catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = e.message;
        _isSetupError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage =
            'Prescription extraction failed unexpectedly. Please retry or review manually.';
        _isSetupError = false;
      });
    }
  }

  Future<void> _runLocalOcrFallback() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final ocr = ref.read(ocrServiceProvider);
      final buffer = StringBuffer();
      final pathsToScan = file.previewImagePaths.isNotEmpty
          ? file.previewImagePaths
          : <String>[file.path];

      for (final imgPath in pathsToScan) {
        if (!imgPath.toLowerCase().endsWith('.pdf')) {
          final pageText = await ocr.extractTextFromImage(imgPath);
          if (pageText.trim().isNotEmpty) {
            buffer.writeln(pageText.trim());
          }
        }
      }

      final rawText = buffer.toString().trim();
      final parsedItems = PrescriptionParser.parse(rawText);
      final rxDate = PrescriptionParser.extractPrescriptionDate(rawText);

      if (!mounted) return;
      setState(() => _isExtracting = false);

      context.push(
        '/prescriptions/review',
        extra: <String, dynamic>{
          'items': parsedItems,
          'imagePath': file.path,
          'previewImagePaths': file.previewImagePaths,
          'rawText': rawText,
          'prescriptionDate': rxDate,
          'mimeType': file.mimeType,
          'fileName': file.fileName,
          'extractionSource': 'local_ocr_fallback',
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage =
            'Local OCR could not read this file. You can still proceed to manual entry with the preview.';
      });
    }
  }

  void _openManualReviewWithPreview() {
    final file = _selectedFile;
    context.push(
      '/prescriptions/review',
      extra: <String, dynamic>{
        'items': <PrescriptionMedicineItem>[],
        'imagePath': file?.path ?? '',
        'previewImagePaths': file?.previewImagePaths ?? const <String>[],
        'rawText': '',
        'prescriptionDate': '',
        'mimeType': file?.mimeType ?? 'image/jpeg',
        'fileName': file?.fileName ?? 'manual_prescription',
        'extractionSource': 'manual',
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF087F8C);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Prescription'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Safety disclaimer banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryTeal.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: primaryTeal,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Import a clear photo or PDF of your prescription. You will review and confirm every extracted field before anything is saved to your history.',
                      style: TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Banner (File validation or Gemini backend error)
            if (_errorMessage != null) ...[
              Container(
                key: const Key('prescription_error_banner'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isSetupError
                                ? 'Backend Setup Required'
                                : 'Extraction / File Issue',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF7F1D1D),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('retry_extraction_button'),
                            onPressed: _isExtracting
                                ? null
                                : _requestConsentAndExtract,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry AI Extraction'),
                          ),
                          if (!_selectedFile!.isPdf ||
                              _selectedFile!.previewImagePaths.isNotEmpty)
                            OutlinedButton.icon(
                              key: const Key('local_ocr_fallback_button'),
                              onPressed: _isExtracting
                                  ? null
                                  : _runLocalOcrFallback,
                              icon: const Icon(
                                Icons.document_scanner_outlined,
                                size: 16,
                              ),
                              label: const Text('Use On-Device OCR'),
                            ),
                          TextButton.icon(
                            key: const Key('manual_entry_fallback_button'),
                            onPressed: _isExtracting
                                ? null
                                : _openManualReviewWithPreview,
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Enter Manually'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isValidatingFile || _isExtracting)
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: primaryTeal),
                    const SizedBox(height: 16),
                    Text(
                      _isValidatingFile
                          ? 'Validating document & rendering preview...'
                          : 'Extracting prescription fields with Gemini...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else if (_selectedFile == null) ...[
              _buildSourceSelectionCard(primaryTeal, isDark),
              const SizedBox(height: 24),
              _buildSavedPrescriptionsSection(context, primaryTeal, isDark),
            ] else
              _buildPreviewAndActionCard(_selectedFile!, primaryTeal, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelectionCard(Color primaryTeal, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            size: 60,
            color: Color(0xFF087F8C),
          ),
          const SizedBox(height: 14),
          Text(
            'Select Prescription Source',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture a photo with your camera, choose an image from your gallery, or upload a single/multi-page PDF prescription.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('pick_camera_button'),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTeal,
                    side: BorderSide(color: primaryTeal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('pick_gallery_button'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('pick_pdf_button'),
              onPressed: _pickPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Upload PDF Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryTeal,
                side: BorderSide(color: primaryTeal),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAndActionCard(
    SelectedPrescriptionFile file,
    Color primaryTeal,
    bool isDark,
  ) {
    final previewPaths = file.previewImagePaths;
    final hasVisualPreview =
        previewPaths.isNotEmpty && File(previewPaths.first).existsSync();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                file.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_outlined,
                color: primaryTeal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_formatFileSize(file.sizeBytes)} • ${file.isPdf ? 'PDF (${file.pageCount} page${file.pageCount == 1 ? '' : 's'})' : 'Image'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('cancel_selected_file_button'),
                tooltip: 'Cancel & Remove File',
                icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
                onPressed: _cancelSelection,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual Preview (Image or Multi-page PDF carousel)
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasVisualPreview
                ? Stack(
                    children: [
                      PageView.builder(
                        itemCount: previewPaths.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentPreviewPage = idx),
                        itemBuilder: (ctx, idx) {
                          return InteractiveViewer(
                            child: Image.file(
                              File(previewPaths[idx]),
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                      if (previewPaths.length > 1)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Page ${_currentPreviewPage + 1} of ${previewPaths.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          file.isPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          size: 48,
                          color: primaryTeal,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          file.isPdf
                              ? 'PDF Ready (${file.pageCount} page${file.pageCount == 1 ? '' : 's'})'
                              : 'Image Selected',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            key: const Key('extract_with_gemini_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text(
              'Extract Prescription with AI',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _requestConsentAndExtract,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('change_file_button'),
                  onPressed: _cancelSelection,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Cancel / Choose Another'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPrescriptionsSection(
    BuildContext context,
    Color primaryTeal,
    bool isDark,
  ) {
    final prescriptionsAsync = ref.watch(userPrescriptionsProvider);
    final prescriptions = prescriptionsAsync.value ?? [];
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.folder_shared_outlined,
              size: 20,
              color: Color(0xFF087F8C),
            ),
            const SizedBox(width: 8),
            Text(
              'Saved Prescriptions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const Spacer(),
            if (prescriptions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ' Stored',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryTeal,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (prescriptions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 38, color: textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No saved prescriptions yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capture or upload a prescription above. Confirmed records will appear here securely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...prescriptions.map((rx) {
            final isPdf =
                rx.mimeType.contains('pdf') ||
                rx.imagePath.toLowerCase().endsWith('.pdf');
            final dateStr = rx.prescriptionDate.isNotEmpty
                ? rx.prescriptionDate
                : rx.uploadedAt.toString().split(' ').first;
            final medNames = rx.extractedMedicines.isNotEmpty
                ? rx.extractedMedicines.take(3).join(', ')
                : 'No structured medicines listed';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      color: isPdf ? const Color(0xFFEF4444) : primaryTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isPdf ? 'PDF Prescription' : 'Prescription Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• $dateStr',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medNames,
                          style: TextStyle(fontSize: 12, color: textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: 'View Prescription Details',
                    onPressed: () => _viewPrescriptionDetails(rx),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Delete Prescription',
                    onPressed: () => _confirmDeletePrescription(rx),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _viewPrescriptionDetails(PrescriptionModel rx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = Theme.of(ctx).cardColor;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Color(0xFF087F8C)),
                      const SizedBox(width: 8),
                      const Text(
                        'Prescription Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (rx.prescriptionDate.isNotEmpty) ...[
                    Text(
                      'Prescription Date: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Uploaded: ',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Extracted Medications:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (rx.extractedMedicines.isEmpty)
                    const Text(
                      'No medications listed.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...rx.extractedMedicines.map(
                      (m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF087F8C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (rx.imagePath.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Original Attachment:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showPrescriptionAttachmentDialog(
                        path: rx.imagePath,
                        mimeType: rx.mimeType,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF087F8C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF087F8C).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              rx.mimeType.contains('pdf')
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color: const Color(0xFF087F8C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rx.imagePath.split('/').last.split('\\').last,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Color(0xFF087F8C),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePrescription(PrescriptionModel rx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Prescription?'),
        content: const Text(
          'Are you sure you want to delete this prescription? This action permanently removes the stored record. Active medication alarms will remain preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = ref.read(authStateProvider).value;
      final uid = user?.uid ?? '';
      try {
        await ref
            .read(medicationRepositoryProvider)
            .deletePrescription(rx, currentUserId: uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prescription deleted successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not delete prescription: '),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showPrescriptionAttachmentDialog({
    required String path,
    required String mimeType,
  }) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return;
    final isPdf = mimeType.contains('pdf') || cleanPath.toLowerCase().endsWith('.pdf');
    final isRemote = cleanPath.startsWith('http://') || cleanPath.startsWith('https://');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  isPdf ? 'PDF Document' : 'Prescription Image',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  if (isRemote)
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open Link',
                      onPressed: () {
                        const MethodChannel('com.medscan.pro/document_picker')
                            .invokeMethod('launchExternalUri', {'uri': cleanPath});
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: isPdf
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 64,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cleanPath.split('/').last.split('\\').last,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                final uri = isRemote ? cleanPath : 'file://';
                                const MethodChannel('com.medscan.pro/document_picker')
                                    .invokeMethod('launchExternalUri', {'uri': uri});
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open PDF in System Viewer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF087F8C),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: isRemote
                            ? Image.network(
                                cleanPath,
                                fit: BoxFit.contain,
                                loadingBuilder: (c, child, progress) => progress == null
                                    ? child
                                    : const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                errorBuilder: (context, error, stackTrace) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Unable to load prescription image from cloud.'),
                                ),
                              )
                            : Image.file(
                                File(cleanPath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Original file not found on local device storage.'),
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
