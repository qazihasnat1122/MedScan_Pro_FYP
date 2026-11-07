import '../providers/scan_providers.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';
import '../repositories/medicine_lookup_repository.dart';
import 'packaging_ocr_parser.dart';

enum VerificationState {
  manufacturerSupported,
  referenceAvailable,
  limitedVerification,
  suspiciousDetected,
  noReferenceFound,
}

extension VerificationStateExtension on VerificationState {
  String get label {
    switch (this) {
      case VerificationState.manufacturerSupported:
        return 'Manufacturer-supported verification';
      case VerificationState.referenceAvailable:
        return 'Reference information available';
      case VerificationState.limitedVerification:
        return 'Limited verification';
      case VerificationState.suspiciousDetected:
        return 'Suspicious indicators detected';
      case VerificationState.noReferenceFound:
        return 'No reference found';
    }
  }

  String get code {
    switch (this) {
      case VerificationState.manufacturerSupported:
        return 'MANUFACTURER_SUPPORTED';
      case VerificationState.referenceAvailable:
        return 'REFERENCE_AVAILABLE';
      case VerificationState.limitedVerification:
        return 'LIMITED_VERIFICATION';
      case VerificationState.suspiciousDetected:
        return 'SUSPICIOUS_DETECTED';
      case VerificationState.noReferenceFound:
        return 'NO_REFERENCE_FOUND';
    }
  }

  String get meaning {
    switch (this) {
      case VerificationState.manufacturerSupported:
        return 'Manufacturer-provided reference data is available and scanned details match supported checks. (Does not chemically prove contents).';
      case VerificationState.referenceAvailable:
        return 'A general reference record was found; direct manufacturer-supported batch verification may not be available.';
      case VerificationState.limitedVerification:
        return 'Some information is missing, unreadable, or not covered by available reference data.';
      case VerificationState.suspiciousDetected:
        return 'One or more mismatches, alerts, or unusual identifier patterns require caution and further review.';
      case VerificationState.noReferenceFound:
        return 'No suitable record found in trusted directory. This does not automatically mean counterfeit.';
    }
  }
}

class VerificationAudit {
  final Map<String, String> observedData;
  final Map<String, String> referenceMatch;
  final List<String> unresolvedUncertainty;

  VerificationAudit({
    required this.observedData,
    required this.referenceMatch,
    required this.unresolvedUncertainty,
  });
}

class VerificationResult {
  final VerificationState state;
  final String title;
  final List<String> reasons;
  final VerificationAudit audit;

  /// Clear consumer-facing status required for evaluation:
  /// - 'Reference matched'
  /// - 'Mismatch detected'
  /// - 'Unable to verify'
  final String verificationStatus;

  /// Explicit list of fields that matched the reference record.
  final List<String> matchedFields;

  /// Explicit list of fields that conflicted with the reference record.
  final List<String> mismatchedFields;

  /// True only when backed by a trusted live record rather than bundled sample data.
  final bool isTrustedSource;

  VerificationResult({
    required this.state,
    required this.title,
    required this.reasons,
    required this.audit,
    this.verificationStatus = 'Unable to verify',
    this.matchedFields = const [],
    this.mismatchedFields = const [],
    this.isTrustedSource = false,
  });

  String get riskLevel => state.code;
  String get stateLabel => state.label;
  String get explanation => state.meaning;
}

