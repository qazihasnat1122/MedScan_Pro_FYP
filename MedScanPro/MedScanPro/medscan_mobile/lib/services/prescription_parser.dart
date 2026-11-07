import '../providers/scan_providers.dart';
import '../models/medicine_model.dart';
import '../repositories/medicine_lookup_repository.dart';

/// Structured clinical medicine entity extracted from a doctor's prescription.
/// Missing or unclear values remain empty (`''` / `durationDays: 0`) and are
/// marked for user review (`isConfirmed = false`). Never invents medicine names,
/// doses, clock times, or durations.
class PrescriptionMedicineItem {
  String id;
  String medicineName;
  String brand;
  String strength;
  String dosageInstructions;
  String route;
  String dosageForm;
  String frequency;
  String timing;
  String duration;
  int durationDays;
  String quantity;
  String prescriptionDate;
  String specialInstructions;
  List<String> uncertainFields;
  FieldConfidence confidence;
  bool isConfirmed;

  PrescriptionMedicineItem({
    required this.id,
    required this.medicineName,
    this.brand = '',
    required this.strength,
    this.dosageInstructions = '',
    String? route,
    String? dosageForm,
    required this.frequency,
    this.timing = '',
    String? duration,
    this.durationDays = 0,
    this.quantity = '',
    this.prescriptionDate = '',
    this.specialInstructions = '',
    List<String>? uncertainFields,
    this.confidence = FieldConfidence.medium,
    this.isConfirmed = false,
  }) : route = route ?? dosageForm ?? '',
       dosageForm = dosageForm ?? route ?? '',
       duration = duration ?? (durationDays > 0 ? '$durationDays days' : ''),
       uncertainFields = uncertainFields ?? const [];

  /// Returns the list of critical or optional fields that are missing or flagged uncertain.
  List<String> get missingOrUncertainFields {
    final fields = <String>{...uncertainFields};
    if (medicineName.trim().isEmpty ||
        medicineName.toLowerCase().startsWith('prescribed medicine') ||
        medicineName.toLowerCase() == 'unknown') {
      fields.add('medicineName');
    }
    if (strength.trim().isEmpty || strength.toLowerCase() == 'as directed') {
      fields.add('strength');
    }
    if (dosageInstructions.trim().isEmpty &&
        route.trim().isEmpty &&
        dosageForm.trim().isEmpty) {
      fields.add('dosageInstructions');
    }
    if (frequency.trim().isEmpty || frequency.toLowerCase() == 'as directed') {
      fields.add('frequency');
    }
    if (duration.trim().isEmpty && durationDays <= 0) {
      fields.add('duration');
    }
    return fields.toList();
  }

  /// True if critical fields are missing or confidence is not high.
  bool get needsReview =>
      !isConfirmed ||
      confidence != FieldConfidence.high ||
      medicineName.trim().isEmpty ||
      strength.trim().isEmpty ||
      frequency.trim().isEmpty ||
      (duration.trim().isEmpty && durationDays <= 0) ||
      uncertainFields.isNotEmpty;

  /// True if the prescription instructs "as needed" / PRN / SOS usage.
  /// Repeating fixed alarms must NOT be auto-created for PRN medications.
  bool get isPrnOrAsNeeded {
    final combined =
        '$frequency $dosageInstructions $specialInstructions $timing'
            .toLowerCase();
    return RegExp(
      r'\b(prn|s\.?o\.?s\.?|as needed|when needed|when required|if needed|for pain only|for fever only)\b',
    ).hasMatch(combined);
  }

  /// True if the schedule is tapering, variable, or ambiguous.
  bool get isAmbiguousOrTaperingSchedule {
    if (frequency.trim().isEmpty) return true;
    final combined = '$frequency $dosageInstructions $specialInstructions'
        .toLowerCase();
    return RegExp(
      r'\b(taper|tapering|gradually|reduce|decreasing|alternate days|every other day|as directed|variable|consult doctor)\b',
    ).hasMatch(combined);
  }

