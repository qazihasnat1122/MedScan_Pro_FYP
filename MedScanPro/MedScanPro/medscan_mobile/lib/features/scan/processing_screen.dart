import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';
import '../../services/ocr_service.dart';
import '../../services/packaging_ocr_parser.dart';

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
      final allOcrLines = <OcrTextLine>[];
      if (scanData.frontImagePath != null) {
        try {
          final res = await ocr
              .recognizeImage(scanData.frontImagePath!)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    const OcrRecognitionResult(rawText: '', lines: []),
              );
          if (res.rawText.trim().isNotEmpty) {
            combinedText += '${res.rawText}\n';
            allOcrLines.addAll(res.lines);
          }
        } catch (_) {}
      }
      if (scanData.backImagePath != null) {
        try {
          final res = await ocr
              .recognizeImage(scanData.backImagePath!)
              .timeout(
                const Duration(seconds: 4),
                onTimeout: () =>
                    const OcrRecognitionResult(rawText: '', lines: []),
              );
          if (res.rawText.trim().isNotEmpty) {
            combinedText += '${res.rawText}\n';
            allOcrLines.addAll(res.lines);
          }
        } catch (_) {}
      }
      if (scanData.sideImagePath != null) {
        try {
          final res = await ocr
              .recognizeImage(scanData.sideImagePath!)
              .timeout(
                const Duration(seconds: 4),
                onTimeout: () =>
                    const OcrRecognitionResult(rawText: '', lines: []),
              );
          if (res.rawText.trim().isNotEmpty) {
            combinedText += '${res.rawText}\n';
            allOcrLines.addAll(res.lines);
          }
        } catch (_) {}
      }

      scanData.rawText = combinedText;

      // Intelligent Pharmaceutical Packaging Parser (never fabricates values)
      final parsed = PackagingOcrParser.parse(
        combinedText,
        ocrLines: allOcrLines,
      );
      scanData.extractedName = parsed.medicineName;
      scanData.extractedBrand = parsed.brandName;
      scanData.extractedManufacturer = parsed.manufacturer;
      scanData.extractedBatch = parsed.batchNumber;
      scanData.extractedExpiry = parsed.expiryDate;
      if (parsed.barcode.isNotEmpty && scanData.extractedBarcode.isEmpty) {
        scanData.extractedBarcode = parsed.barcode;
      }
      scanData.extractedRegistrationInfo = parsed.registrationInfo;
      scanData.extractedGenericSalt = parsed.genericSalt;
      scanData.extractedStrength = parsed.strength;
      scanData.extractedPrice = parsed.price;
      scanData.extractedMfgDate = parsed.mfgDate;
      scanData.extractedDosageForm = parsed.dosageForm;
      scanData.specialNotice = parsed.specialNotice;
      scanData.structuredSummary = parsed.structuredSummary;
      scanData.candidateNames = parsed.brandCandidates;
      scanData.isAmbiguous = parsed.isAmbiguous;

      if (mounted) {
        context.pushReplacement('/scan/confirm');
      }
    } catch (e) {
      if (mounted) {
        context.pushReplacement('/scan/confirm');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF087F8C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: primaryTeal),
              SizedBox(height: 24),
              Text(
                'Reading Medicine Packaging...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Extracting medicine name, batch number, and expiration details with on-device OCR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
