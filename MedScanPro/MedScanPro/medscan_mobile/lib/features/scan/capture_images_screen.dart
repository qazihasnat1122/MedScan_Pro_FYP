import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/theme.dart';
import '../../providers/scan_providers.dart';

/// Step configuration for the streamlined 3-step OCR camera capture workflow.
class _ScanStepInfo {
  final String title;
  final String subtitle;
  final String hint;
  final IconData icon;
  final bool isRequired;

  const _ScanStepInfo({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.icon,
    required this.isRequired,
  });
}

/// Streamlined, step-by-step camera capture wizard for medicine packaging OCR.
/// Fixes previous logic errors by guiding the user through exactly one step at a time:
/// Step 1: Front Packaging -> Step 2: Back Packaging -> Step 3: Side/Barcode.
class CaptureImagesScreen extends ConsumerStatefulWidget {
  const CaptureImagesScreen({super.key});

  @override
  ConsumerState<CaptureImagesScreen> createState() =>
      _CaptureImagesScreenState();
}

class _CaptureImagesScreenState extends ConsumerState<CaptureImagesScreen> {
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0; // 0 = Front, 1 = Back, 2 = Side/Barcode

  String? _frontPath;
  String? _backPath;
  String? _sidePath;

  static const List<_ScanStepInfo> _steps = [
    _ScanStepInfo(
      title: 'Front Packaging',
      subtitle: 'Medicine Name & Strength',
      hint:
          'Ensure brand name, strength (e.g., 500mg), and generic salt are clearly in focus.',
      icon: Icons.aspect_ratio_rounded,
      isRequired: true,
    ),
    _ScanStepInfo(
      title: 'Back Packaging',
      subtitle: 'Batch Number & Expiry Date',
      hint:
          'Align printed batch identifier, manufacturing date, and expiry date.',
      icon: Icons.calendar_today_rounded,
      isRequired: true,
    ),
    _ScanStepInfo(
      title: 'Side / Barcode',
      subtitle: '2D DataMatrix or Barcode (Optional)',
      hint:
          'Scan GS1 DataMatrix code, retail barcode, or official registration number.',
      icon: Icons.qr_code_2_rounded,
      isRequired: false,
    ),
  ];

  String? get _currentImagePath {
    switch (_currentStep) {
      case 0:
        return _frontPath;
      case 1:
        return _backPath;
      case 2:
        return _sidePath;
      default:
        return null;
    }
  }

  void _setImageForCurrentStep(String path) {
    setState(() {
      if (_currentStep == 0) _frontPath = path;
      if (_currentStep == 1) _backPath = path;
      if (_currentStep == 2) _sidePath = path;
    });
  }

  Future<void> _captureOrPickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );
      if (file != null) {
        HapticFeedback.lightImpact();
        _setImageForCurrentStep(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to access camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = Theme.of(context).cardColor;
        final textPrimary = isDark
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Capture ${_steps[_currentStep].title}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    'Take Photo with Camera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Recommended for sharpest OCR text detection',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureOrPickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  title: Text(
                    'Upload from Photo Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: const Text('Choose existing packaging image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureOrPickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _frontPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture front packaging photo first.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_currentStep == 1 && _backPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture back packaging with batch and expiry.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finishAndProcess();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finishAndProcess() {
    if (_frontPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Front packaging photo is required for OCR analysis.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final scanData = ref.read(scanStateProvider);
    scanData.frontImagePath = _frontPath;
    scanData.backImagePath = _backPath;
    scanData.sideImagePath = _sidePath;

    context.push('/scan/processing');
  }

  void _quickSampleScan() {
    final scanData = ref.read(scanStateProvider);
    scanData.extractedName = 'Panadol 500mg';
    scanData.extractedManufacturer = 'GSK Pakistan';
    scanData.extractedBatch = 'B1024';
    scanData.extractedExpiry = '12/2027';
    scanData.extractedBarcode = '896400012345';
    scanData.extractedGenericSalt = 'Paracetamol B.P.';
    scanData.extractedStrength = '500mg';
    scanData.extractedDosageForm = 'Tablet';
    scanData.rawText =
        'Panadol 500mg\nParacetamol B.P.\nBatch: B1024\nExp: 12/2027\nMfg: GSK Pakistan\nReg No: 001234';
    context.push('/scan/confirm');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final stepInfo = _steps[_currentStep];
    final currentImg = _currentImagePath;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Capture Medicine Packaging'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _quickSampleScan,
            child: const Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Test Demo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Step Progress Indicator (1 of 3, 2 of 3, 3 of 3) ────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (i) {
                      final isDone =
                          (i == 0 && _frontPath != null) ||
                          (i == 1 && _backPath != null) ||
                          (i == 2 && _sidePath != null);
                      final isCurrent = i == _currentStep;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentStep = i),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : (isDone
                                            ? AppColors.emerald
                                            : Colors.grey.withValues(
                                                alpha: 0.2,
                                              )),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isDone && !isCurrent
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: isCurrent || isDone
                                                ? Colors.white
                                                : textMuted,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _steps[i].title.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent
                                        ? AppColors.primary
                                        : textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (i < 2)
                                Container(
                                  width: 14,
                                  height: 1.5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  color: borderColor,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),

            // ── Active Step Viewfinder & Content Area ───────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Title & Instructions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            stepInfo.icon,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'STEP ${_currentStep + 1} OF 3',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (!stepInfo.isRequired) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Optional',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stepInfo.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stepInfo.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Viewfinder / Captured Image Display
                    InkWell(
                      onTap: _showImageSourceModal,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 260,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: currentImg != null
                                ? AppColors.primary
                                : borderColor,
                            width: currentImg != null ? 2 : 1.5,
                          ),
                          boxShadow: isDark ? [] : AppColors.subtleShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: currentImg != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(currentImg),
                                      fit: BoxFit.cover,
                                    ),
                                    // Retake overlay button
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.65,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.refresh_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Retake',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Verified capture banner
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        color: AppColors.primaryDark.withValues(
                                          alpha: 0.85,
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Image Captured Successfully',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Viewfinder reticle
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 34,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Tap to photograph packaging',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Opens camera viewfinder or gallery',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clinical Framing Hint Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF162032)
                            : const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF047857)
                              : const Color(0xFFCCFBF1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stepInfo.hint,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF5EEAD4)
                                    : const Color(0xFF0F766E),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Step Navigation Actions (Prev, Next, Finish) ────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: Icon(
                        _currentStep == 2
                            ? Icons.verified_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _currentStep == 2
                            ? 'Run MedScan OCR'
                            : (currentImg != null
                                  ? 'Next Step'
                                  : 'Capture & Continue'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