  /// Infers how many daily clock times the user should pick for a standard daily schedule,
  /// WITHOUT assuming what those exact clock times are. Returns null if PRN or ambiguous.
  int? get expectedDailyDoseCount {
    if (isPrnOrAsNeeded || isAmbiguousOrTaperingSchedule) return null;
    final f = frequency.toLowerCase().trim();
    if (RegExp(
      r'(\b1\s*[-+]\s*1\s*[-+]\s*1\s*[-+]\s*1\b|\bfour times\b|\bqid\b|\b4 times\b|\bevery 6 hours\b)',
    ).hasMatch(f)) {
      return 4;
    }
    if (RegExp(
      r'(\b1\s*[-+]\s*1\s*[-+]\s*1\b|\bthrice\b|\bthree times\b|\btds\b|\btid\b|\b3 times\b|\bevery 8 hours\b)',
    ).hasMatch(f)) {
      return 3;
    }
    if (RegExp(
      r'(\b1\s*[-+]\s*0\s*[-+]\s*1\b|\btwice\b|\bbd\b|\bbid\b|\b2 times\b|\bevery 12 hours\b)',
    ).hasMatch(f)) {
      return 2;
    }
    if (RegExp(
      r'(\b1\s*[-+]\s*0\s*[-+]\s*0\b|\b0\s*[-+]\s*0\s*[-+]\s*1\b|\bonce\b|\bod\b|\bhs\b|\bdaily\b|\b1 time\b|\bat bedtime\b|\bevery 24 hours\b)',
    ).hasMatch(f)) {
      return 1;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_name': medicineName,
      'brand': brand,
      'strength': strength,
      'dosage_instructions': dosageInstructions,
      'route': route,
      'dosage_form': dosageForm.isNotEmpty ? dosageForm : route,
      'frequency': frequency,
      'timing': timing,
      'duration': duration,
      'duration_days': durationDays,
      'quantity': quantity,
      'prescription_date': prescriptionDate,
      'special_instructions': specialInstructions,
      'uncertain_fields': uncertainFields,
      'confidence': confidence.name,
      'is_confirmed': isConfirmed,
    };
  }

