import '../repositories/medicine_lookup_repository.dart';
import 'ocr_service.dart';

class RankedBrandCandidate {
  final String brandName;
  final double score;
  final String reason;

  const RankedBrandCandidate({
    required this.brandName,
    required this.score,
    required this.reason,
  });
}

class ParsedMedicineInfo {
  final String medicineName;
  final String brandName;
  final String genericSalt;
  final String strength;
  final String dosageForm;
  final String manufacturer;
  final String batchNumber;
  final String mfgDate;
  final String expiryDate;
  final String barcode;
  final String price;
  final String registrationInfo;
  final String specialNotice;
  final List<String> cleanedLines;
  final String structuredSummary;
  final List<String> brandCandidates;
  final bool isAmbiguous;
  final bool? isExpired;
  final String expiryValidationMessage;

  ParsedMedicineInfo({
    required this.medicineName,
    required this.brandName,
    required this.genericSalt,
    required this.strength,
    required this.dosageForm,
    required this.manufacturer,
    required this.batchNumber,
    required this.mfgDate,
    required this.expiryDate,
    this.barcode = '',
    required this.price,
    required this.registrationInfo,
    required this.specialNotice,
    required this.cleanedLines,
    required this.structuredSummary,
    this.brandCandidates = const [],
    this.isAmbiguous = false,
    this.isExpired,
    this.expiryValidationMessage = '',
  });
}

class PackagingOcrParser {
  // Screen/IDE/Terminal background noise tokens to discard
  static final List<String> _screenNoiseTokens = [
    'edit selection',
    'view go run',
    'terminal help',
    'explorer',
    'egplorer',
    'medscanpro',
    'github\\workilows',
    'workflows',
    'build josyml',
    'vmedscan',
    'dart tool',
    'gradle',
    'kotlin',
    'capslk',
    'fnlock',
    'shift',
    'ctrl',
    'alt',
    'aradle',
    'windows',
    'cmd.exe',
  ];

  // URL, domain, email, and retailer patterns to strictly exclude from brand candidates
  static final RegExp _urlOrDomainRegex = RegExp(
    r'(?:https?:\/\/|www\.|[a-z0-9\-]+\.(?:com|pk|net|org|io|co|gov|edu|med|shop|store|info|biz)\b|@)',
    caseSensitive: false,
  );

  static final Set<String> _retailerAndWebsiteTokens = {
    'dawaai',
    'dawaai.com',
    'dvago',
    'dvago.pk',
    'sehat',
    'sehat.com.pk',
    'emeds',
    'emeds.pk',
    'medznmore',
    'tabiyat',
    'tabiyat.pk',
    'servaid',
    'clinix',
    'fazaldin',
    'chughtai',
    'marham',
    'oladoc',
    'daraz',
    'daraz.pk',
    'pharmacy',
    'online',
    'order',
    'delivery',
    'website',
  };

  // Slogans and irrelevant packaging phrases to exclude or down-rank
  static final List<String> _sloganAndIrrelevantPhrases = [
    'fast pain relief',
    'effective pain relief',
    'rapid relief',
    'quick relief',
    'gentle on stomach',
    'on the go',
    'new pack',
    'value pack',
    'economy pack',
    'family pack',
    'doctor recommended',
    'no. 1',
    'number 1',
    'original',
    'soluble',
    'dispersible tablets',
    'effervescent',
    'dissolves quickly',
    'dissolve in water',
    'fever and pain',
    'headache relief',
    'toothache',
    'migraine',
    'cold and flu',
    'sugar free',
    'alcohol free',
    'non drowsy',
    'manufactured by',
    'marketed by',
    'distributed by',
    'packed by',
    'sole agent',
    'registered trademark',
    'all rights reserved',
    'see enclosed leaflet',
    'read the leaflet',
    'as directed by physician',
    'as directed by the physician',
    'to be sold on prescription',
    'prescription only medicine',
  ];

  // Pharmaceutical boilerplate lines to exclude from medicine name candidates
  static final List<String> _boilerplatePrefixes = [
    'each enteric coated tablet contains',
    'each enteric-coated tablet contains',
    'each film coated tablet contains',
    'each film-coated tablet contains',
    'each dispersible tablet contains',
    'each soluble tablet contains',
    'each uncoated tablet contains',
    'each tablet contains',
    'each capsule contains',
    'each 5ml contains',
    'each ml contains',
    'contains:',
    'composition:',
    'dosage:',
    'indications:',
    'directions:',
    'warnings:',
    'precautions:',
    'keep out of reach',
    'store below',
    'store in a cool',
    'protect from',
    'protect from light',
    'for oral use',
    'batch no',
    'lot no',
    'mfg. date',
    'mig. date',
    'exp. date',
    'expiry date',
    'mrp. rs',
    'm.r.p',
  ];

