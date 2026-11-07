import '../models/user_medication_model.dart';
import '../models/medicine_model.dart';

class ClinicalService {
  static const Map<String, String> _brandToSaltMap = {
    'panadol': 'paracetamol',
    'calpol': 'paracetamol',
    'disprol': 'paracetamol',
    'paracetamol': 'paracetamol',
    'brufen': 'ibuprofen',
    'ibuprofen': 'ibuprofen',
    'aspirin': 'aspirin',
    'disprin': 'aspirin',
    'warfarin': 'warfarin',
    'coumadin': 'warfarin',
    'glucophage': 'metformin',
    'metformin': 'metformin',
    'cipro': 'ciprofloxacin',
    'novidat': 'ciprofloxacin',
    'ciprofloxacin': 'ciprofloxacin',
    'augmentin': 'amoxicillin_clavulanic',
    'amoxicillin': 'amoxicillin',
    'risek': 'omeprazole',
    'omez': 'omeprazole',
    'omeprazole': 'omeprazole',
  };

  String? _resolveSalt(String medName) {
    final lower = medName.toLowerCase();
    for (final entry in _brandToSaltMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Screen for drug-drug interactions, duplicate active salts, and incomplete data.
  List<String> checkInteractions(List<UserMedicationModel> meds) {
    if (meds.length < 2) return [];

    final List<String> warnings = [];
    final List<String> detectedSalts = [];
    final List<String> unmappedNames = [];

    for (final m in meds) {
      final salt = _resolveSalt(m.name);
      if (salt != null) {
        detectedSalts.add(salt);
      } else {
        unmappedNames.add(m.name);
      }
    }

    // 1. Duplicate Active Ingredient Toxicity Check
    final saltCounts = <String, int>{};
    for (final s in detectedSalts) {
      saltCounts[s] = (saltCounts[s] ?? 0) + 1;
    }
    saltCounts.forEach((salt, count) {
      if (count > 1) {
        final formattedSalt = salt.replaceAll('_', ' ').toUpperCase();
        warnings.add(
          '⚠️ Duplicate Active Salt Alert ($formattedSalt): You have $count medications containing $formattedSalt. Taking multiple products with the same active ingredient increases the risk of toxicity.',
        );
      }
    });

    // 2. Clinical Interaction Pairs
    final saltSet = detectedSalts.toSet();

    // Aspirin + Warfarin (Major Bleeding Risk)
    if (saltSet.contains('aspirin') && saltSet.contains('warfarin')) {
      warnings.add(
        '🚨 Severe Interaction: Aspirin + Warfarin significantly increases the risk of major internal bleeding. Do not combine without strict medical supervision.',
      );
    }

    // Paracetamol + Ibuprofen (Timing & GI Advisory)
    if (saltSet.contains('paracetamol') && saltSet.contains('ibuprofen')) {
      warnings.add(
        'ℹ️ Timing Advisory: Paracetamol + Ibuprofen. Alternating doses every 4–6 hours is recommended over concurrent administration. Always take Ibuprofen with food to protect gastric lining.',
      );
    }

    // Ciprofloxacin + Omeprazole
    if (saltSet.contains('ciprofloxacin') && saltSet.contains('omeprazole')) {
      warnings.add(
        '⚠️ Absorption Advisory: Ciprofloxacin absorption can be reduced by acid reducers. Separate doses by at least 2 hours.',
      );
    }

    // 3. Incomplete Information / Unknown Medicine Warning
    if (unmappedNames.isNotEmpty) {
      warnings.add(
        'Notice: Incomplete ingredient profile for "${unmappedNames.join(', ')}". Automated interaction screening covers registered primary salts only. Consult your pharmacist or doctor.',
      );
    }

    // 4. Coverage disclaimer - always shown when 2+ medicines are screened, so the
    // absence of a specific warning is never presented as a safety clearance.
    warnings.add(
      'Notice: This screening only checks a small built-in list of ingredient pairs. No warning here does NOT mean the combination is safe. Confirm all medicines with your pharmacist or doctor.',
    );

    return warnings;
  }

  // Alternatives Finder
  List<MedicineModel> findAlternatives(
    MedicineModel target,
    List<MedicineModel> allMeds,
  ) {
    // Only return exact same generic name. Always advise confirming.
    return allMeds
        .where(
          (m) =>
              m.genericName.toLowerCase() == target.genericName.toLowerCase() &&
              m.medicineId != target.medicineId,
        )
        .toList();
  }

  // Price Checker
  String checkPrice(double userPrice, double referencePrice) {
    if (userPrice > referencePrice * 1.2) {
      return 'Entered price is significantly higher than the reference price (Rs. ${referencePrice.toStringAsFixed(2)}).';
    } else if (userPrice < referencePrice * 0.8) {
      return 'Entered price is significantly lower than the reference price. Verify authenticity.';
    }
    return 'Price is within expected range.';
  }

  /// Screen active medications against the patient's saved allergies list.
  List<String> checkAllergyContraindications(
    List<UserMedicationModel> meds,
    List<String> allergies,
  ) {
    if (allergies.isEmpty || meds.isEmpty) return [];
    final warnings = <String>[];
    for (final allergy in allergies) {
      final aLower = allergy.toLowerCase().trim();
      if (aLower.isEmpty) continue;
      for (final med in meds) {
        final medNameLower = med.name.toLowerCase();
        final genericLower = med.genericName.toLowerCase();
        if ((aLower.contains('penicillin') || aLower.contains('amoxicillin')) &&
            (medNameLower.contains('augmentin') ||
                medNameLower.contains('amoxicillin') ||
                medNameLower.contains('curam') ||
                genericLower.contains('amoxicillin') ||
                genericLower.contains('penicillin'))) {
          warnings.add(
            '🚨 Allergy Contraindication: You take "${med.name}", but have a recorded allergy to $allergy. Consult your physician immediately.',
          );
        } else if ((aLower.contains('aspirin') || aLower.contains('nsaid')) &&
            (medNameLower.contains('aspirin') ||
                medNameLower.contains('disprin') ||
                medNameLower.contains('brufen') ||
                medNameLower.contains('ibuprofen') ||
                medNameLower.contains('diclofenac') ||
                medNameLower.contains('voltral') ||
                genericLower.contains('aspirin') ||
                genericLower.contains('ibuprofen') ||
                genericLower.contains('diclofenac'))) {
          warnings.add(
            '🚨 Allergy / NSAID Sensitivity: You take "${med.name}", which belongs to the NSAID/salicylate class and conflicts with your $allergy allergy.',
          );
        } else if (aLower.length >= 3 &&
            (medNameLower.contains(aLower) ||
                (genericLower.isNotEmpty && genericLower.contains(aLower)))) {
          warnings.add(
            '⚠️ Potential Allergy Conflict: "${med.name}" may conflict with your reported $allergy allergy.',
          );
        }
      }
    }
    return warnings;
  }
}