  /// Parses structured JSON output (from Gemini or stored Firestore map) WITHOUT
  /// inventing defaults for missing medicine names, strengths, frequencies, or durations.
  factory PrescriptionMedicineItem.fromMap(
    Map<String, dynamic> map, {
    String? id,
    String defaultPrescriptionDate = '',
  }) {
    String cleanStr(dynamic value) {
      if (value == null) return '';
      final s = value.toString().trim();
      if (s.toLowerCase() == 'null' ||
          s.toLowerCase() == 'unknown' ||
          s.toLowerCase() == 'n/a' ||
          s.toLowerCase() == 'none') {
        return '';
      }
      return s;
    }

    final medicineName = cleanStr(map['medicineName'] ?? map['medicine_name']);
    final brand = cleanStr(
      map['brand'] ?? map['brandName'] ?? map['brand_name'],
    );
    final strength = cleanStr(map['strength']);
    final dosageInstructions = cleanStr(
      map['dosageInstructions'] ?? map['dosage_instructions'],
    );
    final route = cleanStr(
      map['route'] ?? map['dosageForm'] ?? map['dosage_form'],
    );
    final frequency = cleanStr(map['frequency']);
    final timing = cleanStr(map['timing']);
    final durationText = cleanStr(map['duration']);
    final quantity = cleanStr(map['quantity']);
    final prescriptionDate = cleanStr(
      map['prescriptionDate'] ??
          map['prescription_date'] ??
          defaultPrescriptionDate,
    );
    final specialInstructions = cleanStr(
      map['specialInstructions'] ?? map['special_instructions'],
    );

    int parsedDurationDays = 0;
    final rawDurationDays = map['durationDays'] ?? map['duration_days'];
    if (rawDurationDays != null) {
      parsedDurationDays = int.tryParse(rawDurationDays.toString()) ?? 0;
    }
    if (parsedDurationDays <= 0 && durationText.isNotEmpty) {
      final match = RegExp(
        r'(\d+)\s*(day|wk|week|month)',
        caseSensitive: false,
      ).firstMatch(durationText);
      if (match != null) {
        final count = int.tryParse(match.group(1)!) ?? 0;
        final unit = match.group(2)!.toLowerCase();
        if (unit.startsWith('wk') || unit.startsWith('week')) {
          parsedDurationDays = count * 7;
        } else if (unit.startsWith('month')) {
          parsedDurationDays = count * 30;
        } else {
          parsedDurationDays = count;
        }
      }
    }

    final rawUncertain = map['uncertainFields'] ?? map['uncertain_fields'];
    final uncertain = <String>[];
    if (rawUncertain is List) {
      for (final e in rawUncertain) {
        final s = cleanStr(e);
        if (s.isNotEmpty) uncertain.add(s);
      }
    }

    if (medicineName.isEmpty) {
      uncertain.add('medicineName');
    }
    if (strength.isEmpty) {
      uncertain.add('strength');
    }
    if (frequency.isEmpty) {
      uncertain.add('frequency');
    }
    if (durationText.isEmpty && parsedDurationDays <= 0) {
      uncertain.add('duration');
    }

    final rawConf = map['confidence'];
    final confStr = cleanStr(rawConf).toLowerCase();
    final confNum = rawConf is num
        ? rawConf.toDouble()
        : double.tryParse(confStr);
    FieldConfidence confidence;
    if ((confStr == 'high' || (confNum != null && confNum >= 0.8)) &&
        uncertain.isEmpty) {
      confidence = FieldConfidence.high;
    } else if (confStr == 'low' ||
        (confNum != null && confNum < 0.5) ||
        medicineName.isEmpty) {
      confidence = FieldConfidence.low;
    } else {
      confidence = FieldConfidence.medium;
    }

    final explicitlyConfirmed =
        map['is_confirmed'] == true || map['isConfirmed'] == true;

    return PrescriptionMedicineItem(
      id:
          id ??
          (cleanStr(map['id']).isNotEmpty
              ? cleanStr(map['id'])
              : 'rx_${DateTime.now().microsecondsSinceEpoch}'),
      medicineName: medicineName,
      brand: brand,
      strength: strength,
      dosageInstructions: dosageInstructions,
      route: route,
      dosageForm: route,
      frequency: frequency,
      timing: timing,
      duration: durationText.isNotEmpty
          ? durationText
          : (parsedDurationDays > 0 ? '$parsedDurationDays days' : ''),
      durationDays: parsedDurationDays,
      quantity: quantity,
      prescriptionDate: prescriptionDate,
      specialInstructions: specialInstructions,
      uncertainFields: uncertain.toSet().toList(),
      confidence: confidence,
      // Raw Gemini extraction must never be auto-marked confirmed if fields are missing/uncertain
      isConfirmed: explicitlyConfirmed && uncertain.isEmpty,
    );
  }

