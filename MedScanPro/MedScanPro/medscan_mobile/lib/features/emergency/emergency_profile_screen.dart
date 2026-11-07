import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/safety_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/emergency_profile_model.dart';
import '../../shared/widgets/primary_button.dart';

class EmergencyProfileScreen extends ConsumerStatefulWidget {
  const EmergencyProfileScreen({super.key});

  @override
  ConsumerState<EmergencyProfileScreen> createState() =>
      _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState
    extends ConsumerState<EmergencyProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _blood = TextEditingController();
  final _allergyInput = TextEditingController();
  final _conditionInput = TextEditingController();
  final _meds = TextEditingController();
  final _contact = TextEditingController();

  List<String> _allergiesList = [];
  List<String> _conditionsList = [];

  bool _sharing = false;
  bool _shareAllergies = true;
  bool _shareConditions = true;
  bool _shareContact = true;

  bool _loaded = false;
  bool _isSaving = false;

  final List<String> _commonAllergySuggestions = [
    'Penicillin',
    'Amoxicillin',
    'Aspirin',
    'Sulfa Drugs',
    'NSAIDs',
    'Peanuts',
    'Latex',
    'Iodine',
  ];

  final List<String> _commonConditionSuggestions = [
    'Hypertension',
    'Type 2 Diabetes',
    'Asthma',
    'Chronic Kidney Disease',
    'Coronary Artery Disease',
    'Epilepsy',
    'Thyroid Disorder',
  ];

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _blood.dispose();
    _allergyInput.dispose();
    _conditionInput.dispose();
    _meds.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _addAllergy(String item) {
    final clean = item.trim();
    if (clean.isEmpty) return;
    if (!_allergiesList.any((a) => a.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _allergiesList.add(clean);
        _allergyInput.clear();
      });
    } else {
      _allergyInput.clear();
    }
  }

  void _removeAllergy(String item) {
    setState(() {
      _allergiesList.removeWhere((a) => a.toLowerCase() == item.toLowerCase());
    });
  }

  void _addCondition(String item) {
    final clean = item.trim();
    if (clean.isEmpty) return;
    if (!_conditionsList.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _conditionsList.add(clean);
        _conditionInput.clear();
      });
    } else {
      _conditionInput.clear();
    }
  }

  void _removeCondition(String item) {
    setState(() {
      _conditionsList.removeWhere((c) => c.toLowerCase() == item.toLowerCase());
    });
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    final uid = user?.uid ?? 'local_user';
    setState(() => _isSaving = true);

    try {
      final p = EmergencyProfileModel(
        userId: uid,
        name: _name.text.trim(),
        age: int.tryParse(_age.text.trim()) ?? 0,
        bloodGroup: _blood.text.trim(),
        allergiesList: _allergiesList,
        medicalConditionsList: _conditionsList,
        currentMedicines: _meds.text.trim(),
        emergencyContact: _contact.text.trim(),
        isSharingEnabled: _sharing,
        shareAllergiesInQr: _shareAllergies,
        shareConditionsInQr: _shareConditions,
        shareContactInQr: _shareContact,
        isUserReported: true,
      );

      await ref.read(safetyServiceProvider).saveEmergencyProfile(p);
      ref.invalidate(emergencyProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency health profile saved successfully.'),
            backgroundColor: Color(0xFF087F8C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally. Cloud sync pending: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF087F8C);
    final profileAsync = ref.watch(emergencyProfileProvider);

    // Populate data once when available
    profileAsync.whenData((profile) {
      if (!_loaded && profile != null) {
        _name.text = profile.name;
        _age.text = profile.age > 0 ? profile.age.toString() : '';
        _blood.text = profile.bloodGroup;
        _allergiesList = List<String>.from(profile.allergiesList);
        _conditionsList = List<String>.from(profile.medicalConditionsList);
        _meds.text = profile.currentMedicines;
        _contact.text = profile.emergencyContact;
        _sharing = profile.isSharingEnabled;
        _shareAllergies = profile.shareAllergiesInQr;
        _shareConditions = profile.shareConditionsInQr;
        _shareContact = profile.shareContactInQr;
        _loaded = true;
      }
    });

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Health Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── User-Reported Disclaimer Banner ────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User-Reported Health Profile',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'This profile contains self-declared patient medical information for emergency responders and clinical safety cross-checks. Keep it accurate and up to date.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── QR Sharing & Privacy Toggles Card ─────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Enable Emergency QR Code Sharing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Allows any medical responder to scan your offline emergency payload without needing the MedScan app.',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        value: _sharing,
                        activeTrackColor: primaryTeal,
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setState(() => _sharing = val),
                      ),
                      if (_sharing) ...[
                        const Divider(height: 20),
                        Text(
                          'QR Privacy Controls',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Include Allergies in QR payload',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _shareAllergies,
                          activeColor: primaryTeal,
                          onChanged: (val) =>
                              setState(() => _shareAllergies = val ?? true),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Include Medical Conditions in QR payload',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _shareConditions,
                          activeColor: primaryTeal,
                          onChanged: (val) =>
                              setState(() => _shareConditions = val ?? true),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Include Emergency Contact Phone in QR payload',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _shareContact,
                          activeColor: primaryTeal,
                          onChanged: (val) =>
                              setState(() => _shareContact = val ?? true),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                            label: const Text('View My Emergency QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => context.push('/emergency/qr'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Form Section ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Personal Medical Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _age,
                              decoration: const InputDecoration(
                                labelText: 'Age',
                                prefixIcon: Icon(Icons.cake_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _blood,
                              decoration: const InputDecoration(
                                labelText: 'Blood Group (e.g. O+)',
                                prefixIcon: Icon(Icons.bloodtype_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Allergies Chip Editor ─────────────────────────────
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Known Drug & Food Allergies',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_allergiesList.length} saved',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _allergyInput,
                              decoration: const InputDecoration(
                                hintText: 'Add an allergy (e.g. Penicillin)...',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: _addAllergy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () => _addAllergy(_allergyInput.text),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      if (_allergiesList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _allergiesList.map((a) {
                            return Chip(
                              label: Text(
                                a,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.12),
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              onDeleted: () => _removeAllergy(a),
                              side: BorderSide(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.3),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _commonAllergySuggestions
                              .where((s) => !_allergiesList.contains(s))
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      '+ $s',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () => _addAllergy(s),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Medical Conditions Chip Editor ────────────────────
                      Row(
                        children: [
                          const Icon(
                            Icons.healing_outlined,
                            size: 18,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Medical Conditions & Diagnoses',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_conditionsList.length} saved',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _conditionInput,
                              decoration: const InputDecoration(
                                hintText:
                                    'Add condition (e.g. Asthma, Diabetes)...',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: _addCondition,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () =>
                                _addCondition(_conditionInput.text),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      if (_conditionsList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _conditionsList.map((c) {
                            return Chip(
                              label: Text(
                                c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: const Color(
                                0xFF0284C7,
                              ).withValues(alpha: 0.12),
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
                              onDeleted: () => _removeCondition(c),
                              side: BorderSide(
                                color: const Color(
                                  0xFF0284C7,
                                ).withValues(alpha: 0.3),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _commonConditionSuggestions
                              .where((s) => !_conditionsList.contains(s))
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      '+ $s',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () => _addCondition(s),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: _meds,
                        decoration: const InputDecoration(
                          labelText: 'Current Medications Summary',
                          prefixIcon: Icon(Icons.medication_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _contact,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      _isSaving
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: primaryTeal,
                              ),
                            )
                          : PrimaryButton(
                              text: 'Save Emergency Profile',
                              onPressed: _save,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
