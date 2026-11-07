import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/theme.dart';
import '../../models/medicine_reaction_report_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/safety_providers.dart';
import '../../shared/widgets/primary_button.dart';

class ReportReactionScreen extends ConsumerStatefulWidget {
  final String? prefilledMedicineName;

  const ReportReactionScreen({super.key, this.prefilledMedicineName});

  @override
  ConsumerState<ReportReactionScreen> createState() =>
      _ReportReactionScreenState();
}

class _ReportReactionScreenState extends ConsumerState<ReportReactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medController = TextEditingController();
  final _reactionDetailsController = TextEditingController();

  String _selectedReactionType = 'Skin rash or hives';
  String _selectedOnset = 'Within 1 hour';
  String _selectedSeverity = 'Mild';
  final List<String> _photos = [];
  bool _consentGiven = false;
  bool _isSubmitting = false;

  final List<String> _reactionTypes = [
    'Skin rash or hives',
    'Nausea, vomiting, or stomach pain',
    'Dizziness or drowsiness',
    'Swelling (face, lips, or tongue)',
    'Shortness of breath / wheezing',
    'Headache or migraine',
    'Fever or chills',
    'Unusual bleeding or bruising',
    'Other unexpected symptom',
  ];

  final List<String> _onsetOptions = [
    'Immediately (under 15 mins)',
    'Within 1 hour',
    '1 to 6 hours',
    'Next day (12–24 hours)',
    'After several days',
  ];

  final List<String> _severityLevels = ['Mild', 'Moderate', 'Severe'];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledMedicineName != null &&
        widget.prefilledMedicineName!.isNotEmpty) {
      _medController.text = widget.prefilledMedicineName!;
    }
  }

  @override
  void dispose() {
    _medController.dispose();
    _reactionDetailsController.dispose();
    super.dispose();
  }

  bool _isLifeThreateningSymptom(String symptom, String severity) {
    final lower = symptom.toLowerCase();
    return severity == 'Severe' ||
        lower.contains('breath') ||
        lower.contains('swelling (face') ||
        lower.contains('tongue');
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _photos.add(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please confirm consent before submitting a reaction report.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a safety reaction report.'),
        ),
      );
      return;
    }

    final medName = _medController.text.trim();

    // Check life-threatening symptom confirmation
    if (_isLifeThreateningSymptom(_selectedReactionType, _selectedSeverity)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text(
                'Emergency Warning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Symptoms such as difficulty breathing, swelling of the face/throat, or severe reactions can be life-threatening anaphylaxis. '
            'Please seek immediate emergency medical treatment (call 1122 or visit the nearest ER) rather than waiting for an app report.\n\n'
            'Do you still wish to archive this report for your records?',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel & Call Help'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Report'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final safetyService = ref.read(safetyServiceProvider);

      // Duplicate / Spam Protection check
      final isDuplicate = await safetyService.hasRecentReactionReport(
        userId: user.uid,
        medicineName: medName,
      );

      if (isDuplicate && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Recent Report Exists'),
            content: Text(
              'You already submitted an adverse reaction report for "$medName" in the last 24 hours. Would you like to submit another entry anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit Anyway'),
              ),
            ],
          ),
        );
        if (confirm != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final report = MedicineReactionReportModel(
        id: '',
        userId: user.uid,
        medicineName: medName,
        suspectedReaction: _selectedReactionType,
        onsetTime: _selectedOnset,
        severity: _selectedSeverity,
        localPhotoPaths: _photos,
        consentGiven: _consentGiven,
        status: 'Pending Review',
        submittedAt: DateTime.now(),
        additionalNotes: _reactionDetailsController.text.trim(),
      );

      await safetyService.submitReactionReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reaction report archived as Pending Review. Consult your physician.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

    final userReportsAsync = ref.watch(userReactionReportsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Report a Reaction'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Urgent Emergency Warning Banner ────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF991B1B)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.emergency_outlined,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'EMERGENCY WARNING',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'If experiencing severe symptoms like difficulty breathing, throat tightness, or facial swelling, STOP and seek immediate emergency care (Call 1122 or visit an ER). Do not delay care with an app form.',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Pharmacovigilance Disclaimer ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'User-reported reactions remain "Pending Review" and are never automatically treated as verified causal recalls.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Form Card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine Name *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _medController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Panadol 500mg, Augmentin 625mg',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the medicine name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Suspected Reaction *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedReactionType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: _reactionTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedReactionType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Onset Timing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedOnset,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: _onsetOptions.map((opt) {
                                  return DropdownMenuItem(
                                    value: opt,
                                    child: Text(
                                      opt,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedOnset = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Severity',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSeverity,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: _severityLevels.map((lvl) {
                                  return DropdownMenuItem(
                                    value: lvl,
                                    child: Text(
                                      lvl,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSeverity = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Additional Symptom Notes (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reactionDetailsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe what happened, other medicines taken, or treatment received...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Photos (optional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Supporting Photos (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt_outlined),
                              onPressed: () =>
                                  _pickPhoto(source: ImageSource.camera),
                              tooltip: 'Take Photo',
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library_outlined),
                              onPressed: () =>
                                  _pickPhoto(source: ImageSource.gallery),
                              tooltip: 'Gallery',
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_photos.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _photos.asMap().entries.map((entry) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(entry.value),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _photos.removeAt(entry.key));
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),

                    // Mandatory Consent Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consentGiven,
                      onChanged: (val) {
                        setState(() => _consentGiven = val ?? false);
                      },
                      title: Text(
                        'I consent to sharing this adverse reaction data for private safety auditing. I understand this report is unverified and does not replace medical advice.',
                        style: TextStyle(fontSize: 12, color: textPrimary),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),

                    PrimaryButton(
                      text: _isSubmitting
                          ? 'Submitting...'
                          : 'Submit Reaction Report',
                      isLoading: _isSubmitting,
                      onPressed: _submitReport,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── User's Previously Submitted Reports ────────────────────────
            Text(
              'My Submitted Reaction Reports',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            userReportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'You have not submitted any adverse reaction reports.',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.healing_outlined,
                              color: AppColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.medicineName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.suspectedReaction} • ${r.severity}',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: ${r.status}',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: 'Delete Report',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Report?'),
                                  content: const Text(
                                    'Are you sure you want to delete this reaction report?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref
                                    .read(safetyServiceProvider)
                                    .deleteReactionReport(r.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
