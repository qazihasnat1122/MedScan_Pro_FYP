import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ocr_service.dart';
import '../repositories/medicine_lookup_repository.dart';

final ocrServiceProvider = Provider((ref) => OcrService());
final medicineLookupProvider = Provider((ref) => MedicineLookupRepository());

/// Confidence level for a single extracted OCR field.
enum FieldConfidence { low, medium, high }

extension FieldConfidenceExt on FieldConfidence {
  String get label {
    switch (this) {
      case FieldConfidence.low:
        return 'LOW';
      case FieldConfidence.medium:
        return 'MED';
      case FieldConfidence.high:
        return 'HIGH';
    }
  }

  /// Below this threshold, the field must be confirmed by the user before
  /// proceeding, and it must not feed into MANUFACTURER_SUPPORTED or
  /// REFERENCE_AVAILABLE results without explicit user confirmation.
  bool get requiresUserConfirmation => this == FieldConfidence.low;
}

class ScanData {
  String? frontImagePath;
  String? backImagePath;
  String? sideImagePath;

  String extractedName = '';
  String extractedBrand = '';
  String extractedManufacturer = '';
  String extractedBatch = '';
  String extractedExpiry = '';
  String extractedRegistrationInfo = '';
  String extractedBarcode = '';
  String rawText = '';

  // Cleaned and structured domain fields
  String extractedGenericSalt = '';
  String extractedStrength = '';
  String extractedPrice = '';
  String extractedMfgDate = '';
  String extractedDosageForm = '';
  String specialNotice = '';
  String structuredSummary = '';
  List<String> candidateNames = [];
  bool isAmbiguous = false;

  /// Per-field OCR confidence scores (Gap 1).
  /// Keys match the field names: 'name', 'manufacturer', 'batch', 'expiry',
  /// 'barcode', 'genericSalt', 'strength'.
  Map<String, FieldConfidence> fieldConfidences = {};

  /// Whether the user has explicitly confirmed a low-confidence field (Gap 1).
  /// Keys are field names; value = true once the user tapped to confirm.
  Map<String, bool> fieldConfirmedByUser = {};

  /// Tracks whether the batch/expiry missing prompt has already been shown
  /// so we don't repeat it on retake (Gap 1).
  bool batchExpiryMissingPromptShown = false;

  /// Returns true if all critical fields either have sufficient confidence
  /// or have been explicitly confirmed by the user (Gap 1).
  bool get criticalFieldsConfirmed {
    const critical = ['batch', 'expiry'];
    for (final f in critical) {
      final conf = fieldConfidences[f] ?? FieldConfidence.high;
      if (conf.requiresUserConfirmation &&
          !(fieldConfirmedByUser[f] ?? false)) {
        return false;
      }
    }
    return true;
  }

  /// True when both batch AND expiry are absent/empty, triggering the
  /// "add one more photo" prompt (Gap 1).
  bool get batchAndExpiryBothMissing =>
      extractedBatch.isEmpty && extractedExpiry.isEmpty;
}

class ScanDataNotifier extends Notifier<ScanData> {
  @override
  ScanData build() {
    return ScanData();
  }

  /// Clears all scan data — call at the start of each new scan session.
  void reset() => state = ScanData();
}

final scanStateProvider = NotifierProvider<ScanDataNotifier, ScanData>(() {
  return ScanDataNotifier();
});