  PrescriptionMedicineItem copyWith({
    String? id,
    String? medicineName,
    String? brand,
    String? strength,
    String? dosageInstructions,
    String? route,
    String? dosageForm,
    String? frequency,
    String? timing,
    String? duration,
    int? durationDays,
    String? quantity,
    String? prescriptionDate,
    String? specialInstructions,
    List<String>? uncertainFields,
    FieldConfidence? confidence,
    bool? isConfirmed,
  }) {
    return PrescriptionMedicineItem(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      brand: brand ?? this.brand,
      strength: strength ?? this.strength,
      dosageInstructions: dosageInstructions ?? this.dosageInstructions,
      route: route ?? dosageForm ?? this.route,
      dosageForm: dosageForm ?? route ?? this.dosageForm,
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      duration: duration ?? this.duration,
      durationDays: durationDays ?? this.durationDays,
      quantity: quantity ?? this.quantity,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      uncertainFields: uncertainFields ?? this.uncertainFields,
      confidence: confidence ?? this.confidence,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

/// On-device fallback Prescription Parser & Clinical Noise Filter.
/// STRICTLY IGNORES: Doctor names, clinic/hospital headers, qualifications (MBBS, FCPS),
/// phone numbers, addresses, and lab notices.
/// STRICTLY EXTRACTS: Structured medicines without inventing unknown values.
class PrescriptionParser {
  static final RegExp _doctorHeaderRegex = RegExp(
    r'\b(dr\.?|prof\.?|doctor|physician|surgeon|consultant|mbbs|fcps|mcps|frcp|mrcp|m\.d\.|ph\.d|pmdc|pmc)\b',
    caseSensitive: false,
  );

  static final RegExp _hospitalHeaderRegex = RegExp(
    r'\b(hospital|clinic|dispensary|medical center|health care|healthcare|memorial|complex|department of|opd|emergency|ward|room no|bed no)\b',
    caseSensitive: false,
  );

  static final RegExp _patientDemographicsRegex = RegExp(
    r'\b(patient name|pt name|name:|age:|gender:|sex:|male|female|years?|yrs?|weight:|wt:|mr no|reg no|receipt no|token no|date:)\b',
    caseSensitive: false,
  );

  static final RegExp _contactRegex = RegExp(
    r'(\+?92\s?\d{3}|\b03\d{2}[-\s]?\d{7}\b|ph:|phone:|tel:|mob:|email:|www\.|\.com|\.pk)',
    caseSensitive: false,
  );

  static final RegExp _disclaimerRegex = RegExp(
    r'\b(not valid for court|signature|stamp|seal|dispensed by|follow up after|bring this card|fees?|charges?|pharmacist signature)\b',
    caseSensitive: false,
  );

  static final RegExp _strengthRegex = RegExp(
    r'(\b\d+(\.\d+)?\s*(mg|ml|mcg|gm?|iu|units?)\b)',
    caseSensitive: false,
  );

  static final RegExp _formRegex = RegExp(
    r'\b(tab(let)?|cap(sule)?|syp(rup)?|inj(ection)?|drop(s)?|oint(ment)?|cream|gel|susp(ension)?|inhaler|patch)\b',
    caseSensitive: false,
  );

  static final RegExp _frequencyRegex = RegExp(
    r'(\b[0-3]\s*[-+]\s*[0-3]\s*[-+]\s*[0-3]\b|\b(once|twice|thrice|three times|four times)\s+daily\b|\b(od|bd|tds|qid|sos|prn|hs|stat)\b|\bevery\s+\d+\s+hours?\b|\bas needed\b)',
    caseSensitive: false,
  );

  static final RegExp _timingRegex = RegExp(
    r'\b(before meals?|after meals?|with food|empty stomach|at bedtime|morning|night|ac|pc)\b',
    caseSensitive: false,
  );

  static final RegExp _durationRegex = RegExp(
    r'(\b\d+\s*(days?|wks?|weeks?|months?)\b|\bx\s*\d+\s*(days?|wks?)?)',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b',
  );

  /// Extracts visible prescription date if present in raw text.
  static String extractPrescriptionDate(String rawOcrText) {
    final match = _dateRegex.firstMatch(rawOcrText);
    return match?.group(0) ?? '';
  }

  /// Filters non-drug text and extracts structured medicine items from OCR output.
  static List<PrescriptionMedicineItem> parse(String rawOcrText) {
    if (rawOcrText.trim().isEmpty) return [];

    final rxDate = extractPrescriptionDate(rawOcrText);
    final List<PrescriptionMedicineItem> items = [];
    final lines = rawOcrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_isHeaderOrDemographicNoise(line)) {
        continue;
      }

      final hasDosageOrForm =
          _strengthRegex.hasMatch(line) || _formRegex.hasMatch(line);
      final hasFrequency = _frequencyRegex.hasMatch(line);

      if (hasDosageOrForm || hasFrequency || _isLikelyMedicineName(line)) {
        String combinedChunk = line;
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          if (!_isHeaderOrDemographicNoise(nextLine) &&
              (_frequencyRegex.hasMatch(nextLine) ||
                  _timingRegex.hasMatch(nextLine) ||
                  _durationRegex.hasMatch(nextLine))) {
            combinedChunk += ' $nextLine';
            i++;
          }
        }

        final item = _extractMedicineFromChunk(
          combinedChunk,
          items.length,
          prescriptionDate: rxDate,
        );
        if (item != null) {
          items.add(item);
        }
      }
    }

    return items;
  }

