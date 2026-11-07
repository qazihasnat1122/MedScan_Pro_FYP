import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/theme.dart';
import '../../models/medicine_model.dart';
import '../../models/batch_model.dart';
import '../../models/scan_event_model.dart';
import '../../models/verification_record_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/scan_providers.dart';
import '../../providers/verification_providers.dart';
import '../../repositories/medicine_lookup_repository.dart';
import '../../services/ocr_service.dart';
import '../../services/packaging_ocr_parser.dart';
import '../../services/prescription_ai_service.dart';
import '../../services/verification_engine.dart';
import '../../services/emergency_qr_payload_service.dart';
import '../emergency/widgets/emergency_profile_display_sheet.dart';

/// In-App Smart Medicine Scanner Screen
/// Uses the existing `mobile_scanner` package for both live barcode detection
/// and direct in-app frame capture (via RepaintBoundary over the camera Texture),
/// eliminating external camera switching and blank camera screens.
class SmartScannerScreen extends ConsumerStatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  ConsumerState<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends ConsumerState<SmartScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _cameraPreviewBoundaryKey = GlobalKey();

  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserPosition;

  bool _isTorchOn = false;
  bool _isProcessing = false;
  bool _isScanningSecondSide = false;
  String? _detectedBarcode;
  String? _capturedPreviewPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _laserPosition = Tween<double>(
      begin: 0.1,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _laserAnimCtrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isProcessing) {
          _scannerController.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _scannerController.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimCtrl.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) {
        setState(() => _isTorchOn = !_isTorchOn);
      }
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_detectedBarcode != null || _isProcessing) return;
    for (final barcode in capture.barcodes) {
      final val = barcode.rawValue;
      if (val != null && val.trim().isNotEmpty) {
        final cleanVal = val.trim();
        final emergencyResult =
            EmergencyQrPayloadService.decodePayload(cleanVal);
        if (emergencyResult.status == EmergencyQrDecodeStatus.success &&
            emergencyResult.data != null) {
          _isProcessing = true;
          HapticFeedback.heavyImpact();
          await EmergencyProfileDisplaySheet.show(
            context,
            emergencyResult.data!,
          );
          if (mounted) {
            setState(() => _isProcessing = false);
          }
          break;
        } else if (cleanVal.startsWith('MEDSCAN PRO EMERGENCY') ||
            cleanVal.contains('medscan_emergency')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emergencyResult.message),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _detectedBarcode = cleanVal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Barcode detected: ${val.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: MedScanTheme.primaryTeal,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      }
    }
  }

  /// Captures the current live camera preview frame directly in-app without
  /// launching the external phone camera app.
  Future<void> _captureInAppFrame({bool isSecondPhoto = false}) async {
    if (_isProcessing) return;
    try {
      HapticFeedback.lightImpact();
      final boundaryContext = _cameraPreviewBoundaryKey.currentContext;
      final renderObject = boundaryContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary &&
          _scannerController.value.isRunning) {
        final ui.Image image = await renderObject.toImage(pixelRatio: 2.5);
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image.dispose();

        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          final tempFile = File(
            '${Directory.systemTemp.path}/medscan_frame_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          if (mounted) {
            setState(() {
              _capturedPreviewPath = tempFile.path;
              _isScanningSecondSide = false;
            });
          }
          await _processSingleImage(
            tempFile.path,
            isSecondPhoto: isSecondPhoto,
          );
          return;
        }
      }

      // If live camera stream is not running (e.g. emulator without camera),
      // prompt user to pick from gallery or retry camera.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live camera stream is not ready. Please wait a moment or pick an image from Gallery.',
            ),
            backgroundColor: MedScanTheme.stateLimited,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture camera frame: $e'),
            backgroundColor: MedScanTheme.stateSuspicious,
          ),
        );
      }
    }
  }

  /// Picks an image from the device gallery while cleanly pausing/resuming the
  /// in-app camera controller so CameraX never shows a blank screen.
  Future<void> _pickFromGallery({bool isSecondPhoto = false}) async {
    if (_isProcessing) return;
    try {
      try {
        await _scannerController.stop();
      } catch (_) {}

      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      try {
        await _scannerController.start();
      } catch (_) {}

      if (file != null) {
        HapticFeedback.lightImpact();
        if (mounted) {
          setState(() {
            _capturedPreviewPath = file.path;
            _isScanningSecondSide = false;
          });
        }
        await _processSingleImage(file.path, isSecondPhoto: isSecondPhoto);
      }
    } catch (e) {
      try {
        await _scannerController.start();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load gallery photo: $e'),
            backgroundColor: MedScanTheme.stateSuspicious,
          ),
        );
      }
    }
  }

  String _cleanAiField(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim();
    final lower = s.toLowerCase();
    if (lower == 'null' ||
        lower == 'none' ||
        lower == 'unknown' ||
        lower == 'n/a' ||
        lower == 'not visible' ||
        lower == 'not detected') {
      return '';
    }
    return s;
  }

  Future<void> _processSingleImage(
    String imagePath, {
    bool isSecondPhoto = false,
  }) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final ocr = ref.read(ocrServiceProvider);
      final scanData = ref.read(scanStateProvider);

      if (!isSecondPhoto) {
        scanData.frontImagePath = imagePath;
      } else {
        scanData.backImagePath = imagePath;
      }

      // 0. Check for barcode inside the static image if none was detected live
      if (_detectedBarcode == null || _detectedBarcode!.isEmpty) {
        try {
          final BarcodeCapture? imgBarcode = await _scannerController
              .analyzeImage(imagePath)
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
          if (imgBarcode != null) {
            for (final b in imgBarcode.barcodes) {
              if (b.rawValue != null && b.rawValue!.trim().isNotEmpty) {
                final cleanVal = b.rawValue!.trim();
                final emergencyResult =
                    EmergencyQrPayloadService.decodePayload(cleanVal);
                if (emergencyResult.status == EmergencyQrDecodeStatus.success &&
                    emergencyResult.data != null) {
                  _isProcessing = true;
                  HapticFeedback.heavyImpact();
                  if (!mounted) return;
                  await EmergencyProfileDisplaySheet.show(
                    context,
                    emergencyResult.data!,
                  );
                  if (mounted) {
                    setState(() => _isProcessing = false);
                  }
                  return;
                }
                _detectedBarcode = cleanVal;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 1. Extract OCR text and bounding boxes using on-device ML Kit
      OcrRecognitionResult ocrRecognition = const OcrRecognitionResult(
        rawText: '',
        lines: [],
      );
      try {
        ocrRecognition = await ocr
            .recognizeImage(imagePath)
            .timeout(
              const Duration(seconds: 6),
              onTimeout: () =>
                  const OcrRecognitionResult(rawText: '', lines: []),
            );
      } catch (_) {
        ocrRecognition = const OcrRecognitionResult(rawText: '', lines: []);
      }

      final text = ocrRecognition.rawText;
      final parsed = PackagingOcrParser.parse(
        text,
        ocrLines: ocrRecognition.lines,
      );

      // 2. Smart AI Fallback/Enhancement only when on-device OCR missed key fields
      Map<String, dynamic> aiAttrs = const {};
      final needsAiBrain =
          (!isSecondPhoto &&
              parsed.medicineName.isEmpty &&
              parsed.genericSalt.isEmpty) ||
          (isSecondPhoto &&
              parsed.batchNumber.isEmpty &&
              parsed.expiryDate.isEmpty) ||
          text.trim().length < 12;

      if (needsAiBrain) {
        try {
          aiAttrs = await ref
              .read(prescriptionAiServiceProvider)
              .extractPackagingAttributesFromImage(imagePath)
              .timeout(const Duration(seconds: 18), onTimeout: () => const {});
        } catch (_) {
          aiAttrs = const {};
        }
      }

      final aiRawText = _cleanAiField(aiAttrs['rawText']);
      final combinedThisPhotoText = [
        if (text.trim().isNotEmpty) text.trim(),
        if (aiRawText.isNotEmpty) aiRawText,
      ].join('\n');

      final effectiveParsed = aiRawText.isNotEmpty
          ? PackagingOcrParser.parse(
              combinedThisPhotoText,
              ocrLines: ocrRecognition.lines,
            )
          : parsed;

      final rawAiBrand = _cleanAiField(aiAttrs['brandName']);
      final aiBrand = PackagingOcrParser.isUrlOrIrrelevantBrandToken(rawAiBrand)
          ? ''
          : rawAiBrand;
      final aiSalt = _cleanAiField(aiAttrs['genericSalt']);
      final aiStrength = _cleanAiField(aiAttrs['strength']);
      final aiForm = _cleanAiField(aiAttrs['dosageForm']);
      final aiMfg = _cleanAiField(aiAttrs['manufacturer']);
      final aiBatch = _cleanAiField(aiAttrs['batchNumber']);
      final aiExpiry = _cleanAiField(aiAttrs['expiryDate']);
      final aiMfgDate = _cleanAiField(aiAttrs['mfgDate']);
      final aiPrice = _cleanAiField(aiAttrs['price']);
      final aiReg = _cleanAiField(aiAttrs['registrationNumber']);
      final aiBarcode = _cleanAiField(aiAttrs['barcode']);

      final candidateBrand = effectiveParsed.brandName.isNotEmpty
          ? effectiveParsed.brandName
          : aiBrand;
      final candidateSalt = effectiveParsed.genericSalt.isNotEmpty
          ? effectiveParsed.genericSalt
          : aiSalt;
      final candidateStrength = effectiveParsed.strength.isNotEmpty
          ? effectiveParsed.strength
          : aiStrength;
      final candidateForm = effectiveParsed.dosageForm.isNotEmpty
          ? effectiveParsed.dosageForm
          : aiForm;
      final candidateMfg = effectiveParsed.manufacturer.isNotEmpty
          ? effectiveParsed.manufacturer
          : aiMfg;
      final candidateBatch = effectiveParsed.batchNumber.isNotEmpty
          ? effectiveParsed.batchNumber
          : aiBatch;
      final candidateExpiry = effectiveParsed.expiryDate.isNotEmpty
          ? effectiveParsed.expiryDate
          : aiExpiry;
      final candidateMfgDate = effectiveParsed.mfgDate.isNotEmpty
          ? effectiveParsed.mfgDate
          : aiMfgDate;
      final candidatePrice = effectiveParsed.price.isNotEmpty
          ? effectiveParsed.price
          : aiPrice;
      final candidateReg = effectiveParsed.registrationInfo.isNotEmpty
          ? effectiveParsed.registrationInfo
          : aiReg;

      String candidateName = effectiveParsed.medicineName.isNotEmpty
          ? effectiveParsed.medicineName
          : (candidateBrand.isNotEmpty
                ? (candidateStrength.isNotEmpty &&
                          !candidateBrand.toLowerCase().contains(
                            candidateStrength.toLowerCase(),
                          )
                      ? '$candidateBrand $candidateStrength'
                      : candidateBrand)
                : '');

      if (candidateName.isEmpty && candidateSalt.isNotEmpty) {
        candidateName = candidateStrength.isNotEmpty
            ? '$candidateSalt $candidateStrength'
            : candidateSalt;
      }

      if (isSecondPhoto) {
        // Merge 2nd photo into existing scanData without wiping 1st photo's medicine identity
        scanData.rawText = [
          if (scanData.rawText.trim().isNotEmpty) scanData.rawText.trim(),
          if (combinedThisPhotoText.isNotEmpty) combinedThisPhotoText,
        ].join('\n');
        if (scanData.extractedName.isEmpty && candidateName.isNotEmpty) {
          scanData.extractedName = candidateName;
        }
        if (scanData.extractedBrand.isEmpty && candidateBrand.isNotEmpty) {
          scanData.extractedBrand = candidateBrand;
        }
        if (scanData.extractedGenericSalt.isEmpty && candidateSalt.isNotEmpty) {
          scanData.extractedGenericSalt = candidateSalt;
        }
        if (scanData.extractedStrength.isEmpty &&
            candidateStrength.isNotEmpty) {
          scanData.extractedStrength = candidateStrength;
        }
        if (scanData.extractedDosageForm.isEmpty && candidateForm.isNotEmpty) {
          scanData.extractedDosageForm = candidateForm;
        }
        if (scanData.extractedManufacturer.isEmpty && candidateMfg.isNotEmpty) {
          scanData.extractedManufacturer = candidateMfg;
        }
        if (candidateBatch.isNotEmpty) {
          scanData.extractedBatch = candidateBatch;
        }
        if (candidateExpiry.isNotEmpty) {
          scanData.extractedExpiry = candidateExpiry;
        }
        if (candidateMfgDate.isNotEmpty) {
          scanData.extractedMfgDate = candidateMfgDate;
        }
        if (candidatePrice.isNotEmpty) {
          scanData.extractedPrice = candidatePrice;
        }
        if (candidateReg.isNotEmpty) {
          scanData.extractedRegistrationInfo = candidateReg;
        }
        if (effectiveParsed.specialNotice.isNotEmpty) {
          scanData.specialNotice = effectiveParsed.specialNotice;
        }
      } else {
        scanData.rawText = combinedThisPhotoText;
        scanData.extractedName = candidateName;
        scanData.extractedBrand = candidateBrand;
        scanData.extractedManufacturer = candidateMfg;
        scanData.extractedBatch = candidateBatch;
        scanData.extractedExpiry = candidateExpiry;
        scanData.extractedRegistrationInfo = candidateReg;
        scanData.extractedGenericSalt = candidateSalt;
        scanData.extractedStrength = candidateStrength;
        scanData.extractedPrice = candidatePrice;
        scanData.extractedMfgDate = candidateMfgDate;
        scanData.extractedDosageForm = candidateForm;
        scanData.specialNotice = effectiveParsed.specialNotice;
        scanData.structuredSummary = effectiveParsed.structuredSummary;
        scanData.candidateNames = effectiveParsed.brandCandidates;
        scanData.isAmbiguous = effectiveParsed.isAmbiguous;
      }

      if (_detectedBarcode != null && _detectedBarcode!.isNotEmpty) {
        scanData.extractedBarcode = _detectedBarcode!;
      } else if (effectiveParsed.barcode.isNotEmpty &&
          scanData.extractedBarcode.isEmpty) {
        scanData.extractedBarcode = effectiveParsed.barcode;
      } else if (aiBarcode.isNotEmpty && scanData.extractedBarcode.isEmpty) {
        scanData.extractedBarcode = aiBarcode;
      }

      scanData.fieldConfidences['name'] = scanData.extractedName.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;
      scanData.fieldConfidences['strength'] =
          scanData.extractedStrength.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;
      scanData.fieldConfidences['batch'] = scanData.extractedBatch.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;
      scanData.fieldConfidences['expiry'] = scanData.extractedExpiry.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;
      scanData.fieldConfidences['genericSalt'] =
          scanData.extractedGenericSalt.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;
      scanData.fieldConfidences['barcode'] =
          scanData.extractedBarcode.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium;

      setState(() => _isProcessing = false);

      if (mounted) {
        await _executeVerificationAndShowSheet(scanData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing error: $e'),
            backgroundColor: MedScanTheme.stateSuspicious,
          ),
        );
      }
    }
  }

  Future<void> _executeVerificationAndShowSheet(
    ScanData scanData, {
    MedicineModel? explicitlySelectedMedicine,
  }) async {
    final repo = ref.read(medicineLookupProvider);
    final engine = ref.read(verificationEngineProvider);

    List<MedicineModel> matchedMeds = [];
    List<MedicineModel> likelyCandidates = [];
    List<BatchModel> matchedBatches = [];
    int priorScans = 0;

    // 1. Rank candidates using exact brand, fuzzy brand, generic salt, and strength
    final rankedMatches = await repo.rankMedicineCandidates(
      scanData.extractedBrand.isNotEmpty
          ? scanData.extractedBrand
          : scanData.extractedName,
      genericSalt: scanData.extractedGenericSalt,
      strength: scanData.extractedStrength,
      extraCandidates: scanData.candidateNames,
    );

    likelyCandidates = rankedMatches.map((m) => m.medicine).toList();

    if (explicitlySelectedMedicine != null) {
      matchedMeds = [explicitlySelectedMedicine];
      scanData.isAmbiguous = false;
    } else if (rankedMatches.isNotEmpty) {
      matchedMeds = [rankedMatches.first.medicine];
      // Check if top two database candidates are tied/ambiguous (e.g. only salt matched multiple brands)
      if (rankedMatches.length >= 2 &&
          (rankedMatches[0].score - rankedMatches[1].score).abs() < 15.0 &&
          scanData.extractedBrand.isEmpty) {
        scanData.isAmbiguous = true;
      }
      // Populate candidate names for confirmation picker
      for (final rm in rankedMatches) {
        if (!scanData.candidateNames.contains(rm.medicine.medicineName)) {
          scanData.candidateNames = [
            ...scanData.candidateNames,
            rm.medicine.medicineName,
          ];
        }
      }
    }

    // 2. Fallback: search by DRAP Registration Number
    if (matchedMeds.isEmpty && scanData.extractedRegistrationInfo.isNotEmpty) {
      matchedMeds = await repo.searchMedicines(
        scanData.extractedRegistrationInfo,
      );
    }

    // 3. Fallback: search by Barcode / GTIN
    if (matchedMeds.isEmpty && scanData.extractedBarcode.isNotEmpty) {
      matchedMeds = await repo.searchMedicines(scanData.extractedBarcode);
    }

    // 4. Search batches for the identified medicine
    if (matchedMeds.isNotEmpty && scanData.extractedBatch.isNotEmpty) {
      matchedBatches = await repo.searchBatches(
        matchedMeds.first.medicineId,
        scanData.extractedBatch,
      );
    }

    final verifService = ref.read(verificationServiceProvider);
    if (scanData.extractedBarcode.isNotEmpty) {
      priorScans = await verifService.getIdentifierScanCount(
        scanData.extractedBarcode,
      );
    } else if (scanData.extractedBatch.isNotEmpty) {
      priorScans = await verifService.getIdentifierScanCount(
        scanData.extractedBatch,
      );
    }

    final result = engine.verify(
      scanData: scanData,
      matchedMedicines: matchedMeds,
      matchedBatches: matchedBatches,
      previousScanCount: priorScans,
    );

    // Log verification telemetry
    try {
      final user = ref.read(authStateProvider).value;
      final scanEvent = ScanEventModel(
        eventId: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.uid ?? 'anonymous_scanner',
        identifier: scanData.extractedBarcode.isNotEmpty
            ? scanData.extractedBarcode
            : scanData.extractedBatch,
        medicineId: matchedMeds.isNotEmpty
            ? matchedMeds.first.medicineId
            : 'unknown_med',
        medicineName: scanData.extractedName.isNotEmpty
            ? scanData.extractedName
            : (matchedMeds.isNotEmpty
                  ? matchedMeds.first.medicineName
                  : 'Unidentified Medicine'),
        manufacturerId: matchedMeds.isNotEmpty
            ? matchedMeds.first.manufacturerId
            : scanData.extractedManufacturer,
        batchNumber: scanData.extractedBatch,
        timestamp: DateTime.now(),
        resultCode: result.riskLevel,
        verificationResult: result.stateLabel,
        approximateLocation: 'Pakistan Mobile Device',
        reasons: result.reasons,
      );
      await ref.read(verificationServiceProvider).logScanEvent(scanEvent);

      final record = VerificationRecordModel(
        id: 'REC-${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.uid ?? 'anonymous_scanner',
        medicineName: scanData.extractedName.isNotEmpty
            ? scanData.extractedName
            : (matchedMeds.isNotEmpty
                  ? matchedMeds.first.medicineName
                  : 'Unidentified Medicine'),
        riskLevel: result.riskLevel,
        verifiedAt: DateTime.now(),
      );
      await ref.read(verificationServiceProvider).logVerificationRecord(record);
    } catch (_) {}

    if (!mounted) return;

    _showVerificationBottomSheet(
      result,
      scanData,
      priorScans,
      matchedMedicine: matchedMeds.isNotEmpty ? matchedMeds.first : null,
      candidateMedicines: likelyCandidates.isNotEmpty
          ? likelyCandidates
          : MedicineLookupRepository.staticReferenceMedicines,
    );
  }

  void _showVerificationBottomSheet(
    VerificationResult result,
    ScanData scanData,
    int priorScans, {
    MedicineModel? matchedMedicine,
    required List<MedicineModel> candidateMedicines,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VerificationBottomSheet(
          result: result,
          scanData: scanData,
          priorScans: priorScans,
          matchedMedicine: matchedMedicine,
          candidateMedicines: candidateMedicines,
          onRetake: () {
            Navigator.pop(ctx);
            ref.read(scanStateProvider.notifier).reset();
            setState(() {
              _detectedBarcode = null;
              _capturedPreviewPath = null;
              _isScanningSecondSide = false;
            });
          },
          onScanSecondSideInApp: () {
            Navigator.pop(ctx);
            setState(() {
              _isScanningSecondSide = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Flip the medicine pack to show Batch No. & Expiry Date, then tap the shutter button.',
                ),
                backgroundColor: MedScanTheme.primaryTeal,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          },
          onPickSecondSideGallery: () {
            Navigator.pop(ctx);
            _pickFromGallery(isSecondPhoto: true);
          },
          onSelectMedicineCandidate: (selectedMed) {
            Navigator.pop(ctx);
            scanData.extractedBrand = selectedMed.medicineName
                .replaceAll(
                  RegExp(
                    r'\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%)\b',
                    caseSensitive: false,
                  ),
                  '',
                )
                .trim();
            scanData.extractedName = selectedMed.medicineName;
            if (scanData.extractedGenericSalt.isEmpty) {
              scanData.extractedGenericSalt = selectedMed.genericName;
            }
            if (scanData.extractedStrength.isEmpty) {
              scanData.extractedStrength = selectedMed.strength;
            }
            if (scanData.extractedManufacturer.isEmpty) {
              scanData.extractedManufacturer = selectedMed.companyName;
            }
            scanData.isAmbiguous = false;
            scanData.fieldConfidences['name'] = FieldConfidence.high;
            scanData.fieldConfirmedByUser['name'] = true;
            _executeVerificationAndShowSheet(
              scanData,
              explicitlySelectedMedicine: selectedMed,
            );
          },
          onManualUpdateAndVerify: (medName, batchNo, expiryDate) {
            Navigator.pop(ctx);
            if (medName.trim().isNotEmpty) {
              scanData.extractedName = medName.trim();
              scanData.extractedBrand = medName
                  .trim()
                  .replaceAll(
                    RegExp(
                      r'\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%)\b',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .trim();
              scanData.isAmbiguous = false;
              scanData.fieldConfidences['name'] = FieldConfidence.high;
              scanData.fieldConfirmedByUser['name'] = true;
            }
            if (batchNo.trim().isNotEmpty) {
              scanData.extractedBatch = batchNo.trim();
              scanData.fieldConfidences['batch'] = FieldConfidence.high;
              scanData.fieldConfirmedByUser['batch'] = true;
            }
            if (expiryDate.trim().isNotEmpty) {
              scanData.extractedExpiry = expiryDate.trim();
              scanData.fieldConfidences['expiry'] = FieldConfidence.high;
              scanData.fieldConfirmedByUser['expiry'] = true;
            }
            _executeVerificationAndShowSheet(scanData);
          },
        );
      },
    );
  }

  void _runQuickSampleScan() {
    final scanData = ref.read(scanStateProvider);
    scanData.extractedBrand = 'Disprin';
    scanData.extractedName = 'Disprin 300mg';
    scanData.extractedManufacturer = 'Reckitt Benckiser Pakistan';
    scanData.extractedBatch = '';
    scanData.extractedExpiry = '12/2027';
    scanData.extractedBarcode = '';
    scanData.extractedGenericSalt = 'Aspirin B.P.';
    scanData.extractedStrength = '300mg';
    scanData.extractedDosageForm = 'Tablet';
    scanData.isAmbiguous = false;
    scanData.fieldConfidences['name'] = FieldConfidence.high;
    scanData.fieldConfidences['strength'] = FieldConfidence.high;
    scanData.fieldConfidences['batch'] = FieldConfidence.medium;
    scanData.fieldConfidences['expiry'] = FieldConfidence.high;
    scanData.fieldConfidences['genericSalt'] = FieldConfidence.high;
    scanData.fieldConfidences['barcode'] = FieldConfidence.medium;
    _executeVerificationAndShowSheet(scanData);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameWidth = size.width * 0.82;
    final frameHeight = size.height * 0.42;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Full-Bleed In-App Live Viewfinder (Wrapped in RepaintBoundary) ──
          Positioned.fill(
            child: RepaintBoundary(
              key: _cameraPreviewBoundaryKey,
              child: MobileScanner(
                controller: _scannerController,
                tapToFocus: true,
                onDetect: _onBarcodeDetected,
                placeholderBuilder: (context) {
                  return Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: MedScanTheme.accentTeal,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Starting In-App Camera...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap anywhere on preview to focus',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error) {
                  return Container(
                    color: MedScanTheme.background,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_off_rounded,
                              size: 48,
                              color: MedScanTheme.stateLimited,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera Unavailable',
                              style: MedScanTheme.heading2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Camera permission or hardware is unavailable (${error.errorCode.name}). You can retry the camera or pick a package photo from your gallery.',
                              textAlign: TextAlign.center,
                              style: MedScanTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry Camera'),
                                  onPressed: () => _scannerController.start(),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MedScanTheme.primaryTeal,
                                  ),
                                  icon: const Icon(Icons.photo_library_rounded),
                                  label: const Text('Pick from Gallery'),
                                  onPressed: () => _pickFromGallery(
                                    isSecondPhoto: _isScanningSecondSide,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 2. Darkened Guideline Mask & Target Frame ─────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GuidelineFramePainter(
                  frameWidth: frameWidth,
                  frameHeight: frameHeight,
                  borderColor: _isScanningSecondSide
                      ? const Color(0xFFF59E0B)
                      : (_detectedBarcode != null
                            ? MedScanTheme.accentTeal
                            : Colors.white),
                ),
              ),
            ),
          ),

          // ── 3. Animated Laser Line ────────────────────────────────────────
          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: frameWidth - 16,
                height: frameHeight - 16,
                child: AnimatedBuilder(
                  animation: _laserPosition,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(0, (_laserPosition.value * 2) - 1),
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              MedScanTheme.accentTeal.withValues(alpha: 0.0),
                              MedScanTheme.accentTeal,
                              MedScanTheme.accentTeal.withValues(alpha: 0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MedScanTheme.accentTeal.withValues(
                                alpha: 0.6,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── 4. Top Header & Action Controls ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isScanningSecondSide
                              ? Icons.flip_camera_ios_rounded
                              : (_detectedBarcode != null
                                    ? Icons.verified_rounded
                                    : Icons.crop_free_rounded),
                          size: 14,
                          color: _isScanningSecondSide
                              ? const Color(0xFFF59E0B)
                              : (_detectedBarcode != null
                                    ? MedScanTheme.accentTeal
                                    : Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isScanningSecondSide
                              ? 'SCAN BACK / BATCH SIDE'
                              : (_detectedBarcode != null
                                    ? 'BARCODE LOCKED'
                                    : 'VERIFY MEDICINE SCAN'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        child: IconButton(
                          tooltip: 'Toggle Flash',
                          icon: Icon(
                            _isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _isTorchOn ? Colors.amber : Colors.white,
                          ),
                          onPressed: _toggleTorch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        child: IconButton(
                          icon: const Icon(
                            Icons.science_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Quick Test Sample',
                          onPressed: _runQuickSampleScan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 5. Guidance Micro-Copy ────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            top: (size.height / 2) + (frameHeight / 2) + 16,
            child: Column(
              children: [
                Text(
                  _isScanningSecondSide
                      ? 'Point at Back / Side Flap showing Batch No. & Expiry Date'
                      : (_detectedBarcode != null
                            ? 'Barcode read ($_detectedBarcode)! Tap shutter to scan package text'
                            : 'Align medicine package inside frame & tap shutter'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap preview to focus • Extracts Brand, Salt, Strength, Batch & Expiry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),

          // ── 6. Processing Overlay ──────────────────────────────────────────
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: MedScanTheme.accentTeal,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isScanningSecondSide
                              ? 'Reading Batch & Expiry Date...'
                              : 'Analyzing Medicine Package...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Matching against reference database',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 7. Bottom Capture Deck ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 20,
                bottom: 32,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Picker Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () => _pickFromGallery(
                                  isSecondPhoto: _isScanningSecondSide,
                                ),
                        ),
                        const Text(
                          'Gallery',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),

                    // Central In-App Shutter Button
                    GestureDetector(
                      onTap: _isProcessing
                          ? null
                          : () => _captureInAppFrame(
                              isSecondPhoto: _isScanningSecondSide,
                            ),
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isScanningSecondSide
                                ? const Color(0xFFF59E0B)
                                : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isProcessing
                                ? Colors.grey
                                : (_isScanningSecondSide
                                      ? const Color(0xFFD97706)
                                      : MedScanTheme.primaryTeal),
                            shape: BoxShape.circle,
                          ),
                          child: _isProcessing
                              ? const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                        ),
                      ),
                    ),

                    // Retake / Reset or Flip Camera Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            (_capturedPreviewPath != null ||
                                    _detectedBarcode != null ||
                                    _isScanningSecondSide)
                                ? Icons.refresh_rounded
                                : Icons.flip_camera_android_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  if (_capturedPreviewPath != null ||
                                      _detectedBarcode != null ||
                                      _isScanningSecondSide) {
                                    ref
                                        .read(scanStateProvider.notifier)
                                        .reset();
                                    setState(() {
                                      _capturedPreviewPath = null;
                                      _detectedBarcode = null;
                                      _isScanningSecondSide = false;
                                    });
                                  } else {
                                    _scannerController.switchCamera();
                                  }
                                },
                        ),
                        Text(
                          (_capturedPreviewPath != null ||
                                  _detectedBarcode != null ||
                                  _isScanningSecondSide)
                              ? 'Retake'
                              : 'Flip',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for camera guideline frame and darkened surrounding overlay.
class _GuidelineFramePainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final Color borderColor;

  _GuidelineFramePainter({
    required this.frameWidth,
    required this.frameHeight,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );

    // Darkened Mask Outside Frame
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Frame Border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(20)),
      borderPaint,
    );

    // Corner Accents
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const r = 20.0;

    // Top-Left
    canvas.drawLine(
      Offset(frameRect.left, frameRect.top + r),
      Offset(frameRect.left, frameRect.top + r + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.left + r, frameRect.top),
      Offset(frameRect.left + r + cornerLength, frameRect.top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(frameRect.right, frameRect.top + r),
      Offset(frameRect.right, frameRect.top + r + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.right - r, frameRect.top),
      Offset(frameRect.right - r - cornerLength, frameRect.top),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(frameRect.left, frameRect.bottom - r),
      Offset(frameRect.left, frameRect.bottom - r - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.left + r, frameRect.bottom),
      Offset(frameRect.left + r + cornerLength, frameRect.bottom),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(frameRect.right, frameRect.bottom - r),
      Offset(frameRect.right, frameRect.bottom - r - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.right - r, frameRect.bottom),
      Offset(frameRect.right - r - cornerLength, frameRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidelineFramePainter oldDelegate) {
    return oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.borderColor != borderColor;
  }
}

/// Simple, structured Results Bottom Sheet displaying:
/// - Likely Brand Name prominently
/// - Generic Salt, Strength, Batch, Expiry (with validation), Barcode, Manufacturer, and Verification Status
/// - Clear "Not detected" labels for missing fields
/// - "Retake Scan", "Select Correct Medicine", and "Scan Back/Side for Batch & Expiry" actions
class _VerificationBottomSheet extends ConsumerStatefulWidget {
  final VerificationResult result;
  final ScanData scanData;
  final int priorScans;
  final MedicineModel? matchedMedicine;
  final List<MedicineModel> candidateMedicines;
  final VoidCallback onRetake;
  final VoidCallback onScanSecondSideInApp;
  final VoidCallback onPickSecondSideGallery;
  final void Function(MedicineModel selectedMedicine) onSelectMedicineCandidate;
  final void Function(
    String medicineName,
    String batchNumber,
    String expiryDate,
  )
  onManualUpdateAndVerify;

  const _VerificationBottomSheet({
    required this.result,
    required this.scanData,
    required this.priorScans,
    this.matchedMedicine,
    required this.candidateMedicines,
    required this.onRetake,
    required this.onScanSecondSideInApp,
    required this.onPickSecondSideGallery,
    required this.onSelectMedicineCandidate,
    required this.onManualUpdateAndVerify,
  });

  @override
  ConsumerState<_VerificationBottomSheet> createState() =>
      _VerificationBottomSheetState();
}

class _VerificationBottomSheetState
    extends ConsumerState<_VerificationBottomSheet> {
  bool _isReporting = false;
  bool _reportSubmitted = false;
  bool _showManualBatchInputs = false;
  bool _showMedicineSelector = false;

  late final TextEditingController _nameInputCtrl;
  late final TextEditingController _batchInputCtrl;
  late final TextEditingController _expiryInputCtrl;

  @override
  void initState() {
    super.initState();
    _nameInputCtrl = TextEditingController(text: widget.scanData.extractedName);
    _batchInputCtrl = TextEditingController(
      text: widget.scanData.extractedBatch,
    );
    _expiryInputCtrl = TextEditingController(
      text: widget.scanData.extractedExpiry,
    );
    if (widget.scanData.isAmbiguous || widget.scanData.extractedName.isEmpty) {
      _showMedicineSelector = true;
    }
  }

  @override
  void dispose() {
    _nameInputCtrl.dispose();
    _batchInputCtrl.dispose();
    _expiryInputCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String verificationStatus, VerificationState state) {
    if (verificationStatus == 'Mismatch detected' ||
        state == VerificationState.suspiciousDetected) {
      return MedScanTheme.stateSuspicious;
    }
    if (verificationStatus == 'Reference matched') {
      return state == VerificationState.manufacturerSupported
          ? MedScanTheme.stateVerified
          : MedScanTheme.stateReference;
    }
    return MedScanTheme.stateLimited;
  }

  IconData _getStatusIcon(String verificationStatus, VerificationState state) {
    if (verificationStatus == 'Mismatch detected' ||
        state == VerificationState.suspiciousDetected) {
      return Icons.warning_amber_rounded;
    }
    if (verificationStatus == 'Reference matched') {
      return Icons.verified_rounded;
    }
    return Icons.help_outline_rounded;
  }

  Future<void> _submitReport() async {
    setState(() => _isReporting = true);
    try {
      final user = ref.read(authStateProvider).value;
      final identifier = widget.scanData.extractedBarcode.isNotEmpty
          ? widget.scanData.extractedBarcode
          : (widget.scanData.extractedBatch.isNotEmpty
                ? widget.scanData.extractedBatch
                : 'UNKNOWN');
      await ref
          .read(verificationServiceProvider)
          .submitSuspiciousReport(
            identifier: identifier,
            medicineName: widget.scanData.extractedName.isNotEmpty
                ? widget.scanData.extractedName
                : 'Unidentified Medicine',
            batchNumber: widget.scanData.extractedBatch.isNotEmpty
                ? widget.scanData.extractedBatch
                : 'NOT_DETECTED',
            resultCode: widget.result.state.code,
            userId: user?.uid ?? 'anonymous_reporter',
            notes:
                'Submitted via 1-tap verification report (${widget.result.verificationStatus})',
          );
      if (mounted) {
        setState(() {
          _isReporting = false;
          _reportSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted to DRAP & manufacturer safety registry.',
            ),
            backgroundColor: MedScanTheme.stateVerified,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: MedScanTheme.stateSuspicious,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(
      widget.result.verificationStatus,
      widget.result.state,
    );
    final statusIcon = _getStatusIcon(
      widget.result.verificationStatus,
      widget.result.state,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batchMissing = widget.scanData.extractedBatch.trim().isEmpty;
    final expiryMissing = widget.scanData.extractedExpiry.trim().isEmpty;
    final matchedMed = widget.matchedMedicine;

    final prominentBrand = widget.scanData.extractedBrand.isNotEmpty
        ? widget.scanData.extractedBrand
        : (widget.scanData.extractedName.isNotEmpty
              ? widget.scanData.extractedName
              : (matchedMed != null
                    ? matchedMed.medicineName
                    : 'Not detected'));

    final expiryValidation = PackagingOcrParser.validateExpiryDate(
      widget.scanData.extractedExpiry,
    );

    final displayPrice = widget.scanData.extractedPrice.isNotEmpty
        ? widget.scanData.extractedPrice
        : (matchedMed != null && matchedMed.referencePrice > 0
              ? matchedMed.referencePrice.toStringAsFixed(2)
              : '');

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? MedScanTheme.surfaceCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: MedScanTheme.cardShadow,
          ),
          child: Column(
            children: [
              // Pull Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── 1. Prominent Brand Header & Quick Actions ────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MedScanTheme.surface
                            : const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MedScanTheme.primaryTeal.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: MedScanTheme.primaryTeal.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.medication_rounded,
                                  color: MedScanTheme.primaryTeal,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LIKELY BRAND NAME',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                        color: MedScanTheme.primaryTeal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      prominentBrand,
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: prominentBrand == 'Not detected'
                                            ? const Color(0xFFD97706)
                                            : (isDark
                                                  ? MedScanTheme.textPrimary
                                                  : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    if (matchedMed != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Reference: ${matchedMed.medicineName} • ${matchedMed.genericName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? MedScanTheme.textSecondary
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MedScanTheme.primaryTeal,
                                    side: const BorderSide(
                                      color: MedScanTheme.primaryTeal,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Select Correct Medicine',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showMedicineSelector =
                                          !_showMedicineSelector;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Retake Scan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: widget.onRetake,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 1b. Candidate Medicine Picker (when ambiguous or user taps Select Correct Medicine) ──
                    if (_showMedicineSelector) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? MedScanTheme.surface
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: MedScanTheme.primaryTeal.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.list_alt_rounded,
                                  size: 18,
                                  color: MedScanTheme.primaryTeal,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.scanData.isAmbiguous
                                        ? 'Ambiguous Scan — Confirm Likely Medicine:'
                                        : 'Select Correct Medicine from Reference Catalog:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: MedScanTheme.primaryTeal,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(
                                    () => _showMedicineSelector = false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.candidateMedicines
                                  .take(8)
                                  .map(
                                    (med) => ActionChip(
                                      avatar: const Icon(
                                        Icons.medication_outlined,
                                        size: 15,
                                        color: MedScanTheme.primaryTeal,
                                      ),
                                      label: Text(
                                        '${med.medicineName} (${med.genericName})',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: () =>
                                          widget.onSelectMedicineCandidate(med),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── 2. Verification Status Card ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.result.verificationStatus,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                    Text(
                                      widget.result.state.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (widget.result.matchedFields.isNotEmpty) ...[
                            Text(
                              '✓ Matched Fields: ${widget.result.matchedFields.join(" • ")}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (widget.result.mismatchedFields.isNotEmpty) ...[
                            Text(
                              '⚠ Conflicts: ${widget.result.mismatchedFields.join(" • ")}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          ...widget.result.reasons.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '• $r',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: isDark
                                      ? MedScanTheme.textSecondary
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 3. Extracted Package Details Table ───────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MedScanTheme.surface
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? MedScanTheme.borderSubtle
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Extracted Package Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: MedScanTheme.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            label: 'Brand Name',
                            value: prominentBrand,
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Generic / Salt',
                            value:
                                widget.scanData.extractedGenericSalt.isNotEmpty
                                ? widget.scanData.extractedGenericSalt
                                : 'Not detected',
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Strength',
                            value: widget.scanData.extractedStrength.isNotEmpty
                                ? widget.scanData.extractedStrength
                                : 'Not detected',
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Batch / LOT No.',
                            value: widget.scanData.extractedBatch.isNotEmpty
                                ? widget.scanData.extractedBatch
                                : 'Not detected',
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Expiry Date',
                            value: widget.scanData.extractedExpiry.isNotEmpty
                                ? '${widget.scanData.extractedExpiry} (${expiryValidation.message})'
                                : 'Not detected',
                            isDark: isDark,
                            isAlert: expiryValidation.isExpired == true,
                          ),
                          _buildDetailRow(
                            label: 'Barcode',
                            value: widget.scanData.extractedBarcode.isNotEmpty
                                ? widget.scanData.extractedBarcode
                                : 'Not detected',
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Manufacturer',
                            value:
                                widget.scanData.extractedManufacturer.isNotEmpty
                                ? widget.scanData.extractedManufacturer
                                : 'Not detected',
                            isDark: isDark,
                          ),
                          _buildDetailRow(
                            label: 'Verification Status',
                            value: widget.result.verificationStatus,
                            isDark: isDark,
                            isAlert:
                                widget.result.verificationStatus ==
                                'Mismatch detected',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 4. Second Photo of Back/Side when Batch or Expiry Missing ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MedScanTheme.surface
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.flip_camera_ios_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (batchMissing || expiryMissing)
                                      ? 'Batch or Expiry Not Visible on Front?'
                                      : 'Scan Back/Side or Edit Fields',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _showManualBatchInputs =
                                      !_showManualBatchInputs,
                                ),
                                child: Text(
                                  _showManualBatchInputs
                                      ? 'Hide Editor'
                                      : 'Edit Manually',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Take a 2nd photo of the back or side flap of the package where Batch/LOT and Expiry are stamped:',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark
                                  ? MedScanTheme.textSecondary
                                  : const Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Scan Back/Side',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: widget.onScanSecondSideInApp,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB45309),
                                    side: const BorderSide(
                                      color: Color(0xFFD97706),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Back Photo (Gallery)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: widget.onPickSecondSideGallery,
                                ),
                              ),
                            ],
                          ),
                          if (_showManualBatchInputs) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameInputCtrl,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Medicine / Brand Name',
                                hintText: 'e.g. Disprin 300mg, Panadol 500mg',
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.medication_outlined,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? MedScanTheme.surfaceCard
                                    : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _batchInputCtrl,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Batch / LOT No.',
                                      hintText: 'e.g. B1024 or 21787',
                                      isDense: true,
                                      prefixIcon: const Icon(
                                        Icons.tag_rounded,
                                        size: 18,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? MedScanTheme.surfaceCard
                                          : Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _expiryInputCtrl,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Expiry Date',
                                      hintText: 'e.g. 12/2027',
                                      isDense: true,
                                      prefixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? MedScanTheme.surfaceCard
                                          : Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MedScanTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Update & Re-Verify',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => widget.onManualUpdateAndVerify(
                                  _nameInputCtrl.text,
                                  _batchInputCtrl.text,
                                  _expiryInputCtrl.text,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 5. 1-Tap Suspicious Report Button ────────────────────
                    if (widget.result.state ==
                            VerificationState.suspiciousDetected ||
                        widget.result.state ==
                            VerificationState.noReferenceFound) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: MedScanTheme.stateSuspicious.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: MedScanTheme.stateSuspicious.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Report Questionable Medicine to Authorities',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: MedScanTheme.stateSuspicious,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submit this scan’s details to DRAP Market Surveillance.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? MedScanTheme.textSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _reportSubmitted
                                      ? MedScanTheme.stateVerified
                                      : MedScanTheme.stateSuspicious,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: _isReporting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _reportSubmitted
                                            ? Icons.check_circle_rounded
                                            : Icons.report_problem_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  _reportSubmitted
                                      ? 'Report Lodged Successfully'
                                      : '1-Tap Report to DRAP',
                                ),
                                onPressed: (_isReporting || _reportSubmitted)
                                    ? null
                                    : _submitReport,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── 6. Bottom Action CTAs ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retake Scan'),
                            onPressed: widget.onRetake,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MedScanTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.price_check_rounded,
                              size: 18,
                            ),
                            label: const Text('Check Price'),
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(
                                '/price-check',
                                extra: {
                                  'medicineName':
                                      widget.scanData.extractedName.isNotEmpty
                                      ? widget.scanData.extractedName
                                      : prominentBrand,
                                  'referencePrice': double.tryParse(
                                    displayPrice.replaceAll(
                                      RegExp(r'[^0-9.]'),
                                      '',
                                    ),
                                  ),
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool isDark,
    bool isAlert = false,
  }) {
    final isNotDetected = value == 'Not detected';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? MedScanTheme.textMuted
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isAlert
                    ? const Color(0xFFDC2626)
                    : (isNotDetected
                          ? const Color(0xFFD97706)
                          : (isDark
                                ? MedScanTheme.textPrimary
                                : const Color(0xFF0F172A))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