  // Common Pakistani and International Pharmaceutical Manufacturers
  static final Map<String, String> _knownManufacturers = {
    'novamed': 'NovaMed Pharmaceuticals',
    'reckitt': 'Reckitt Benckiser Pakistan',
    'benckiser': 'Reckitt Benckiser Pakistan',
    'gsk': 'GSK Pakistan',
    'glaxosmithkline': 'GlaxoSmithKline Pakistan',
    'haleon': 'Haleon Pakistan Ltd',
    'abbott': 'Abbott Laboratories Pakistan',
    'getz': 'Getz Pharma',
    'searle': 'The Searle Company Ltd',
    'sami': 'Sami Pharmaceuticals',
    'hilton': 'Hilton Pharma',
    'ferozsons': 'Ferozsons Laboratories',
    'sanofi': 'Sanofi-Aventis Pakistan',
    'pfizer': 'Pfizer Pakistan',
    'pharmevo': 'PharmEvo Pvt Ltd',
    'bosch': 'Bosch Pharmaceuticals',
    'martin dow': 'Martin Dow Ltd',
    'highnoon': 'Highnoon Laboratories',
    'ccl': 'CCL Pharmaceuticals',
    'wilshire': 'Wilshire Laboratories',
    'macter': 'Macter Laboratories',
    'barrett': 'Barrett Hodgson',
    'genix': 'Genix Pharma',
    'brookes': 'Brookes Pharma',
    'atco': 'Atco Laboratories',
    'agp': 'AGP Limited',
    'novartis': 'Novartis Pharma Pakistan',
    'sandoz': 'Sandoz Pakistan',
    'merck': 'Merck Marker Pvt Ltd',
  };

  // Known Generic Salts
  static final List<String> _knownSalts = [
    'Diclofenac Sodium',
    'Diclofenac Potassium',
    'Paracetamol',
    'Acetaminophen',
    'Aspirin',
    'Acetylsalicylic Acid',
    'Amoxicillin',
    'Clavulanic Acid',
    'Metformin Hydrochloride',
    'Metformin',
    'Ibuprofen',
    'Mefenamic Acid',
    'Naproxen',
    'Ciprofloxacin',
    'Metronidazole',
    'Omeprazole',
    'Esomeprazole',
    'Pantoprazole',
    'Famotidine',
    'Azithromycin',
    'Cefixime',
    'Ceftriaxone',
    'Levofloxacin',
    'Loratadine',
    'Cetirizine',
    'Fexofenadine',
    'Montelukast',
    'Amlodipine',
    'Atorvastatin',
    'Rosuvastatin',
    'Losartan',
    'Valsartan',
    'Bisoprolol',
    'Sitagliptin',
    'Empagliflozin',
    'Glimepiride',
    'Calcium Carbonate',
    'Cholecalciferol',
  ];

  static bool isUrlOrIrrelevantBrandToken(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    if (_urlOrDomainRegex.hasMatch(lower)) return true;
    for (final token in _retailerAndWebsiteTokens) {
      if (lower == token ||
          lower.contains('$token.') ||
          lower.startsWith('$token ') ||
          lower.endsWith(' $token')) {
        return true;
      }
    }
    return false;
  }