  static bool _isHeaderOrDemographicNoise(String line) {
    if (line.length < 3) return true;
    if (_doctorHeaderRegex.hasMatch(line)) return true;
    if (_hospitalHeaderRegex.hasMatch(line)) return true;
    if (_patientDemographicsRegex.hasMatch(line)) return true;
    if (_contactRegex.hasMatch(line)) return true;
    if (_disclaimerRegex.hasMatch(line)) return true;
    return false;
  }

  static bool _isLikelyMedicineName(String line) {
    final lower = line.toLowerCase();
    for (final med in MedicineLookupRepository.staticReferenceMedicines) {
      if (med.brandName.isNotEmpty &&
          lower.contains(med.brandName.toLowerCase())) {
        return true;
      }
      if (med.genericName.isNotEmpty &&
          lower.contains(med.genericName.toLowerCase())) {
        return true;
      }
    }
    const knownDrugs = [
      'panadol',
      'augmentin',
      'amoxicillin',
      'brufen',
      'paracetamol',
      'ciprofloxacin',
      'metformin',
      'glucophage',
      'omeprazole',
      'risek',
      'flagyl',
      'arinate',
      'klaricid',
      'cefixime',
      'ceftriaxone',
      'azithromycin',
      'azomax',
      'lexotanil',
      'xanax',
      'disprin',
      'lipitor',
      'atorvastatin',
      'concor',
      'norvasc',
      'amladipine',
      'ventolin',
      'synflex',
      'dianic',
      'calpol',
      'disprol',
      'curam',
      'sitagliptin',
      'empagliflozin',
      'pantoprazole',
    ];
    return knownDrugs.any((drug) => lower.contains(drug));
  }

