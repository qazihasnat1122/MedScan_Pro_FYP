import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';

/// Scored medicine candidate returned by [MedicineLookupRepository.rankMedicineCandidates].
class RankedMedicineMatch {
  final MedicineModel medicine;
  final double score;
  final String
  matchType; // 'exact_brand', 'fuzzy_brand', 'generic_salt', 'identifier'

  const RankedMedicineMatch({
    required this.medicine,
    required this.score,
    required this.matchType,
  });
}

class SameSaltCandidate {
  final MedicineModel medicine;
  final bool isExactBioequivalent;
  final String evidenceSource;

  const SameSaltCandidate({
    required this.medicine,
    required this.isExactBioequivalent,
    required this.evidenceSource,
  });
}

class SameSaltResult {
  final String searchedQuery;
  final String activeSalt;
  final MedicineModel? sourceMedicine;
  final List<SameSaltCandidate> exactMatches;
  final List<SameSaltCandidate> otherFormulations;

  const SameSaltResult({
    required this.searchedQuery,
    required this.activeSalt,
    this.sourceMedicine,
    this.exactMatches = const [],
    this.otherFormulations = const [],
  });

  bool get isEmpty => exactMatches.isEmpty && otherFormulations.isEmpty;
  int get totalCount => exactMatches.length + otherFormulations.length;
}

class MedicineLookupRepository {
  final FirebaseFirestore? _customFirestore;
  MedicineLookupRepository([this._customFirestore]);

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static List<MedicineModel> get staticReferenceMedicines =>
      _referenceMedicines;

  static final RegExp _urlOrDomainRegex = RegExp(
    r'(?:https?:\/\/|www\.|[a-z0-9\-]+\.(?:com|pk|net|org|io|co|edu|gov|info|biz|shop|store|online)\b)',
    caseSensitive: false,
  );