class VerificationEngine {
  VerificationResult verify({
    required ScanData scanData,
    required List<MedicineModel> matchedMedicines,
    required List<BatchModel> matchedBatches,
    required int previousScanCount,
  }) {
    final displayBrand = scanData.extractedBrand.isNotEmpty
        ? scanData.extractedBrand
        : scanData.extractedName;

    // 1. Compile Observed Data from Camera OCR / Barcode
    final observed = <String, String>{
      'Brand Name': displayBrand.isNotEmpty ? displayBrand : 'Not detected',
      'Generic Salt': scanData.extractedGenericSalt.isNotEmpty
          ? scanData.extractedGenericSalt
          : 'Not detected',
      'Strength': scanData.extractedStrength.isNotEmpty
          ? scanData.extractedStrength
          : 'Not detected',
      'Batch Number': scanData.extractedBatch.isNotEmpty
          ? scanData.extractedBatch
          : 'Not detected',
      'Expiry Date': scanData.extractedExpiry.isNotEmpty
          ? scanData.extractedExpiry
          : 'Not detected',
      'Manufacturer': scanData.extractedManufacturer.isNotEmpty
          ? scanData.extractedManufacturer
          : 'Not detected',
      'Barcode': scanData.extractedBarcode.isNotEmpty
          ? scanData.extractedBarcode
          : 'Not detected',
      if (scanData.specialNotice.isNotEmpty)
        'Packaging Notice': scanData.specialNotice,
    };

    // 2. Check: No Reference Found (including barcode with no trusted reference)
    if (matchedMedicines.isEmpty) {
      final noRefReasons = <String>[
        if (scanData.extractedBarcode.isNotEmpty)
          'Scanned barcode "${scanData.extractedBarcode}" has no matching trusted reference record.',
        'No matching medicine record was found in the reference registry.',
        'A barcode, OCR read, or batch number without a trusted reference cannot verify authenticity.',
      ];

      return VerificationResult(
        state: VerificationState.noReferenceFound,
        title: VerificationState.noReferenceFound.label,
        verificationStatus: 'Unable to verify',
        matchedFields: const [],
        mismatchedFields: const [],
        isTrustedSource: false,
        reasons: noRefReasons,
        audit: VerificationAudit(
          observedData: observed,
          referenceMatch: {
            'Registry Status': 'No matching entry found in reference database',
          },
          unresolvedUncertainty: [
            'Packaging text or barcode could not be mapped to an approved reference product.',
            'Select the correct medicine manually or retake a clearer scan.',
          ],
        ),
      );
    }

    final medicine = matchedMedicines.first;
    final refCompany = medicine.companyName.isNotEmpty
        ? medicine.companyName
        : medicine.manufacturerId;
    final isBundledMedicine =
        MedicineLookupRepository.isBundledReferenceMedicine(
          medicine.medicineId,
        );

    final reference = <String, String>{
      'Registered Brand': medicine.medicineName,
      'Active Formulation': medicine.genericName,
      'Reference Strength': medicine.strength.isNotEmpty
          ? medicine.strength
          : 'Not specified',
      'Company Name': refCompany,
      'Record Source': isBundledMedicine
          ? 'Bundled Reference Catalog (Sample/Offline)'
          : 'Trusted Registry Record',
      if (medicine.registrationInfo.isNotEmpty)
        'Registration Number': medicine.registrationInfo,
    };

    final List<String> suspiciousReasons = [];
    final List<String> uncertainties = [];
    final List<String> matchedFields = [];
    final List<String> mismatchedFields = [];

    // 3. Ambiguous OCR Check
    if (scanData.isAmbiguous) {
      uncertainties.add(
        'Packaging text matched multiple possible medicine candidates (${scanData.candidateNames.take(3).join(", ")}). Please confirm the correct medicine.',
      );
    }

    // 4. Compare Brand Name against Reference
    if (scanData.extractedName.isNotEmpty ||
        scanData.extractedBrand.isNotEmpty) {
      final scannedLabel =
          (scanData.extractedBrand.isNotEmpty
                  ? scanData.extractedBrand
                  : scanData.extractedName)
              .toLowerCase();
      final refBrandRoot = medicine.medicineName.split(' ').first.toLowerCase();
      if (scannedLabel.contains(refBrandRoot) ||
          MedicineLookupRepository.similarity(scannedLabel, refBrandRoot) >=
              0.78) {
        matchedFields.add('Brand Name (${medicine.medicineName})');
      }
    }

    // 5. Compare Strength / Variant against Reference
    if (scanData.extractedStrength.isNotEmpty && medicine.strength.isNotEmpty) {
      final normScannedStrength = _normalizeStrength(
        scanData.extractedStrength,
      );
      final normRefStrength = _normalizeStrength(medicine.strength);
      if (normScannedStrength == normRefStrength) {
        matchedFields.add('Strength (${medicine.strength})');
      } else {
        mismatchedFields.add(
          'Strength (Package: ${scanData.extractedStrength} vs Reference: ${medicine.strength})',
        );
        suspiciousReasons.add(
          'Strength/Variant Mismatch: Package shows "${scanData.extractedStrength}", which conflicts with the reference strength "${medicine.strength}" for ${medicine.medicineName}.',
        );
      }
    } else if (scanData.extractedStrength.isEmpty) {
      uncertainties.add('Strength was not detected on the scanned package.');
    }

    // 6. Compare Generic Salt against Reference
    if (scanData.extractedGenericSalt.isNotEmpty &&
        medicine.genericName.isNotEmpty) {
      final scannedSaltWords = _extractSaltKeywords(
        scanData.extractedGenericSalt,
      );
      final refSaltWords = _extractSaltKeywords(medicine.genericName);
      final saltMatches = scannedSaltWords.any(
        (sw) => refSaltWords.any(
          (rw) =>
              sw == rw ||
              sw.contains(rw) ||
              rw.contains(sw) ||
              MedicineLookupRepository.similarity(sw, rw) >= 0.80,
        ),
      );
      if (saltMatches) {
        matchedFields.add('Generic Salt (${medicine.genericName})');
      } else {
        mismatchedFields.add(
          'Generic Salt (Package: ${scanData.extractedGenericSalt} vs Reference: ${medicine.genericName})',
        );
        suspiciousReasons.add(
          'Formulation Mismatch: Package generic salt "${scanData.extractedGenericSalt}" conflicts with reference active ingredient "${medicine.genericName}".',
        );
      }
    }

    // 7. Compare Manufacturer against Reference
    if (scanData.extractedManufacturer.isNotEmpty) {
      final extWords = _extractCompanyKeywords(scanData.extractedManufacturer);
      final medWords = _extractCompanyKeywords(
        '${medicine.manufacturerId} ${medicine.companyName} ${medicine.medicineName}',
      );

      final sharesKeyword = extWords.any(
        (ew) => medWords.any((mw) => ew.contains(mw) || mw.contains(ew)),
      );
      if (sharesKeyword) {
        matchedFields.add('Manufacturer ($refCompany)');
      } else {
        mismatchedFields.add(
          'Manufacturer (Package: ${scanData.extractedManufacturer} vs Reference: $refCompany)',
        );
        suspiciousReasons.add(
          'Manufacturer Mismatch: Scanned manufacturer "${scanData.extractedManufacturer}" conflicts with registered manufacturer "$refCompany".',
        );
      }
    }

    // 8. Validate Printed Expiry Date
    if (scanData.extractedExpiry.isNotEmpty) {
      final expiryValidation = PackagingOcrParser.validateExpiryDate(
        scanData.extractedExpiry,
      );
      if (expiryValidation.isExpired == true) {
        mismatchedFields.add(
          'Expiry Date (Expired: ${scanData.extractedExpiry})',
        );
        suspiciousReasons.add(
          'Expired Medication: Printed package expiry date (${scanData.extractedExpiry}) has already passed.',
        );
      } else if (expiryValidation.isExpired == false) {
        matchedFields.add('Valid Expiry Date (${scanData.extractedExpiry})');
      } else {
        uncertainties.add(
          'Printed expiry date "${scanData.extractedExpiry}" could not be validated.',
        );
      }
    } else {
      uncertainties.add('Printed expiry date was not detected during scan.');
    }

    // 9. Check Anomaly Detection: Duplicate serialized identifiers
    if (previousScanCount > 5) {
      suspiciousReasons.add(
        'High-frequency scan anomaly: This specific identifier has been recorded $previousScanCount times across different locations.',
      );
    } else if (previousScanCount > 2) {
      uncertainties.add(
        'This identifier has been scanned $previousScanCount previous times.',
      );
    }

    // 10. Check Batch Validity & Trusted vs Sample Batch Source
    bool batchVerified = false;
    bool isTrustedBatch = false;
    if (scanData.extractedBatch.isNotEmpty) {
      if (matchedBatches.isEmpty) {
        uncertainties.add(
          'Scanned batch "${scanData.extractedBatch}" is not registered in the manufacturer batch vault.',
        );
      } else {
        final batch = matchedBatches.first;
        final isBundledBatch = MedicineLookupRepository.isBundledSampleBatch(
          batch.batchId,
        );
        final vaultExpiryFormatted =
            '${batch.expiryDate.month.toString().padLeft(2, '0')}/${batch.expiryDate.year}';

        reference['Batch Status'] = batch.status.toUpperCase();
        reference['Vault Expiry'] = vaultExpiryFormatted;
        reference['Batch Source'] = isBundledBatch
            ? 'Bundled Sample Batch (Unverified Demo Data)'
            : 'Authorized Manufacturer Vault';

        if (batch.status.toLowerCase() != 'active') {
          mismatchedFields.add(
            'Batch Status (${batch.batchNumber} is ${batch.status.toUpperCase()})',
          );
          suspiciousReasons.add(
            'Safety Alert: Batch "${batch.batchNumber}" has status "${batch.status.toUpperCase()}" (recalled/withdrawn).',
          );
        }

        if (batch.expiryDate.isBefore(DateTime.now())) {
          mismatchedFields.add(
            'Batch Expiry (${batch.batchNumber} expired $vaultExpiryFormatted)',
          );
          suspiciousReasons.add(
            'Expired Medication: Batch expiration date (${batch.expiryDate.toLocal().toString().split(' ')[0]}) has passed.',
          );
        }

        // Compare printed expiry date with batch vault expiry date if both exist
        if (scanData.extractedExpiry.isNotEmpty) {
          final parsedPrintedExp = PackagingOcrParser.parseExpiryDate(
            scanData.extractedExpiry,
          );
          if (parsedPrintedExp != null &&
              (parsedPrintedExp.year != batch.expiryDate.year ||
                  parsedPrintedExp.month != batch.expiryDate.month)) {
            mismatchedFields.add(
              'Expiry Mismatch (Printed: ${scanData.extractedExpiry} vs Batch Vault: $vaultExpiryFormatted)',
            );
            suspiciousReasons.add(
              'Expiry Date Conflict: Printed package expiry (${scanData.extractedExpiry}) does not match batch record expiry ($vaultExpiryFormatted).',
            );
          }
        }

        if (scanData.extractedBarcode.isNotEmpty &&
            batch.identifiers.isNotEmpty) {
          if (!batch.identifiers.contains(scanData.extractedBarcode)) {
            mismatchedFields.add(
              'Barcode (${scanData.extractedBarcode} does not match batch ${batch.batchNumber})',
            );
            suspiciousReasons.add(
              'Identifier Mismatch: Scanned barcode does not correspond to this batch record.',
            );
          } else {
            batchVerified = true;
            matchedFields.add('Barcode (${scanData.extractedBarcode})');
          }
        } else {
          batchVerified = true;
        }

        if (isBundledBatch) {
          batchVerified = false;
          isTrustedBatch = false;
          matchedFields.add(
            'Batch Number (${batch.batchNumber} - sample reference)',
          );
          uncertainties.add(
            'The matching batch record is sample data bundled in this app build, not a live manufacturer record, so manufacturer support cannot be confirmed.',
          );
        } else if (batchVerified) {
          isTrustedBatch = true;
          matchedFields.add(
            'Batch Number (${batch.batchNumber} - manufacturer vault)',
          );
        }
      }
    } else {
      uncertainties.add(
        'Batch number was not detected or verified from packaging.',
      );
    }

    // 11. Critical field confirmation gate
    final hasCriticalUnconfirmed = !scanData.criticalFieldsConfirmed;
    if (hasCriticalUnconfirmed) {
      uncertainties.add(
        'One or more critical packaging fields (batch number or expiry date) had low OCR confidence and were not explicitly confirmed by the user.',
      );
    }

    // 12. Resolve Final Verification State & Status
    if (suspiciousReasons.isNotEmpty) {
      return VerificationResult(
        state: VerificationState.suspiciousDetected,
        title: VerificationState.suspiciousDetected.label,
        verificationStatus: 'Mismatch detected',
        matchedFields: matchedFields,
        mismatchedFields: mismatchedFields,
        isTrustedSource: isTrustedBatch,
        reasons: suspiciousReasons,
        audit: VerificationAudit(
          observedData: observed,
          referenceMatch: reference,
          unresolvedUncertainty: uncertainties,
        ),
      );
    }

    if (batchVerified &&
        matchedBatches.isNotEmpty &&
        !hasCriticalUnconfirmed &&
        !scanData.isAmbiguous) {
      return VerificationResult(
        state: VerificationState.manufacturerSupported,
        title: VerificationState.manufacturerSupported.label,
        verificationStatus: 'Reference matched',
        matchedFields: matchedFields,
        mismatchedFields: const [],
        isTrustedSource: true,
        reasons: [
          'Manufacturer-provided reference record confirmed.',
          'Matched fields: ${matchedFields.join(", ")}.',
          if (medicine.registrationInfo.isNotEmpty)
            'Registration: ${medicine.registrationInfo}',
          if (scanData.specialNotice.isNotEmpty)
            'Packaging Notice: ${scanData.specialNotice}',
          'Important: Reference matching confirms database alignment; optical scanning alone does not chemically prove a medicine is genuine.',
        ],
        audit: VerificationAudit(
          observedData: observed,
          referenceMatch: reference,
          unresolvedUncertainty: uncertainties,
        ),
      );
    }

    if (uncertainties.length >= 2 ||
        hasCriticalUnconfirmed ||
        scanData.isAmbiguous ||
        matchedFields.isEmpty) {
      return VerificationResult(
        state: VerificationState.limitedVerification,
        title: VerificationState.limitedVerification.label,
        verificationStatus: 'Unable to verify',
        matchedFields: matchedFields,
        mismatchedFields: const [],
        isTrustedSource: false,
        reasons: [
          'Medicine identified in reference catalog, but authenticity cannot be verified due to missing or unverified batch/packaging evidence.',
          if (matchedFields.isNotEmpty)
            'Matched reference fields: ${matchedFields.join(", ")}.',
          ...uncertainties,
          'Note: A local database or OCR match alone does not prove a medicine is genuine.',
        ],
        audit: VerificationAudit(
          observedData: observed,
          referenceMatch: reference,
          unresolvedUncertainty: uncertainties,
        ),
      );
    }

    return VerificationResult(
      state: VerificationState.referenceAvailable,
      title: VerificationState.referenceAvailable.label,
      verificationStatus: 'Reference matched',
      matchedFields: matchedFields,
      mismatchedFields: const [],
      isTrustedSource: !isBundledMedicine,
      reasons: [
        'Reference fields matched in pharmaceutical catalog: ${matchedFields.join(", ")}.',
        'Direct live manufacturer batch verification is not linked for this unit.',
        if (medicine.registrationInfo.isNotEmpty)
          'Registration: ${medicine.registrationInfo}',
        'Important: Reference matching confirms catalog details only and does not prove a medicine is chemically genuine.',
      ],
      audit: VerificationAudit(
        observedData: observed,
        referenceMatch: reference,
        unresolvedUncertainty: uncertainties,
      ),
    );
  }

  static String _normalizeStrength(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  }

  static List<String> _extractSaltKeywords(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\b(?:b\.?p\.?|u\.?s\.?p\.?|ip|ph\.?eur)\b'), '')
        .split(RegExp(r'[^a-z0-9]+'))
        .where(
          (w) =>
              w.length >= 4 &&
              w != 'acid' &&
              w != 'sodium' &&
              w != 'potassium' &&
              w != 'hydrochloride' &&
              w != 'calcium' &&
              w != 'tablet' &&
              w != 'tablets',
        )
        .toList();
  }

  static List<String> _extractCompanyKeywords(String s) {
    const stop = {
      'mfg',
      'ltd',
      'pvt',
      'pharma',
      'pharmaceuticals',
      'pharmaceutical',
      'laboratories',
      'laboratory',
      'pakistan',
      'company',
      'the',
      'limited',
      'inc',
      'corp',
    };
    return s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toList();
  }
}