  static MedicineModel? _findReferenceMatch(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.length < 3) return null;
    for (final med in MedicineLookupRepository.staticReferenceMedicines) {
      if (med.brandName.isNotEmpty &&
          (lower.contains(med.brandName.toLowerCase()) ||
              med.brandName.toLowerCase().contains(lower))) {
        return med;
      }
      if (med.genericName.isNotEmpty &&
          (lower.contains(med.genericName.toLowerCase()) ||
              med.genericName.toLowerCase().contains(lower))) {
        return med;
      }
    }
    return null;
  }

  static PrescriptionMedicineItem? _extractMedicineFromChunk(
    String chunk,
    int index, {
    String prescriptionDate = '',
  }) {
    String name = '';
    String brand = '';
    String strength = '';
    String dosageForm = '';
    String frequency = '';
    String timing = '';
    String durationText = '';
    int duration = 0;
    final uncertainFields = <String>[];
    FieldConfidence confidence = FieldConfidence.high;

    // Extract Strength
    final strengthMatch = _strengthRegex.firstMatch(chunk);
    if (strengthMatch != null) {
      strength = strengthMatch.group(0)!;
    } else {
      uncertainFields.add('strength');
      confidence = FieldConfidence.medium;
    }

    // Extract Form / Route
    final formMatch = _formRegex.firstMatch(chunk);
    if (formMatch != null) {
      final f = formMatch.group(0)!.toLowerCase();
      if (f.startsWith('tab')) {
        dosageForm = 'Tablet';
      } else if (f.startsWith('cap')) {
        dosageForm = 'Capsule';
      } else if (f.startsWith('syp')) {
        dosageForm = 'Syrup';
      } else if (f.startsWith('inj')) {
        dosageForm = 'Injection';
      } else if (f.startsWith('drop')) {
        dosageForm = 'Drops';
      } else if (f.startsWith('susp')) {
        dosageForm = 'Suspension';
      } else {
        dosageForm = formMatch.group(0)!;
      }
    }

    // Extract Frequency
    final freqMatch = _frequencyRegex.firstMatch(chunk);
    if (freqMatch != null) {
      final rawFreq = freqMatch.group(0)!.toUpperCase().replaceAll(' ', '');
      if (rawFreq.contains('1-0-1') ||
          rawFreq.contains('1+0+1') ||
          rawFreq == 'BD') {
        frequency = '1-0-1 (Twice daily)';
      } else if (rawFreq.contains('1-1-1') ||
          rawFreq.contains('1+1+1') ||
          rawFreq == 'TDS') {
        frequency = '1-1-1 (Three times daily)';
      } else if (rawFreq.contains('1-0-0') || rawFreq == 'OD') {
        frequency = '1-0-0 (Once daily morning)';
      } else if (rawFreq.contains('0-0-1') || rawFreq == 'HS') {
        frequency = '0-0-1 (At bedtime)';
      } else {
        frequency = freqMatch.group(0)!;
      }
    } else {
      uncertainFields.add('frequency');
      confidence = FieldConfidence.medium;
    }

    // Extract Timing
    final timingMatch = _timingRegex.firstMatch(chunk);
    if (timingMatch != null) {
      final t = timingMatch.group(0)!.toLowerCase();
      if (t.contains('before') || t == 'ac' || t.contains('empty')) {
        timing = 'Before meal';
      } else if (t.contains('after') || t == 'pc') {
        timing = 'After meal';
      } else if (t.contains('bedtime')) {
        timing = 'At bedtime';
      } else {
        timing = 'With food';
      }
    }

    // Extract Duration (never invent 5 days if not written!)
    final durationMatch = _durationRegex.firstMatch(chunk);
    if (durationMatch != null) {
      durationText = durationMatch.group(0)!.trim();
      final digits = RegExp(r'\d+').firstMatch(durationText);
      if (digits != null) {
        duration = int.tryParse(digits.group(0)!) ?? 0;
        if (durationText.toLowerCase().contains('wk') ||
            durationText.toLowerCase().contains('week')) {
          duration *= 7;
        } else if (durationText.toLowerCase().contains('month')) {
          duration *= 30;
        }
      }
    } else {
      uncertainFields.add('duration');
      if (confidence == FieldConfidence.high) {
        confidence = FieldConfidence.medium;
      }
    }

    // Clean Medicine Name: remove recognized dosage, form, freq, timing tokens
    String cleaned = chunk;
    if (strengthMatch != null) {
      cleaned = cleaned.replaceFirst(strengthMatch.group(0)!, '');
    }
    if (formMatch != null) {
      cleaned = cleaned.replaceFirst(formMatch.group(0)!, '');
    }
    if (freqMatch != null) {
      cleaned = cleaned.replaceFirst(freqMatch.group(0)!, '');
    }
    if (timingMatch != null) {
      cleaned = cleaned.replaceFirst(timingMatch.group(0)!, '');
    }
    if (durationMatch != null) {
      cleaned = cleaned.replaceFirst(durationMatch.group(0)!, '');
    }

    cleaned = cleaned.replaceAll(
      RegExp(r'^(rx|#|\*|\d+\.|\-)\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s\-]'), ' ').trim();

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    if (words.isNotEmpty) {
      final rawExtracted = words.take(3).join(' ');
      final matchedRef = _findReferenceMatch(rawExtracted);
      if (matchedRef != null) {
        name = matchedRef.brandName.isNotEmpty
            ? matchedRef.brandName
            : matchedRef.medicineName;
        brand = matchedRef.brandName;
      } else {
        name = rawExtracted
            .split(' ')
            .map(
              (w) => w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                  : '',
            )
            .join(' ');
        uncertainFields.add('medicineName');
        confidence = FieldConfidence.low;
      }
    } else {
      name = '';
      uncertainFields.add('medicineName');
      confidence = FieldConfidence.low;
    }

    return PrescriptionMedicineItem(
      id: 'rx_${DateTime.now().millisecondsSinceEpoch}_$index',
      medicineName: name,
      brand: brand,
      strength: strength,
      dosageInstructions: dosageForm.isNotEmpty ? '1 $dosageForm' : '',
      route: dosageForm,
      dosageForm: dosageForm,
      frequency: frequency,
      timing: timing,
      duration: durationText,
      durationDays: duration,
      prescriptionDate: prescriptionDate,
      uncertainFields: uncertainFields,
      confidence: confidence,
      // Require user confirmation on the review screen before saving
      isConfirmed: false,
    );
  }
}