  static final List<MedicineModel> _referenceMedicines = [
    MedicineModel(
      medicineId: 'med_panadol_500',
      manufacturerId: 'mfg_gsk',
      companyName: 'GlaxoSmithKline (GSK) Pakistan',
      brandName: 'Panadol',
      medicineName: 'Panadol 500mg',
      genericName: 'Paracetamol',
      strength: '500mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 001234',
      referencePrice: 35.0,
      description:
          'Analgesic and antipyretic for mild to moderate pain and fever.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_calpol_500',
      manufacturerId: 'mfg_gsk',
      companyName: 'GlaxoSmithKline (GSK) Pakistan',
      brandName: 'Calpol',
      medicineName: 'Calpol 500mg',
      genericName: 'Paracetamol',
      strength: '500mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 001235',
      referencePrice: 32.0,
      description:
          'Alternative paracetamol formulation for pain and pyrexia relief.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_disprin_300',
      manufacturerId: 'mfg_reckitt',
      companyName: 'Reckitt Benckiser Pakistan',
      brandName: 'Disprin',
      medicineName: 'Disprin 300mg',
      genericName: 'Aspirin',
      strength: '300mg',
      dosageForm: 'Dispersible Tablet',
      registrationInfo: 'Reg # 001291',
      referencePrice: 40.0,
      description:
          'Dispersible aspirin 300mg tablet for fast relief of headache, toothache, fever, and inflammation.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_disprol_500',
      manufacturerId: 'mfg_reckitt',
      companyName: 'Reckitt Benckiser Pakistan',
      brandName: 'Disprol',
      medicineName: 'Disprol 500mg',
      genericName: 'Paracetamol',
      strength: '500mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 001290',
      referencePrice: 30.0,
      description: 'Soluble paracetamol pain relief tablet.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_augmentin_625',
      manufacturerId: 'mfg_gsk',
      companyName: 'GlaxoSmithKline (GSK) Pakistan',
      brandName: 'Augmentin',
      medicineName: 'Augmentin 625mg',
      genericName: 'Amoxicillin + Clavulanic Acid',
      strength: '625mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 005678',
      referencePrice: 280.0,
      description: 'Broad-spectrum antibacterial medication.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_curam_625',
      manufacturerId: 'mfg_sandoz',
      companyName: 'Sandoz Novartis Pakistan',
      brandName: 'Curam',
      medicineName: 'Curam 625mg',
      genericName: 'Amoxicillin + Clavulanic Acid',
      strength: '625mg',
      dosageForm: 'Film-Coated Tablet',
      registrationInfo: 'Reg # 005699',
      referencePrice: 270.0,
      description:
          'Alternative co-amoxiclav formulation for bacterial infections.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_glucophage_500',
      manufacturerId: 'mfg_merck',
      companyName: 'Merck Marker (Pvt) Ltd.',
      brandName: 'Glucophage',
      medicineName: 'Glucophage 500mg',
      genericName: 'Metformin Hydrochloride',
      strength: '500mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 009876',
      referencePrice: 160.0,
      description: 'Oral antidiabetic medication for Type 2 Diabetes.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_neodipar_500',
      manufacturerId: 'mfg_sanofi',
      companyName: 'Sanofi-Aventis Pakistan',
      brandName: 'Neodipar',
      medicineName: 'Neodipar 500mg',
      genericName: 'Metformin Hydrochloride',
      strength: '500mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 009880',
      referencePrice: 145.0,
      description:
          'Metformin antidiabetic formula for blood glucose management.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_dianic_50',
      manufacturerId: 'mfg_novamed',
      companyName: 'NovaMed Pharmaceuticals (Pvt) Ltd.',
      brandName: 'Dianic',
      medicineName: 'Dianic 50mg',
      genericName: 'Diclofenac Sodium B.P.',
      strength: '50mg',
      dosageForm: 'Enteric Coated Tablet',
      registrationInfo: 'DRAP Reg # 021787',
      referencePrice: 417.0,
      packSize: "10x10's Tablets",
      description:
          'Non-steroidal anti-inflammatory drug (NSAID) for pain relief and inflammation.',
      status: 'approved',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2025, 4, 1),
    ),
    MedicineModel(
      medicineId: 'med_voltral_50',
      manufacturerId: 'mfg_novartis',
      companyName: 'Novartis Pharma Pakistan',
      brandName: 'Voltral',
      medicineName: 'Voltral 50mg',
      genericName: 'Diclofenac Sodium B.P.',
      strength: '50mg',
      dosageForm: 'Enteric Coated Tablet',
      registrationInfo: 'DRAP Reg # 021890',
      referencePrice: 435.0,
      packSize: "10x10's Tablets",
      description:
          'Anti-inflammatory diclofenac analgesic for arthritis and pain.',
      status: 'approved',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2025, 4, 1),
    ),
    MedicineModel(
      medicineId: 'med_brufen_400',
      manufacturerId: 'mfg_abbott',
      companyName: 'Abbott Laboratories Pakistan',
      brandName: 'Brufen',
      medicineName: 'Brufen 400mg',
      genericName: 'Ibuprofen',
      strength: '400mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 002310',
      referencePrice: 55.0,
      description: 'NSAID analgesic and anti-inflammatory tablet.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_risek_20',
      manufacturerId: 'mfg_getz',
      companyName: 'Getz Pharma',
      brandName: 'Risek',
      medicineName: 'Risek 20mg',
      genericName: 'Omeprazole',
      strength: '20mg',
      dosageForm: 'Capsule',
      registrationInfo: 'Reg # 019442',
      referencePrice: 310.0,
      description: 'Proton pump inhibitor for gastric acid reduction.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    MedicineModel(
      medicineId: 'med_flagyl_400',
      manufacturerId: 'mfg_sanofi',
      companyName: 'Sanofi-Aventis Pakistan',
      brandName: 'Flagyl',
      medicineName: 'Flagyl 400mg',
      genericName: 'Metronidazole',
      strength: '400mg',
      dosageForm: 'Tablet',
      registrationInfo: 'Reg # 003112',
      referencePrice: 65.0,
      description: 'Antibacterial and antiprotozoal agent.',
      status: 'approved',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
  ];

  /// True when [batchId] belongs to the sample batches compiled into the app
  /// (offline fallback). These are NOT live manufacturer-vault records and must
  /// never be treated as manufacturer-supported evidence.
  static bool isBundledSampleBatch(String batchId) =>
      _referenceBatches.any((b) => b.batchId == batchId);

  /// True when [medicineId] belongs to the local static reference table bundled
  /// in the app rather than a live verified registry document.
  static bool isBundledReferenceMedicine(String medicineId) =>
      _referenceMedicines.any((m) => m.medicineId == medicineId);

  static final List<BatchModel> _referenceBatches = [
    BatchModel(
      batchId: 'batch_b1024',
      medicineId: 'med_panadol_500',
      manufacturerId: 'mfg_gsk',
      batchNumber: 'B1024',
      manufacturingDate: DateTime(2024, 1, 1),
      expiryDate: DateTime(2027, 12, 31),
      status: 'active',
      identifiers: ['896400012345', 'B1024'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ),
    BatchModel(
      batchId: 'batch_ag302',
      medicineId: 'med_augmentin_625',
      manufacturerId: 'mfg_gsk',
      batchNumber: 'AG302',
      manufacturingDate: DateTime(2024, 5, 1),
      expiryDate: DateTime(2026, 11, 30),
      status: 'active',
      identifiers: ['AG302'],
      createdAt: DateTime(2024, 5, 1),
      updatedAt: DateTime(2024, 5, 1),
    ),
    BatchModel(
      batchId: 'batch_21787',
      medicineId: 'med_dianic_50',
      manufacturerId: 'mfg_novamed',
      batchNumber: '21787',
      manufacturingDate: DateTime(2025, 4, 1),
      expiryDate: DateTime(2027, 4, 30),
      status: 'active',
      identifiers: ['21787', '04-27'],
      createdAt: DateTime(2025, 4, 1),
      updatedAt: DateTime(2025, 4, 1),
    ),
  ];

  /// Ranks candidate medicines against [query], optional [genericSalt], [strength],
  /// and [extraCandidates] (from OCR lines). Never matches URLs or domains.
  Future<List<RankedMedicineMatch>> rankMedicineCandidates(
    String query, {
    String genericSalt = '',
    String strength = '',
    List<String> extraCandidates = const [],
  }) async {
    final allMeds = await _loadAllAvailableMedicines();
    final candidateQueries = <String>[
      if (query.trim().isNotEmpty) query.trim(),
      ...extraCandidates.map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];

    final scoredById = <String, RankedMedicineMatch>{};

    for (final med in allMeds) {
      double bestScore = 0.0;
      String bestType = 'none';

      for (var qIdx = 0; qIdx < candidateQueries.length; qIdx++) {
        final rawQ = candidateQueries[qIdx];
        if (_urlOrDomainRegex.hasMatch(rawQ)) continue;

        final scoreInfo = _scoreMedicineAgainstQuery(
          med,
          rawQ,
          genericSalt: genericSalt,
          strength: strength,
          isPrimaryQuery: qIdx == 0,
        );
        if (scoreInfo.score > bestScore) {
          bestScore = scoreInfo.score;
          bestType = scoreInfo.matchType;
        }
      }

      if (bestScore <= 0 && genericSalt.trim().isNotEmpty) {
        final saltScore = _scoreMedicineAgainstQuery(
          med,
          genericSalt.trim(),
          genericSalt: genericSalt,
          strength: strength,
          isPrimaryQuery: false,
        );
        if (saltScore.score > bestScore) {
          bestScore = saltScore.score;
          bestType = saltScore.matchType;
        }
      }

      if (bestScore >= 35.0) {
        scoredById[med.medicineId] = RankedMedicineMatch(
          medicine: med,
          score: bestScore,
          matchType: bestType,
        );
      }
    }

    final ranked = scoredById.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  Future<List<MedicineModel>> _loadAllAvailableMedicines() async {
    final db = _firestore;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('medicines')
            .get()
            .timeout(const Duration(seconds: 3));
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs
              .map((doc) => MedicineModel.fromMap(doc.data(), doc.id))
              .toList();
          final merged = <String, MedicineModel>{
            for (final m in _referenceMedicines) m.medicineId: m,
            for (final m in remote) m.medicineId: m,
          };
          return merged.values.toList();
        }
      } catch (_) {}
    }
    return _referenceMedicines;
  }

  RankedMedicineMatch _scoreMedicineAgainstQuery(
    MedicineModel med,
    String rawQuery, {
    String genericSalt = '',
    String strength = '',
    bool isPrimaryQuery = true,
  }) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty || _urlOrDomainRegex.hasMatch(q)) {
      return RankedMedicineMatch(medicine: med, score: 0, matchType: 'none');
    }

    final brand = med.brandName.trim().toLowerCase();
    final fullName = med.medicineName.trim().toLowerCase();
    final generic = med.genericName.trim().toLowerCase();
    final reg = med.registrationInfo.trim().toLowerCase();
    final medStrength = med.strength.trim().toLowerCase();

    // Strip strength/form tokens from query to isolate the brand token
    final qWithoutStrength = q
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%)\b'), '')
        .replaceAll(
          RegExp(
            r'\b(?:tablet|tablets|tab|capsule|capsules|cap|syrup|suspension|dispersible|soluble|enteric|coated|film)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    double score = 0;
    String matchType = 'none';

    // 1. Exact full medicine name or exact brand name match
    if (q == fullName ||
        (brand.isNotEmpty && (q == brand || qWithoutStrength == brand))) {
      score = 100.0;
      matchType = 'exact_brand';
    } else if (brand.isNotEmpty &&
        RegExp(r'\b' + RegExp.escape(brand) + r'\b').hasMatch(q)) {
      score = 92.0;
      matchType = 'exact_brand';
    } else if (reg.isNotEmpty &&
        q.length >= 4 &&
        (reg == q || reg.endsWith(q) || (q.contains(reg) && reg.length >= 5))) {
      score = 88.0;
      matchType = 'identifier';
    } else if (brand.isNotEmpty && qWithoutStrength.length >= 4) {
      // 2. Fuzzy brand match (Levenshtein similarity) for minor OCR character errors (e.g., Disprn -> Disprin, Panado1 -> Panadol)
      final tokens = qWithoutStrength.split(' ').where((t) => t.length >= 4);
      double bestSim = similarity(qWithoutStrength, brand);
      for (final tok in tokens) {
        final s = similarity(tok, brand);
        if (s > bestSim) bestSim = s;
      }
      if (bestSim >= 0.80) {
        score = 70.0 + (bestSim * 15.0);
        matchType = 'fuzzy_brand';
      } else if (bestSim >= 0.72 &&
          genericSalt.isNotEmpty &&
          generic.contains(genericSalt.toLowerCase().split(' ').first)) {
        // Slightly lower brand similarity boosted by matching generic salt
        score = 68.0;
        matchType = 'fuzzy_brand';
      }
    }

    // 3. Generic salt or company match when brand didn't match directly
    if (score == 0 && generic.isNotEmpty && q.length >= 4) {
      final cleanGeneric = generic
          .replaceAll(RegExp(r'\b(?:b\.?p\.?|u\.?s\.?p\.?)\b'), '')
          .trim();
      if (cleanGeneric == q ||
          cleanGeneric.contains(q) ||
          q.contains(cleanGeneric)) {
        score = 52.0;
        matchType = 'generic_salt';
      }
    }

    if (score > 0) {
      // Context bonuses / adjustments
      final effectiveStrength = strength.trim().toLowerCase();
      if (effectiveStrength.isNotEmpty && medStrength.isNotEmpty) {
        if (medStrength == effectiveStrength || q.contains(medStrength)) {
          score += 6.0;
        } else if (matchType == 'generic_salt') {
          score -= 10.0;
        }
      }
      if (!isPrimaryQuery) {
        score -= 3.0;
      }
    }

    return RankedMedicineMatch(
      medicine: med,
      score: score,
      matchType: matchType,
    );
  }

  /// Normalized Levenshtein similarity in `[0.0, 1.0]`.
  static double similarity(String a, String b) {
    final s1 = a.trim().toLowerCase();
    final s2 = b.trim().toLowerCase();
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    final dist = _levenshtein(s1, s2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        final del = dp[i - 1][j] + 1;
        final ins = dp[i][j - 1] + 1;
        final sub = dp[i - 1][j - 1] + cost;
        var minVal = del < ins ? del : ins;
        if (sub < minVal) minVal = sub;
        dp[i][j] = minVal;
      }
    }
    return dp[m][n];
  }

  Future<List<MedicineModel>> searchMedicines(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return _referenceMedicines;

    // Never match URLs or domain names as medicines
    if (_urlOrDomainRegex.hasMatch(cleanQuery)) {
      return [];
    }

    // 1. Check ranked brand/fuzzy/generic matches first
    final ranked = await rankMedicineCandidates(query);
    if (ranked.isNotEmpty) {
      return ranked.map((r) => r.medicine).toList();
    }

    // 2. Check Firestore batches or general substring fallback
    final db = _firestore;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('medicines')
            .get()
            .timeout(const Duration(seconds: 3));

        final allMeds = snapshot.docs
            .map((doc) => MedicineModel.fromMap(doc.data(), doc.id))
            .toList();

        final matches = allMeds
            .where((m) => _matchesMedicine(m, cleanQuery))
            .toList();
        if (matches.isNotEmpty) return matches;

        final batchSnap = await db
            .collection('batches')
            .get()
            .timeout(const Duration(seconds: 3));

        for (final doc in batchSnap.docs) {
          final b = BatchModel.fromMap(doc.data(), doc.id);
          final hasCode =
              b.batchNumber.toLowerCase() == cleanQuery ||
              b.identifiers.any(
                (id) =>
                    id.toLowerCase() == cleanQuery ||
                    id.toLowerCase().contains(cleanQuery),
              );

          if (hasCode) {
            final matchedMed = allMeds
                .where((m) => m.medicineId == b.medicineId)
                .toList();
            if (matchedMed.isNotEmpty) return matchedMed;
          }
        }
      } catch (_) {}
    }

    final refMatches = _referenceMedicines
        .where((m) => _matchesMedicine(m, cleanQuery))
        .toList();
    if (refMatches.isNotEmpty) return refMatches;

    for (final b in _referenceBatches) {
      final hasCode =
          b.batchNumber.toLowerCase() == cleanQuery ||
          b.identifiers.any(
            (id) =>
                id.toLowerCase() == cleanQuery ||
                id.toLowerCase().contains(cleanQuery),
          );
      if (hasCode) {
        final matched = _referenceMedicines
            .where((m) => m.medicineId == b.medicineId)
            .toList();
        if (matched.isNotEmpty) return matched;
      }
    }

    return [];
  }

  static String _cleanNorm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<SameSaltResult> findSameSaltAlternatives(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return const SameSaltResult(searchedQuery: '', activeSalt: '');
    }

    final all = await searchMedicines('');

    // 1. Check if the query matches a specific brand name or product name
    MedicineModel? sourceMed;
    for (final m in all) {
      if (m.brandName.toLowerCase() == clean ||
          m.medicineName.toLowerCase() == clean ||
          m.medicineName.toLowerCase().startsWith(clean)) {
        sourceMed = m;
        break;
      }
    }

    final targetSalt = sourceMed != null ? sourceMed.genericName : query.trim();
    final cleanSalt = targetSalt.toLowerCase();

    // 2. Find medicines that share the active generic ingredient
    final matchingMeds = all.where((m) {
      final gen = m.genericName.toLowerCase();
      return gen.contains(cleanSalt) || cleanSalt.contains(gen);
    }).toList();

    final exactMatches = <SameSaltCandidate>[];
    final otherFormulations = <SameSaltCandidate>[];

    for (final m in matchingMeds) {
      final evidence = m.registrationInfo.isNotEmpty
          ? ' • '
          : 'DRAP Registration Spec • ';

      final bool isExact;
      if (sourceMed != null) {
        final sameStrength =
            _cleanNorm(m.strength) == _cleanNorm(sourceMed.strength);
        final sameForm =
            _cleanNorm(m.dosageForm) == _cleanNorm(sourceMed.dosageForm);
        isExact = sameStrength && sameForm;
      } else {
        // If query was just a salt, treat standard 500mg tablets or majority matches as exact
        isExact = true;
      }

      final candidate = SameSaltCandidate(
        medicine: m,
        isExactBioequivalent: isExact,
        evidenceSource: evidence,
      );

      if (sourceMed != null && m.medicineId == sourceMed.medicineId) {
        // Keep source medicine visible but distinct or at front of exact
        continue;
      }

      if (isExact) {
        exactMatches.add(candidate);
      } else {
        otherFormulations.add(candidate);
      }
    }

    return SameSaltResult(
      searchedQuery: query,
      activeSalt: targetSalt,
      sourceMedicine: sourceMed,
      exactMatches: exactMatches,
      otherFormulations: otherFormulations,
    );
  }

  Future<List<MedicineModel>> findSameSaltMedicines(String query) async {
    final result = await findSameSaltAlternatives(query);
    final combined = <MedicineModel>[];
    for (final c in result.exactMatches) {
      combined.add(c.medicine);
    }
    for (final c in result.otherFormulations) {
      if (!combined.any((m) => m.medicineId == c.medicine.medicineId)) {
        combined.add(c.medicine);
      }
    }
    return combined;
  }

  bool _matchesMedicine(MedicineModel med, String query) {
    if (_urlOrDomainRegex.hasMatch(query)) return false;

    final name = med.medicineName.toLowerCase();
    final brand = med.brandName.toLowerCase();
    final generic = med.genericName.toLowerCase();
    final reg = med.registrationInfo.toLowerCase();
    final id = med.medicineId.toLowerCase();
    final company = med.companyName.toLowerCase();

    return name.contains(query) ||
        query.contains(name) ||
        (brand.isNotEmpty &&
            (brand.contains(query) || query.contains(brand))) ||
        (generic.isNotEmpty && generic.contains(query)) ||
        (reg.isNotEmpty && (reg.contains(query) || query.contains(reg))) ||
        (id.isNotEmpty && id.contains(query)) ||
        (company.isNotEmpty && company.contains(query));
  }

  Future<List<BatchModel>> searchBatches(
    String medicineId,
    String batchNumber,
  ) async {
    final cleanBatch = batchNumber.trim().toLowerCase();
    if (cleanBatch.isEmpty) return [];

    final db = _firestore;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('batches')
            .where('status', isEqualTo: 'active')
            .get()
            .timeout(const Duration(seconds: 3));

        final firestoreBatches = snapshot.docs
            .map((doc) => BatchModel.fromMap(doc.data(), doc.id))
            .toList();
        final matching = firestoreBatches.where((b) {
          final sameMed = b.medicineId == medicineId || medicineId.isEmpty;
          final sameBatch =
              b.batchNumber.toLowerCase() == cleanBatch ||
              b.identifiers.any(
                (id) =>
                    id.toLowerCase() == cleanBatch ||
                    id.toLowerCase().contains(cleanBatch),
              );
          return sameMed && sameBatch;
        }).toList();

        if (matching.isNotEmpty) return matching;
      } catch (_) {}
    }

    return _referenceBatches.where((b) {
      final sameMed = medicineId.isEmpty || b.medicineId == medicineId;
      final sameBatch =
          b.batchNumber.toLowerCase() == cleanBatch ||
          b.identifiers.any((id) => id.toLowerCase() == cleanBatch);
      return sameMed && sameBatch;
    }).toList();
  }
}