  static ParsedMedicineInfo parse(
    String rawText, {
    List<OcrTextLine>? ocrLines,
  }) {
    if (rawText.trim().isEmpty && (ocrLines == null || ocrLines.isEmpty)) {
      return ParsedMedicineInfo(
        medicineName: '',
        brandName: '',
        genericSalt: '',
        strength: '',
        dosageForm: '',
        manufacturer: '',
        batchNumber: '',
        mfgDate: '',
        expiryDate: '',
        barcode: '',
        price: '',
        registrationInfo: '',
        specialNotice: '',
        cleanedLines: [],
        structuredSummary: 'No packaging text scanned.',
        brandCandidates: const [],
        isAmbiguous: false,
        isExpired: null,
        expiryValidationMessage: 'Not detected',
      );
    }

    final effectiveRawText = rawText.trim().isNotEmpty
        ? rawText
        : ocrLines!.map((l) => l.text).join('\n');

    final rawLines = effectiveRawText.split('\n').map((l) => l.trim()).toList();

    // 1. Clean and filter out background screen / camera noise
    final cleanedLines = <String>[];
    for (final line in rawLines) {
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();

      // Check if it's IDE/Screen noise
      final isNoise = _screenNoiseTokens.any((t) => lower.contains(t));
      if (isNoise) continue;

      // Discard pure single letters or keyboard tokens
      if (RegExp(
        r'^(?:[a-zA-Z]|shift|tab|esc|fnlock|capslk|>.*)$',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }

      cleanedLines.add(line);
    }

    // 2. Detect Special Regulatory / Government Warnings
    String specialNotice = '';
    for (final line in cleanedLines) {
      final upper = line.toUpperCase();
      if (upper.contains('PUNJAB') &&
          (upper.contains('PROPER') ||
              upper.contains('COVL') ||
              upper.contains('GOVT'))) {
        specialNotice = 'Punjab Govt Property - Not for Sale';
        break;
      }
      if (upper.contains('NOT FOR SALE') ||
          upper.contains('NOT FORSALE') ||
          (upper.contains('NOT') && upper.contains('SALE'))) {
        specialNotice = 'Government Health Supply - Not for Commercial Sale';
      }
      if (upper.contains('SINDH') && upper.contains('GOVT')) {
        specialNotice = 'Sindh Govt Property - Not for Sale';
        break;
      }
    }

    // 3. Extract Strength (e.g., 300mg, 50mg, 500mg, 625mg, 10ml, etc.)
    String detectedStrength = '';
    int? strengthLineIndex;
    final strengthRegex = RegExp(
      r'\b(\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%))\b',
      caseSensitive: false,
    );
    for (int i = 0; i < cleanedLines.length; i++) {
      final line = cleanedLines[i];
      if (isUrlOrIrrelevantBrandToken(line)) continue;
      final match = strengthRegex.firstMatch(line);
      if (match != null) {
        detectedStrength = match.group(1)!.replaceAll(' ', '').toLowerCase();
        strengthLineIndex = i;
        break;
      }
    }

    // 4. Extract Generic Salt (e.g., Aspirin, Diclofenac Sodium B.P, Paracetamol)
    String detectedGenericSalt = '';
    int? saltLineIndex;
    for (int i = 0; i < cleanedLines.length; i++) {
      final line = cleanedLines[i];
      if (isUrlOrIrrelevantBrandToken(line)) continue;
      for (final salt in _knownSalts) {
        if (RegExp(
          r'\b' + RegExp.escape(salt) + r'\b',
          caseSensitive: false,
        ).hasMatch(line)) {
          if (line.toUpperCase().contains('B.P') ||
              RegExp(r'\bBP\b').hasMatch(line.toUpperCase())) {
            detectedGenericSalt = '$salt B.P.';
          } else if (line.toUpperCase().contains('U.S.P') ||
              RegExp(r'\bUSP\b').hasMatch(line.toUpperCase())) {
            detectedGenericSalt = '$salt U.S.P.';
          } else {
            detectedGenericSalt = salt;
          }
          saltLineIndex = i;
          break;
        }
      }
      if (detectedGenericSalt.isNotEmpty) break;
    }

    // 5. Extract Manufacturer
    String detectedManufacturer = '';
    for (final line in cleanedLines) {
      if (isUrlOrIrrelevantBrandToken(line)) continue;
      final lower = line.toLowerCase();
      for (final entry in _knownManufacturers.entries) {
        if (RegExp(
          r'\b' + RegExp.escape(entry.key) + r'\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
          detectedManufacturer = entry.value;
          break;
        }
      }
      if (detectedManufacturer.isNotEmpty) break;
    }
    if (detectedManufacturer.isEmpty) {
      for (final line in cleanedLines) {
        if (isUrlOrIrrelevantBrandToken(line)) continue;
        final lower = line.toLowerCase();
        if (lower.contains('pharma') ||
            lower.contains('laboratories') ||
            lower.contains('mfg. by') ||
            lower.contains('manufactured by') ||
            lower.contains('pvt ltd') ||
            lower.contains('(pvt) ltd')) {
          detectedManufacturer = line
              .replaceAll(
                RegExp(
                  r'^(?:mfg\.?\s*by:?|manufactured\s*by:?)\s*',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
          break;
        }
      }
    }

    // 6. Extract Dosage Form & Packaging
    String detectedForm = '';
    int? formLineIndex;
    for (int i = 0; i < cleanedLines.length; i++) {
      final lower = cleanedLines[i].toLowerCase();
      if (lower.contains('enteric coated') ||
          lower.contains('enteric-coated')) {
        detectedForm = 'Enteric Coated Tablet';
        formLineIndex = i;
        break;
      } else if (lower.contains('film coated') ||
          lower.contains('film-coated')) {
        detectedForm = 'Film Coated Tablet';
        formLineIndex = i;
        break;
      } else if (lower.contains('dispersible') || lower.contains('soluble')) {
        detectedForm = 'Tablet';
        formLineIndex = i;
        break;
      } else if (lower.contains('capsule')) {
        detectedForm = 'Capsule';
        formLineIndex = i;
        break;
      } else if (lower.contains('suspension') || lower.contains('syrup')) {
        detectedForm = 'Oral Suspension';
        formLineIndex = i;
        break;
      } else if (lower.contains('injection') || lower.contains('ampoule')) {
        detectedForm = 'Injection';
        formLineIndex = i;
        break;
      } else if (lower.contains('tablet')) {
        detectedForm = 'Tablet';
        formLineIndex = i;
        break;
      }
    }
    if (detectedForm.isEmpty && cleanedLines.isNotEmpty) {
      detectedForm = 'Tablet';
    }

    // 7. Extract Stacked or Inline Batch, Mfg Date, Expiry Date, MRP, Barcode
    String detectedBatch = '';
    String detectedMfgDate = '';
    String detectedExpDate = '';
    String detectedPrice = '';
    String detectedBarcode = '';

    for (final line in cleanedLines) {
      final gtinMatch = RegExp(r'\b(\d{12,14})\b').firstMatch(line);
      if (gtinMatch != null) {
        detectedBarcode = gtinMatch.group(1)!;
        break;
      }
    }

    for (int i = 0; i < cleanedLines.length; i++) {
      final line = cleanedLines[i];
      final l = line.toLowerCase();
      final isBatchLabel =
          l.startsWith('batch') ||
          l.startsWith('b.no') ||
          l.startsWith('b/no') ||
          l.startsWith('lot');
      final isExpLabel =
          l.startsWith('exp') ||
          l.startsWith('expiry') ||
          l.contains('exp. date') ||
          l.contains('expiry date');
      final isMfgLabel =
          l.startsWith('mfg') || l.startsWith('mig') || l.startsWith('mfd');
      final isMrpLabel =
          l.startsWith('mrp') || l.startsWith('price') || l.startsWith('rs.');

      if (isBatchLabel) {
        final val = _extractTrailingValue(line, [
          'batch no.',
          'batch no:',
          'batch no',
          'batch:',
          'batch',
          'b.no.',
          'b.no:',
          'b.no',
          'b/no:',
          'b/no',
          'lot no.',
          'lot no:',
          'lot no',
          'lot:',
          'lot',
        ]);
        if (_isValidBatchCandidate(val)) {
          detectedBatch = val;
        }
      }
      if (isMfgLabel) {
        final val = _extractTrailingValue(line, [
          'mfg. date:',
          'mfg. date',
          'mig. date:',
          'mig. date',
          'mfg date:',
          'mfg date',
          'mfd:',
          'mfg:',
        ]);
        if (_looksLikeDate(val)) detectedMfgDate = _formatDate(val);
      }
      if (isExpLabel) {
        final val = _extractTrailingValue(line, [
          'exp. date:',
          'exp. date',
          'expiry date:',
          'expiry date',
          'exp date:',
          'exp date',
          'expiry:',
          'exp:',
          'exp.',
          'exp',
        ]);
        if (_looksLikeDate(val)) detectedExpDate = _formatDate(val);
      }
      if (isMrpLabel) {
        final val = _extractTrailingValue(line, [
          'mrp. rs.:',
          'mrp. rs.',
          'mrp. rs',
          'mrp rs:',
          'mrp:',
          'price:',
          'rs.',
        ]);
        if (RegExp(r'\d+').hasMatch(val)) detectedPrice = 'Rs. $val';
      }
    }

    // If still missing, check for consecutive stacked layout
    if (detectedBatch.isEmpty || detectedExpDate.isEmpty) {
      for (int i = 0; i < cleanedLines.length - 1; i++) {
        final l = cleanedLines[i].toLowerCase();
        if ((l.contains('batch') || l.startsWith('lot')) &&
            (l.contains('no') ||
                l.endsWith(':') ||
                l.endsWith('.') ||
                l == 'batch' ||
                l == 'lot')) {
          final candidates = <String>[];
          for (int j = i + 1; j < cleanedLines.length && j <= i + 8; j++) {
            final next = cleanedLines[j].trim();
            final nextLower = next.toLowerCase();
            if (nextLower.contains('date') ||
                nextLower.contains('mrp') ||
                nextLower.contains('exp') ||
                nextLower.contains('mig') ||
                nextLower.contains('mfg') ||
                nextLower.contains('rs')) {
              continue;
            }
            candidates.add(next);
          }

          if (candidates.isNotEmpty) {
            for (final cand in candidates) {
              if (_looksLikeDate(cand)) {
                if (detectedMfgDate.isEmpty && candidates.length >= 2) {
                  detectedMfgDate = _formatDate(cand);
                } else if (detectedExpDate.isEmpty) {
                  detectedExpDate = _formatDate(cand);
                }
              } else if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(cand) &&
                  cand.contains('.')) {
                if (detectedPrice.isEmpty) detectedPrice = 'Rs. $cand';
              } else if (_isValidBatchCandidate(cand) &&
                  detectedBatch.isEmpty) {
                detectedBatch = cand;
              }
            }
          }
          break;
        }
      }
    }

    // Standalone date scanner if still missing
    if (detectedExpDate.isEmpty) {
      final datePattern = RegExp(
        r'\b((?:0?[1-9]|1[0-2])[\/\-](?:20\d{2}|\d{2})|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\/\-]+(?:20\d{2}|\d{2}))\b',
        caseSensitive: false,
      );
      final dates = <String>[];
      for (final line in cleanedLines) {
        final matches = datePattern.allMatches(line);
        for (final m in matches) {
          dates.add(m.group(0)!);
        }
      }
      if (dates.length >= 2) {
        detectedMfgDate = _formatDate(dates[0]);
        detectedExpDate = _formatDate(dates[1]);
      } else if (dates.length == 1) {
        detectedExpDate = _formatDate(dates[0]);
      }
    }

    // Validate expiry date
    final expiryCheck = validateExpiryDate(detectedExpDate);

    // 8. Extract Registration Info (DRAP Reg #)
    String detectedReg = '';
    final regPattern = RegExp(
      r'\b(?:reg\.?\s*(?:no\.?|#)?\s*[:\s]*)([a-zA-Z0-9\-\/]+)',
      caseSensitive: false,
    );
    for (final line in cleanedLines) {
      final m = regPattern.firstMatch(line);
      if (m != null) {
        final val = m.group(1)!.trim();
        if (val.length >= 3 && !isUrlOrIrrelevantBrandToken(val)) {
          detectedReg = 'DRAP Reg # $val';
          break;
        }
      }
    }

    // 9. Rank and Select Medicine Brand Name
    // NEVER select the first OCR line blindly. Score all candidate lines using:
    // - URL/domain/retailer exclusion
    // - Exact & fuzzy reference medicine database matches
    // - Visual prominence (bounding box height/area when available)
    // - Proximity to strength, generic salt, and dosage form lines
    // - Typography and brand-name characteristics
    final rankedCandidates = rankBrandCandidates(
      cleanedLines: cleanedLines,
      ocrLines: ocrLines,
      detectedStrength: detectedStrength,
      detectedGenericSalt: detectedGenericSalt,
      detectedManufacturer: detectedManufacturer,
      strengthLineIndex: strengthLineIndex,
      saltLineIndex: saltLineIndex,
      formLineIndex: formLineIndex,
    );

    String detectedBrand = '';
    bool isAmbiguous = false;
    final candidateNamesList = <String>[];

    for (final rc in rankedCandidates) {
      if (rc.score > 0 && !candidateNamesList.contains(rc.brandName)) {
        candidateNamesList.add(rc.brandName);
      }
    }

    if (rankedCandidates.isNotEmpty && rankedCandidates.first.score >= 25.0) {
      detectedBrand = rankedCandidates.first.brandName;
      if (rankedCandidates.length >= 2) {
        final topScore = rankedCandidates[0].score;
        final runnerUpScore = rankedCandidates[1].score;
        // Mark ambiguous if top score was not a strong database match and runner-up is very close
        if (topScore < 85.0 && (topScore - runnerUpScore) <= 12.0) {
          isAmbiguous = true;
        }
      }
    } else if (rankedCandidates.isNotEmpty &&
        rankedCandidates.first.score > 0) {
      // Low confidence / ambiguous brand candidate
      detectedBrand = rankedCandidates.first.brandName;
      isAmbiguous = true;
    }

    // Also include database medicine candidates matching salt if brand was not clearly found
    if (detectedBrand.isEmpty && detectedGenericSalt.isNotEmpty) {
      final saltBase = detectedGenericSalt
          .replaceAll(
            RegExp(r'\b(?:B\.?P\.?|U\.?S\.?P\.?)\b', caseSensitive: false),
            '',
          )
          .trim();
      for (final refMed in MedicineLookupRepository.staticReferenceMedicines) {
        if (refMed.genericName.toLowerCase().contains(saltBase.toLowerCase())) {
          final brandRoot = refMed.medicineName.split(' ').first;
          if (!candidateNamesList.contains(brandRoot)) {
            candidateNamesList.add(brandRoot);
          }
        }
      }
      if (candidateNamesList.length > 1) {
        isAmbiguous = true;
      }
    }

    // Synthesize final medicine name
    String finalMedicineName = '';
    if (detectedBrand.isNotEmpty) {
      finalMedicineName = detectedBrand;
      if (detectedStrength.isNotEmpty &&
          !finalMedicineName.toLowerCase().contains(detectedStrength)) {
        finalMedicineName = '$finalMedicineName $detectedStrength';
      }
    } else if (detectedGenericSalt.isNotEmpty) {
      finalMedicineName = detectedGenericSalt;
      if (detectedStrength.isNotEmpty &&
          !finalMedicineName.toLowerCase().contains(detectedStrength)) {
        finalMedicineName = '$finalMedicineName $detectedStrength';
      }
    }

    // Build structured easy-to-read summary
    final buffer = StringBuffer();
    buffer.writeln('📋 Cleaned & Structured Extraction:');
    if (finalMedicineName.isNotEmpty) {
      buffer.writeln('• Brand Name: $finalMedicineName');
    }
    if (detectedGenericSalt.isNotEmpty) {
      buffer.writeln(
        '• Active Generic: $detectedGenericSalt ${detectedStrength.isNotEmpty ? "($detectedStrength)" : ""}',
      );
    }
    if (detectedManufacturer.isNotEmpty) {
      buffer.writeln('• Manufacturer: $detectedManufacturer');
    }
    if (detectedBatch.isNotEmpty) {
      buffer.writeln('• Batch Number: $detectedBatch');
    }
    if (detectedMfgDate.isNotEmpty) {
      buffer.writeln('• Mfg. Date: $detectedMfgDate');
    }
    if (detectedExpDate.isNotEmpty) {
      buffer.writeln('• Expiry Date: $detectedExpDate');
    }
    if (detectedPrice.isNotEmpty) {
      buffer.writeln('• Retail Price: $detectedPrice');
    }
    if (detectedForm.isNotEmpty) {
      buffer.writeln('• Dosage Form: $detectedForm');
    }
    if (specialNotice.isNotEmpty) {
      buffer.writeln('• Special Tag: ⚠️ $specialNotice');
    }

    return ParsedMedicineInfo(
      medicineName: finalMedicineName,
      brandName: detectedBrand,
      genericSalt: detectedGenericSalt,
      strength: detectedStrength,
      dosageForm: detectedForm,
      manufacturer: detectedManufacturer,
      batchNumber: detectedBatch,
      mfgDate: detectedMfgDate,
      expiryDate: detectedExpDate,
      barcode: detectedBarcode,
      price: detectedPrice,
      registrationInfo: detectedReg,
      specialNotice: specialNotice,
      cleanedLines: cleanedLines,
      structuredSummary: buffer.toString().trim(),
      brandCandidates: candidateNamesList,
      isAmbiguous: isAmbiguous,
      isExpired: expiryCheck.isExpired,
      expiryValidationMessage: expiryCheck.message,
    );
  }

  /// Ranks all potential brand name candidates across the OCR lines.
  static List<RankedBrandCandidate> rankBrandCandidates({
    required List<String> cleanedLines,
    List<OcrTextLine>? ocrLines,
    required String detectedStrength,
    required String detectedGenericSalt,
    required String detectedManufacturer,
    int? strengthLineIndex,
    int? saltLineIndex,
    int? formLineIndex,
  }) {
    final results = <RankedBrandCandidate>[];
    final seenLower = <String>{};

    // Compute maximum bounding box height & area for visual prominence normalization
    double maxLineHeight = 0;
    double maxLineArea = 0;
    if (ocrLines != null && ocrLines.isNotEmpty) {
      for (final ol in ocrLines) {
        if (ol.height > maxLineHeight) maxLineHeight = ol.height;
        if (ol.area > maxLineArea) maxLineArea = ol.area;
      }
    }

    const nonBrandWords = {
      'not',
      'for',
      'sale',
      'forsale',
      'properiy',
      'property',
      'govt',
      'covl',
      'government',
      'punjab',
      'sindh',
      'kpk',
      'balochistan',
      'tablets',
      'tablet',
      'capsules',
      'capsule',
      'syrup',
      'suspension',
      'injection',
      'drops',
      'sachet',
      'only',
      'daily',
      'dose',
      'dosage',
      'oral',
      'use',
      'contains',
      'composition',
      'keep',
      'store',
      'protect',
      'warning',
      'caution',
      'batch',
      'lot',
      'mfg',
      'mig',
      'mfd',
      'exp',
      'expiry',
      'date',
      'mrp',
      'price',
      'pakistan',
      'karachi',
      'lahore',
      'islamabad',
      'rawalpindi',
      'peshawar',
      'soluble',
      'dispersible',
      'enteric',
      'coated',
      'film',
      'relief',
      'pain',
      'fever',
      'fast',
      'quick',
      'original',
    };

    for (int i = 0; i < cleanedLines.length; i++) {
      final rawLine = cleanedLines[i];
      final lower = rawLine.toLowerCase().trim();

      // 1. Hard Exclusions: URLs, website domains, retailers (e.g. "dawaai.com")
      if (isUrlOrIrrelevantBrandToken(rawLine)) continue;

      // 2. Skip pharmaceutical boilerplate prefixes & labels
      if (_boilerplatePrefixes.any((p) => lower.startsWith(p) || lower == p)) {
        continue;
      }
      if (lower.startsWith('batch') ||
          lower.startsWith('lot') ||
          lower.startsWith('exp') ||
          lower.startsWith('mfg') ||
          lower.startsWith('mig') ||
          lower.startsWith('mrp') ||
          lower.startsWith('reg')) {
        continue;
      }

      // 3. Skip packaging count e.g. "10x10's Tablets", "20 Tablets", "100ml"
      if (RegExp(r'\d+\s*x\s*\d+', caseSensitive: false).hasMatch(rawLine)) {
        continue;
      }
      if (RegExp(
        r'^\d+\s*(?:tablets?|capsules?|sachets?|strips?|packs?|ml|mg|g|mcg)\b',
        caseSensitive: false,
      ).hasMatch(rawLine)) {
        continue;
      }

      // 4. Skip government notices & manufacturer lines
      if (lower.contains('punjab') ||
          lower.contains('sindh') ||
          lower.contains('govt') ||
          lower.contains('covl') ||
          lower.contains('proper') ||
          lower.contains('not for sale')) {
        continue;
      }
      if (detectedManufacturer.isNotEmpty &&
          lower.contains(detectedManufacturer.toLowerCase())) {
        continue;
      }
      if (_knownManufacturers.keys.any(
        (k) => RegExp(
          r'\b' + RegExp.escape(k) + r'\b',
          caseSensitive: false,
        ).hasMatch(lower),
      )) {
        continue;
      }
      if (lower.contains('pharma') ||
          lower.contains('laboratories') ||
          lower.contains('pvt ltd') ||
          lower.contains('reckitt') ||
          lower.contains('benckiser')) {
        continue;
      }

      // 5. Skip marketing slogans and irrelevant phrases
      if (_sloganAndIrrelevantPhrases.any((p) => lower.contains(p))) {
        continue;
      }

      // 6. Clean candidate text (strip inline strength/form suffix to evaluate brand core)
      var cleanCandidate = rawLine
          .replaceAll(RegExp(r'[\(\)\[\]®™*]'), ' ')
          .replaceAll(
            RegExp(
              r'\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\b(?:dispersible|soluble|enteric|film|coated|tablets?|capsules?|syrup|suspension|injection|b\.?p\.?|u\.?s\.?p\.?)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanCandidate.isEmpty) continue;
      if (isUrlOrIrrelevantBrandToken(cleanCandidate)) continue;

      final alphaLetters = cleanCandidate.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (alphaLetters.length < 3) continue;
      if (RegExp(
        r'^[0-9bB8]\.[pP]\.?$',
        caseSensitive: false,
      ).hasMatch(cleanCandidate)) {
        continue;
      }

      final candidateLower = cleanCandidate.toLowerCase();
      if (nonBrandWords.contains(candidateLower)) continue;

      // Skip if the candidate is purely a known generic salt name
      final isPureSalt = _knownSalts.any(
        (s) =>
            candidateLower == s.toLowerCase() ||
            candidateLower.contains(s.toLowerCase()),
      );
      if (isPureSalt) continue;

      // Skip if all words in candidate are stopwords/non-brand words
      final words = candidateLower
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty || words.length > 3) continue;
      if (words.every((w) => nonBrandWords.contains(w))) continue;

      // Score this candidate!
      double score = 15.0; // Base score for passing hygiene filters
      final reasons = <String>[];

      // A. Reference Medicine Database Match (Exact & Fuzzy)
      double bestDbBoost = 0;
      String? canonicalBrand;
      for (final med in MedicineLookupRepository.staticReferenceMedicines) {
        final refBrand = med.medicineName
            .replaceAll(
              RegExp(
                r'\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%)\b',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        final refRoot = refBrand.split(' ').first;

        final simFull = MedicineLookupRepository.similarity(
          cleanCandidate,
          refBrand,
        );
        final simRoot = MedicineLookupRepository.similarity(
          cleanCandidate,
          refRoot,
        );
        final bestSim = simFull > simRoot ? simFull : simRoot;

        if (bestSim == 1.0) {
          bestDbBoost = 100.0;
          canonicalBrand = refBrand;
          reasons.add('Exact medicine database brand match ($refBrand)');
          // Extra context bonus if scanned salt or strength also matches this reference record
          if (detectedGenericSalt.isNotEmpty &&
              med.genericName.toLowerCase().contains(
                detectedGenericSalt.split(' ').first.toLowerCase(),
              )) {
            bestDbBoost += 25.0;
            reasons.add('Matches reference generic salt (${med.genericName})');
          }
          if (detectedStrength.isNotEmpty &&
              med.strength.toLowerCase() == detectedStrength.toLowerCase()) {
            bestDbBoost += 20.0;
            reasons.add('Matches reference strength (${med.strength})');
          }
          break;
        } else if (bestSim >= 0.80 && bestDbBoost < 75.0) {
          bestDbBoost = 75.0 * bestSim;
          canonicalBrand = refBrand;
          reasons.add('Fuzzy medicine database match ($refBrand)');
        }
      }
      score += bestDbBoost;

      // B. Visual Prominence from OCR Bounding Boxes (if available)
      if (ocrLines != null && maxLineHeight > 0) {
        OcrTextLine? matchingOcrLine;
        for (final ol in ocrLines) {
          if (ol.text.toLowerCase().contains(candidateLower) &&
              !isUrlOrIrrelevantBrandToken(ol.text)) {
            matchingOcrLine = ol;
            break;
          }
        }
        if (matchingOcrLine != null && matchingOcrLine.height > 0) {
          final heightRatio = matchingOcrLine.height / maxLineHeight;
          final prominenceBoost = (heightRatio * 35.0).clamp(0.0, 35.0);
          score += prominenceBoost;
          if (heightRatio >= 0.75) {
            reasons.add('Visually prominent text on package');
          }
        }
      }

      // C. Proximity to Strength, Generic Salt, or Dosage Form
      final inlineHasStrength = RegExp(
        r'\b(\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%))\b',
        caseSensitive: false,
      ).hasMatch(rawLine);
      if (inlineHasStrength) {
        score += 20.0;
        reasons.add('Printed alongside strength');
      } else if (strengthLineIndex != null &&
          (i - strengthLineIndex).abs() <= 2) {
        score += 15.0;
        reasons.add('Adjacent to strength text');
      }

      if (saltLineIndex != null && (i - saltLineIndex).abs() <= 2) {
        score += 18.0;
        reasons.add('Adjacent to generic salt text');
      }

      if (formLineIndex != null && (i - formLineIndex).abs() <= 2) {
        score += 10.0;
        reasons.add('Near dosage form');
      }

      // D. Brand Typography Characteristics (single/two-word clean title/upper case)
      if (words.length == 1 &&
          alphaLetters.length >= 4 &&
          alphaLetters.length <= 14) {
        score += 12.0;
      }
      if (RegExp(
        r'^[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?$',
      ).hasMatch(cleanCandidate)) {
        score += 10.0;
      }

      final displayBrand = canonicalBrand ?? _toTitleCaseBrand(cleanCandidate);
      final key = displayBrand.toLowerCase();
      if (!seenLower.contains(key)) {
        seenLower.add(key);
        results.add(
          RankedBrandCandidate(
            brandName: displayBrand,
            score: score,
            reason: reasons.isEmpty
                ? 'Candidate packaging brand text'
                : reasons.join('; '),
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static String _toTitleCaseBrand(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    // Keep short all-caps acronyms or standard brand casing clean
    if (trimmed.length <= 3 && trimmed == trimmed.toUpperCase()) {
      return trimmed;
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return '';
          if (w.length <= 2 && w == w.toUpperCase()) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static bool _isValidBatchCandidate(String value) {
    final clean = value.trim();
    if (clean.length < 3 || clean.length > 16) return false;
    final lower = clean.toLowerCase();
    const invalidTokens = {
      'date',
      'exp',
      'expiry',
      'mfg',
      'mig',
      'mfd',
      'mrp',
      'price',
      'batch',
      'lot',
      'no',
      'none',
      'null',
      'not',
      'detected',
      'unreadable',
      'tablets',
      'tablet',
    };
    if (invalidTokens.contains(lower)) return false;
    if (lower.contains('date') ||
        lower.contains('mrp') ||
        lower.contains('exp')) {
      return false;
    }
    if (_looksLikeDate(clean)) return false;
    // Batch/LOT numbers must contain at least one digit and only alphanumeric/hyphen/slash characters
    if (!RegExp(r'\d').hasMatch(clean)) return false;
    if (!RegExp(r'^[A-Za-z0-9\-\/]+$').hasMatch(clean)) return false;
    return true;
  }

  static String _extractTrailingValue(String line, List<String> prefixes) {
    final lower = line.toLowerCase();
    for (final p in prefixes) {
      final idx = lower.indexOf(p);
      if (idx != -1) {
        final tail = line
            .substring(idx + p.length)
            .replaceAll(RegExp(r'^[ :\.\-#]+'), '')
            .trim();
        // Take first token before another label if multiple labels are on one line
        final splitOnNextLabel = tail
            .split(
              RegExp(
                r'\b(?:mfg|mig|mfd|exp|expiry|mrp|price)\b',
                caseSensitive: false,
              ),
            )
            .first
            .trim();
        if (splitOnNextLabel.isNotEmpty) return splitOnNextLabel;
      }
    }
    return '';
  }

  static bool _looksLikeDate(String text) {
    final clean = text.trim();
    return RegExp(
          r'^(?:0?[1-9]|1[0-2])[\/\-](?:20\d{2}|\d{2})$',
        ).hasMatch(clean) ||
        RegExp(r'^(?:20\d{2})[\/\-](?:0?[1-9]|1[0-2])$').hasMatch(clean) ||
        RegExp(
          r'^(?:0?[1-9]|[12]\d|3[01])[\/\-](?:0?[1-9]|1[0-2])[\/\-](?:20\d{2}|\d{2})$',
        ).hasMatch(clean) ||
        RegExp(
          r'^(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\/\-]*(?:20\d{2}|\d{2})$',
          caseSensitive: false,
        ).hasMatch(clean);
  }

  static String _formatDate(String rawDate) {
    final clean = rawDate.trim();
    final monthNames = {
      'jan': '01',
      'feb': '02',
      'mar': '03',
      'apr': '04',
      'may': '05',
      'jun': '06',
      'jul': '07',
      'aug': '08',
      'sep': '09',
      'oct': '10',
      'nov': '11',
      'dec': '12',
    };

    final alphaMatch = RegExp(
      r'^([a-zA-Z]{3})[a-zA-Z]*[\s\/\-]*(20\d{2}|\d{2})$',
    ).firstMatch(clean);
    if (alphaMatch != null) {
      final mKey = alphaMatch.group(1)!.toLowerCase();
      var year = alphaMatch.group(2)!;
      if (year.length == 2) year = '20$year';
      final month = monthNames[mKey];
      if (month != null) return '$month/$year';
    }

    final normalized = clean.replaceAll('-', '/');
    final parts = normalized.split('/');
    if (parts.length == 2) {
      // Check if YYYY/MM vs MM/YYYY
      if (parts[0].length == 4) {
        final year = parts[0];
        final month = parts[1].padLeft(2, '0');
        return '$month/$year';
      }
      final month = parts[0].padLeft(2, '0');
      var year = parts[1];
      if (year.length == 2) {
        year = '20$year';
      }
      return '$month/$year';
    } else if (parts.length == 3) {
      final month = parts[1].padLeft(2, '0');
      var year = parts[2];
      if (year.length == 2) {
        year = '20$year';
      }
      return '$month/$year';
    }
    return rawDate;
  }

  /// Parses an expiry string (e.g. "04/2027", "04-27", "Dec 2026", "2025-11")
  /// into the last moment of the expiry month, or null if invalid/unreadable.
  static DateTime? parseExpiryDate(String rawExpiry) {
    if (rawExpiry.trim().isEmpty) return null;
    final formatted = _formatDate(rawExpiry.trim());
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(20\d{2})$').firstMatch(formatted);
    if (match == null) return null;
    final month = int.tryParse(match.group(1)!);
    final year = int.tryParse(match.group(2)!);
    if (month == null || year == null || year < 2000 || year > 2100) {
      return null;
    }
    // Medicine expires at the end of the printed month
    return DateTime(year, month + 1, 0, 23, 59, 59);
  }

  /// Validates an expiry string against [now] (defaults to DateTime.now()).
  static ({bool? isExpired, String message, DateTime? expiryDate})
  validateExpiryDate(String rawExpiry, {DateTime? now}) {
    if (rawExpiry.trim().isEmpty) {
      return (isExpired: null, message: 'Not detected', expiryDate: null);
    }
    final parsed = parseExpiryDate(rawExpiry);
    if (parsed == null) {
      return (
        isExpired: null,
        message: 'Unrecognized date format ($rawExpiry)',
        expiryDate: null,
      );
    }
    final current = now ?? DateTime.now();
    if (parsed.isBefore(current)) {
      return (
        isExpired: true,
        message: 'EXPIRED (${_formatDate(rawExpiry)})',
        expiryDate: parsed,
      );
    }
    return (
      isExpired: false,
      message: 'Valid until ${_formatDate(rawExpiry)}',
      expiryDate: parsed,
    );
  }
}
