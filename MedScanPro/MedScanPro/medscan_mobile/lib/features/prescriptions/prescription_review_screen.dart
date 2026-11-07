import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../models/prescription_model.dart';
import '../../models/reminder_model.dart';
import '../../models/user_medication_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/medication_providers.dart';
import '../../providers/scan_providers.dart';
import '../../providers/storage_providers.dart';
import '../../services/notification_service.dart';
import '../../services/prescription_parser.dart';

/// Screen for reviewing, editing, and confirming structured prescription fields
/// alongside the original prescription preview.
///
/// Key safety guarantees:
/// 1. Original prescription image / PDF pages are shown for side-by-side comparison.
/// 2. Missing or uncertain fields remain unknown and are highlighted for user review.
/// 3. Raw AI output is NEVER saved as a confirmed prescription until the user reviews
///    and confirms all items.
/// 4. Saving to Prescription History is idempotent (prevents duplicate records on repeated taps)
///    and decoupled from optional reminder setup.
/// 5. Optional reminder setup NEVER assumes clock times from phrases like "twice daily"
///    and NEVER auto-creates repeating alarms for "as needed" (PRN) or tapering schedules.
class PrescriptionReviewScreen extends ConsumerStatefulWidget {
  final List<PrescriptionMedicineItem>? initialItems;
  final String? imagePath;
  final List<String>? previewImagePaths;
  final String? rawText;
  final String? prescriptionDate;
  final String? mimeType;
  final String? fileName;
  final String? extractionSource;

  const PrescriptionReviewScreen({
    super.key,
    this.initialItems,
    this.imagePath,
    this.previewImagePaths,
    this.rawText,
    this.prescriptionDate,
    this.mimeType,
    this.fileName,
    this.extractionSource,
  });

  @override
  ConsumerState<PrescriptionReviewScreen> createState() =>
      _PrescriptionReviewScreenState();
}

class _PrescriptionReviewScreenState
    extends ConsumerState<PrescriptionReviewScreen> {
  late List<PrescriptionMedicineItem> _items;
  late String _prescriptionDate;
  late final String _sessionPrescriptionId;

  bool _showOriginalComparison = true;
  bool _storeOriginalFileInCloud = true;
  bool _isSavingHistory = false;
  bool _hasSavedToHistory = false;
  String? _saveErrorMessage;
  int _currentPreviewPage = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems != null
        ? widget.initialItems!.map((e) => e.copyWith()).toList()
        : <PrescriptionMedicineItem>[];
    _prescriptionDate = (widget.prescriptionDate ?? '').trim();
    if (_prescriptionDate.isEmpty && _items.isNotEmpty) {
      _prescriptionDate = _items.first.prescriptionDate;
    }
    _sessionPrescriptionId =
        'rx_${DateTime.now().millisecondsSinceEpoch}_${widget.imagePath.hashCode.abs()}';
  }

  int get _unconfirmedCount => _items.where((item) => !item.isConfirmed).length;

  List<String> get _effectivePreviewPaths {
    final paths = widget.previewImagePaths;
    if (paths != null && paths.isNotEmpty) return paths;
    final single = widget.imagePath;
    if (single != null &&
        single.trim().isNotEmpty &&
        !single.toLowerCase().endsWith('.pdf')) {
      return <String>[single];
    }
    return const <String>[];
  }

  void _confirmItem(int index) {
    final item = _items[index];
    if (item.medicineName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medicine name is missing. Please edit and enter the medicine name before confirming.',
          ),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      _showEditItemDialog(item, index);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _items[index] = item.copyWith(
        isConfirmed: true,
        confidence: FieldConfidence.high,
        uncertainFields: const [],
      );
      _hasSavedToHistory = false;
    });
  }

  void _deleteItem(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _items.removeAt(index);
      _hasSavedToHistory = false;
    });
  }

  Future<void> _showEditItemDialog(
    PrescriptionMedicineItem item,
    int index,
  ) async {
    final nameCtrl = TextEditingController(text: item.medicineName);
    final brandCtrl = TextEditingController(text: item.brand);
    final strengthCtrl = TextEditingController(text: item.strength);
    final doseCtrl = TextEditingController(text: item.dosageInstructions);
    final routeCtrl = TextEditingController(
      text: item.route.isNotEmpty ? item.route : item.dosageForm,
    );
    final freqCtrl = TextEditingController(text: item.frequency);
    final timingCtrl = TextEditingController(text: item.timing);
    final durationCtrl = TextEditingController(
      text: item.duration.isNotEmpty
          ? item.duration
          : (item.durationDays > 0 ? '${item.durationDays} days' : ''),
    );
    final quantityCtrl = TextEditingController(text: item.quantity);
    final rxDateCtrl = TextEditingController(
      text: item.prescriptionDate.isNotEmpty
          ? item.prescriptionDate
          : _prescriptionDate,
    );
    final specialCtrl = TextEditingController(text: item.specialInstructions);

    final updated = await showDialog<PrescriptionMedicineItem>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: MedScanTheme.primaryTeal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review & Edit Medicine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('edit_medicine_name_field'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Paracetamol / Amoxicillin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('edit_brand_field'),
                          controller: brandCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Brand (if legible)',
                            hintText: 'e.g. Panadol',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('edit_strength_field'),
                          controller: strengthCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Strength',
                            hintText: 'e.g. 500mg',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('edit_dosage_field'),
                          controller: doseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dosage Instructions',
                            hintText: 'e.g. 1 tablet / 5ml',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('edit_route_field'),
                          controller: routeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Route / Form',
                            hintText: 'e.g. Oral Tablet',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('edit_frequency_field'),
                          controller: freqCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            hintText: 'e.g. Twice daily / PRN',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('edit_timing_field'),
                          controller: timingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Meal Timing',
                            hintText: 'e.g. After meal',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('edit_duration_field'),
                          controller: durationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                            hintText: 'e.g. 5 days',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('edit_quantity_field'),
                          controller: quantityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: 'e.g. 10 tablets',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('edit_rx_date_field'),
                    controller: rxDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prescription Date',
                      hintText: 'e.g. 2026-10-22',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('edit_special_instructions_field'),
                    controller: specialCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Special Instructions',
                      hintText: 'Any warnings, tapering notes, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              key: const Key('save_edited_item_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MedScanTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirm Item'),
              onPressed: () {
                final medName = nameCtrl.text.trim();
                if (medName.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Medicine name cannot be empty.'),
                    ),
                  );
                  return;
                }

                final durText = durationCtrl.text.trim();
                final durDigits = RegExp(r'\d+').firstMatch(durText);
                final parsedDays = durDigits != null
                    ? (int.tryParse(durDigits.group(0)!) ?? 0)
                    : item.durationDays;

                Navigator.of(ctx).pop(
                  item.copyWith(
                    medicineName: medName,
                    brand: brandCtrl.text.trim(),
                    strength: strengthCtrl.text.trim(),
                    dosageInstructions: doseCtrl.text.trim(),
                    route: routeCtrl.text.trim(),
                    dosageForm: routeCtrl.text.trim(),
                    frequency: freqCtrl.text.trim(),
                    timing: timingCtrl.text.trim(),
                    duration: durText,
                    durationDays: parsedDays,
                    quantity: quantityCtrl.text.trim(),
                    prescriptionDate: rxDateCtrl.text.trim(),
                    specialInstructions: specialCtrl.text.trim(),
                    uncertainFields: const [],
                    confidence: FieldConfidence.high,
                    isConfirmed: true,
                  ),
                );
              },
            ),
          ],
        );
      },
    );

    if (updated != null && mounted) {
      setState(() {
        _items[index] = updated;
        if (updated.prescriptionDate.isNotEmpty) {
          _prescriptionDate = updated.prescriptionDate;
        }
        _hasSavedToHistory = false;
      });
    }
  }

  void _addNewManualItem() {
    final newItem = PrescriptionMedicineItem(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      medicineName: '',
      strength: '',
      frequency: '',
      prescriptionDate: _prescriptionDate,
      confidence: FieldConfidence.low,
      isConfirmed: false,
    );
    setState(() {
      _items.add(newItem);
      _hasSavedToHistory = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEditItemDialog(newItem, _items.length - 1);
    });
  }

  /// Saves the reviewed and confirmed prescription to the authenticated user's
  /// Prescription History. Decoupled from optional reminder scheduling.
  Future<void> _confirmAndSaveToHistory() async {
    if (_isSavingHistory) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add and confirm at least one medicine before saving.',
          ),
        ),
      );
      return;
    }

    if (_unconfirmedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD97706),
          content: Text(
            'Please review and confirm $_unconfirmedCount item(s) marked "Needs review" before saving.',
          ),
        ),
      );
      return;
    }

    if (_hasSavedToHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This prescription is already saved to your history.'),
        ),
      );
      return;
    }

    var user = ref.read(authStateProvider).value;
    if (user == null) {
      try {
        user = await ref.read(authStateProvider.future);
      } catch (_) {}
    }
    if (!mounted) return;
    if (user == null || user.uid.trim().isEmpty) {
      setState(() {
        _saveErrorMessage =
            'You must be signed in to save prescriptions to your history.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(_saveErrorMessage!),
        ),
      );
      return;
    }

    setState(() {
      _isSavingHistory = true;
      _saveErrorMessage = null;
    });

    try {
      String storedImageUrl = '';
      final rawPath = (widget.imagePath ?? '').trim();
      if (_storeOriginalFileInCloud && rawPath.isNotEmpty) {
        final storage = ref.read(storageServiceProvider);
        storedImageUrl = await storage.uploadPrescriptionImage(
          userId: user.uid,
          localPath: rawPath,
        );
      }

      final summaryLines = _items.map((i) {
        final parts = <String>[
          i.medicineName,
          if (i.brand.isNotEmpty && i.brand != i.medicineName) '(${i.brand})',
          if (i.strength.isNotEmpty) i.strength,
          if (i.frequency.isNotEmpty) '• ${i.frequency}',
          if (i.duration.isNotEmpty) '• ${i.duration}',
        ];
        return parts.join(' ').trim();
      }).toList();

      final prescription = PrescriptionModel(
        id: _sessionPrescriptionId,
        userId: user.uid,
        imagePath: storedImageUrl,
        extractedMedicines: summaryLines,
        structuredMedicines: _items.map((i) => i.toMap()).toList(),
        prescriptionDate: _prescriptionDate,
        rawText: widget.rawText ?? '',
        mimeType: widget.mimeType ?? 'image/jpeg',
        isConfirmedByUser: true,
        uploadedAt: DateTime.now(),
      );

      final repo = ref.read(medicationRepositoryProvider);
      await repo.addPrescription(prescription);

      if (!mounted) return;
      setState(() {
        _isSavingHistory = false;
        _hasSavedToHistory = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('prescription_saved_snackbar'),
          backgroundColor: Color(0xFF087F8C),
          content: Text(
            'Confirmed prescription saved to your history. You can optionally set reminders below.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingHistory = false;
        _saveErrorMessage =
            'Could not save prescription to history: $e. Your edits are still on screen — please retry.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('prescription_save_error_snackbar'),
          backgroundColor: Colors.red.shade700,
          content: Text(_saveErrorMessage!),
        ),
      );
    }
  }

  /// Opens the separate, optional reminder confirmation sheet.
  /// - Does NOT assume exact clock times from phrases like "twice daily"; asks user to pick times.
  /// - Does NOT automatically schedule repeating alarms for PRN / "as needed" or tapering schedules.
  Future<void> _openOptionalReminderSetup() async {
    if (_unconfirmedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD97706),
          content: Text(
            'Please review and confirm all prescription items first.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OptionalReminderSetupSheet(
        items: _items,
        sessionPrescriptionId: _sessionPrescriptionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? MedScanTheme.surfaceCard : Colors.white;
    final borderColor = isDark ? MedScanTheme.border : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? MedScanTheme.textPrimary
        : const Color(0xFF0F172A);
    final textMuted = isDark ? MedScanTheme.textMuted : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark
          ? MedScanTheme.background
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Review & Confirm Prescription',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
        ),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('add_manual_medicine_button'),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: MedScanTheme.accentTeal,
            ),
            tooltip: 'Add Medication Manually',
            onPressed: _addNewManualItem,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Clinical Safety Disclaimer Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border(bottom: BorderSide(color: Colors.amber.shade400)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safety Notice: AI-extracted text is NOT medically verified. Compare every field with your original prescription below before confirming.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF78350F),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Save error banner (if saving failed, screen is preserved)
          if (_saveErrorMessage != null)
            Container(
              key: const Key('review_save_error_banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFEF2F2),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveErrorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Scrollable Comparison + Editable Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOriginalComparisonCard(isDark, borderColor),
                const SizedBox(height: 12),
                _buildReviewStatusHeader(textPrimary),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  _buildEmptyState(textPrimary, textMuted)
                else
                  ...List.generate(
                    _items.length,
                    (index) => _buildMedicineReviewCard(
                      _items[index],
                      index,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                  ),
                const SizedBox(height: 8),
                // Privacy option for storing original image/PDF
                if ((widget.imagePath ?? '').trim().isNotEmpty)
                  CheckboxListTile(
                    key: const Key('store_original_file_checkbox'),
                    contentPadding: EdgeInsets.zero,
                    value: _storeOriginalFileInCloud,
                    activeColor: MedScanTheme.primaryTeal,
                    title: const Text(
                      'Save original prescription file in my private history',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Uncheck if you only want to save the confirmed medicine text record.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _storeOriginalFileInCloud = val);
                      }
                    },
                  ),
              ],
            ),
          ),

          // 4. Bottom Action Bar: Step 1 (Confirm & Save History) + Step 2 (Separate Optional Reminders)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    key: const Key('confirm_and_save_history_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasSavedToHistory
                          ? const Color(0xFF16A34A)
                          : MedScanTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSavingHistory
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _hasSavedToHistory
                                ? Icons.check_circle_rounded
                                : Icons.cloud_done_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _isSavingHistory
                          ? 'Saving Confirmed Prescription...'
                          : _hasSavedToHistory
                          ? 'Saved to Prescription History'
                          : _unconfirmedCount > 0
                          ? 'Confirm $_unconfirmedCount Item(s) to Save History'
                          : 'Confirm & Save to Prescription History',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _isSavingHistory
                        ? null
                        : _confirmAndSaveToHistory,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('set_optional_reminders_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MedScanTheme.primaryTeal,
                            side: const BorderSide(
                              color: MedScanTheme.primaryTeal,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.alarm_add_rounded, size: 18),
                          label: const Text(
                            'Set Reminders (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _items.isEmpty
                              ? null
                              : _openOptionalReminderSetup,
                        ),
                      ),
                      if (_hasSavedToHistory) ...[
                        const SizedBox(width: 10),
                        TextButton.icon(
                          key: const Key('done_go_records_button'),
                          onPressed: () => context.go('/records'),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('View History'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalComparisonCard(bool isDark, Color borderColor) {
    final previews = _effectivePreviewPaths;
    final hasFilePreview =
        previews.isNotEmpty && File(previews.first).existsSync();
    final hasRawText = (widget.rawText ?? '').trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MedScanTheme.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('toggle_original_prescription_button'),
            onTap: () => setState(
              () => _showOriginalComparison = !_showOriginalComparison,
            ),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.compare_rounded,
                    color: MedScanTheme.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Original Prescription for Comparison${_prescriptionDate.isNotEmpty ? ' • Date: $_prescriptionDate' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _showOriginalComparison
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_showOriginalComparison)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasFilePreview)
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemCount: previews.length,
                            onPageChanged: (idx) =>
                                setState(() => _currentPreviewPage = idx),
                            itemBuilder: (ctx, idx) => InteractiveViewer(
                              child: Image.file(
                                File(previews[idx]),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (previews.length > 1)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Page ${_currentPreviewPage + 1}/${previews.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        (widget.imagePath ?? '').trim().isNotEmpty
                            ? 'Original Document: ${widget.fileName ?? widget.imagePath}'
                            : 'No original image attached (Manual / Text entry).',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (hasRawText) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Extracted Visible Text:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.rawText!.trim(),
                            style: const TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStatusHeader(Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _unconfirmedCount > 0
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _unconfirmedCount > 0
              ? const Color(0xFFF59E0B)
              : const Color(0xFF10B981),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _unconfirmedCount > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: _unconfirmedCount > 0
                ? const Color(0xFFD97706)
                : const Color(0xFF059669),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _unconfirmedCount > 0
                  ? '$_unconfirmedCount of ${_items.length} item(s) need your review and confirmation before saving.'
                  : 'All ${_items.length} item(s) reviewed and confirmed by you.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _unconfirmedCount > 0
                    ? const Color(0xFF92400E)
                    : const Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineReviewCard(
    PrescriptionMedicineItem item,
    int index, {
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final missingFields = item.missingOrUncertainFields;
    final displayTitle = item.medicineName.trim().isNotEmpty
        ? item.medicineName
        : 'Unknown Medicine (Needs Review)';

    return Container(
      key: Key('prescription_item_card_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !item.isConfirmed ? const Color(0xFFF59E0B) : borderColor,
          width: !item.isConfirmed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: item.medicineName.trim().isEmpty
                            ? const Color(0xFFD97706)
                            : textPrimary,
                      ),
                    ),
                    if (item.brand.trim().isNotEmpty)
                      Text(
                        'Brand: ${item.brand}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                  ],
                ),
              ),
              InkWell(
                key: Key('confirm_item_chip_$index'),
                onTap: () => _confirmItem(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.isConfirmed
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.isConfirmed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isConfirmed
                            ? Icons.check_circle_rounded
                            : Icons.touch_app_rounded,
                        size: 14,
                        color: item.isConfirmed
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isConfirmed ? 'Confirmed' : 'Needs Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.isConfirmed
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Highlight missing or uncertain fields
          if (!item.isConfirmed && missingFields.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Missing or uncertain fields (marked for review): ${missingFields.join(', ')}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFieldBadge('Strength', item.strength, isDark: isDark),
              _buildFieldBadge('Dose', item.dosageInstructions, isDark: isDark),
              _buildFieldBadge(
                'Route/Form',
                item.route.isNotEmpty ? item.route : item.dosageForm,
                isDark: isDark,
              ),
              _buildFieldBadge('Frequency', item.frequency, isDark: isDark),
              _buildFieldBadge(
                'Duration',
                item.duration.isNotEmpty
                    ? item.duration
                    : (item.durationDays > 0
                          ? '${item.durationDays} days'
                          : ''),
                isDark: isDark,
              ),
              if (item.quantity.trim().isNotEmpty)
                _buildFieldBadge('Qty', item.quantity, isDark: isDark),
              if (item.timing.trim().isNotEmpty)
                _buildFieldBadge('Timing', item.timing, isDark: isDark),
              if (item.prescriptionDate.trim().isNotEmpty)
                _buildFieldBadge('Date', item.prescriptionDate, isDark: isDark),
            ],
          ),
          if (item.specialInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Special Instructions: ${item.specialInstructions}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('edit_item_button_$index'),
                onPressed: () => _showEditItemDialog(item, index),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: MedScanTheme.primaryTeal,
                ),
                label: const Text(
                  'Edit Fields',
                  style: TextStyle(
                    fontSize: 12,
                    color: MedScanTheme.primaryTeal,
                  ),
                ),
              ),
              if (!item.isConfirmed)
                TextButton.icon(
                  key: Key('confirm_item_button_$index'),
                  onPressed: () => _confirmItem(index),
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF059669),
                  ),
                  label: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                  ),
                ),
              TextButton.icon(
                key: Key('remove_item_button_$index'),
                onPressed: () => _deleteItem(index),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldBadge(String label, String value, {required bool isDark}) {
    final isUnknown = value.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUnknown
            ? const Color(0xFFFEF3C7)
            : (isDark ? MedScanTheme.surface : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUnknown
              ? const Color(0xFFFBBF24)
              : (isDark ? MedScanTheme.borderSubtle : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        '$label: ${isUnknown ? 'Unknown (Review)' : value}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isUnknown
              ? const Color(0xFF92400E)
              : (isDark ? MedScanTheme.textSecondary : const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.playlist_add_check_circle_outlined,
            size: 46,
            color: MedScanTheme.primaryTeal,
          ),
          const SizedBox(height: 12),
          Text(
            'No Structured Medicines Found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare with your original prescription above and tap below to add medicines manually.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addNewManualItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: MedScanTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medicine Manually'),
          ),
        ],
      ),
    );
  }
}

/// Separate, Optional Reminder Confirmation Sheet.
/// Enforces:
/// - Never assumes exact clock times from phrases like "twice daily"; requires user to fill missing times.
/// - Never automatically creates repeating reminders for "as needed" (PRN) or tapering/ambiguous schedules.
/// - Reports reminders as scheduled ONLY when `NotificationService.scheduleReminder` succeeds.
class _OptionalReminderSetupSheet extends ConsumerStatefulWidget {
  final List<PrescriptionMedicineItem> items;
  final String sessionPrescriptionId;

  const _OptionalReminderSetupSheet({
    required this.items,
    required this.sessionPrescriptionId,
  });

  @override
  ConsumerState<_OptionalReminderSetupSheet> createState() =>
      _OptionalReminderSetupSheetState();
}

class _OptionalReminderSetupSheetState
    extends ConsumerState<_OptionalReminderSetupSheet> {
  late final Map<String, bool> _enabledByItemId;
  late final Map<String, List<String?>> _selectedTimesByItemId;
  bool _isScheduling = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _enabledByItemId = <String, bool>{};
    _selectedTimesByItemId = <String, List<String?>>{};

    for (final item in widget.items) {
      final isAutoBlocked =
          item.isPrnOrAsNeeded || item.isAmbiguousOrTaperingSchedule;
      // Do NOT auto-enable repeating reminders for PRN ("as needed") or ambiguous/tapering schedules
      _enabledByItemId[item.id] = !isAutoBlocked;

      // Do NOT assume exact clock times (like 09:00 AM / 09:00 PM) from "twice daily".
      // Initialize slots as null so the user explicitly fills/picks their clock times.
      final slotCount = item.expectedDailyDoseCount ?? 1;
      _selectedTimesByItemId[item.id] = List<String?>.filled(
        slotCount,
        null,
        growable: true,
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final hStr = hour12.toString().padLeft(2, '0');
    final mStr = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.pm ? 'PM' : 'AM';
    return '$hStr:$mStr $period';
  }

  Future<void> _pickClockTime(String itemId, int slotIndex) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTimesByItemId[itemId]![slotIndex] = _formatTimeOfDay(picked);
        _statusMessage = null;
      });
    }
  }

  void _setQuickPresetTime(String itemId, int slotIndex, String formattedTime) {
    setState(() {
      _selectedTimesByItemId[itemId]![slotIndex] = formattedTime;
      _statusMessage = null;
    });
  }

  Future<void> _confirmAndScheduleReminders() async {
    if (_isScheduling) return;

    final enabledItems = widget.items
        .where((i) => _enabledByItemId[i.id] == true)
        .toList();
    if (enabledItems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // Verify all enabled items have user-selected clock times (no assumed times!)
    for (final item in enabledItems) {
      final slots = _selectedTimesByItemId[item.id] ?? const <String?>[];
      if (slots.isEmpty || slots.any((t) => t == null || t.trim().isEmpty)) {
        setState(() {
          _statusIsError = true;
          _statusMessage =
              'Please select exact clock time(s) for "${item.medicineName}" before confirming reminders.';
        });
        return;
      }
    }

    var user = ref.read(authStateProvider).value;
    if (user == null) {
      try {
        user = await ref.read(authStateProvider.future);
      } catch (_) {}
    }
    if (!mounted) return;
    if (user == null || user.uid.trim().isEmpty) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Please sign in to save medication reminders.';
      });
      return;
    }

    setState(() {
      _isScheduling = true;
      _statusMessage = null;
    });

    final repo = ref.read(medicationRepositoryProvider);
    final notif = ref.read(notificationServiceProvider);

    int requestedAlarms = 0;
    int succeededAlarms = 0;

    try {
      for (final item in enabledItems) {
        final confirmedTimes = _selectedTimesByItemId[item.id]!
            .whereType<String>()
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList();

        final deterministicMedDocId =
            '${widget.sessionPrescriptionId}_${item.id}';
        final med = UserMedicationModel(
          id: deterministicMedDocId,
          userId: user.uid,
          name: item.medicineName,
          strength: item.strength,
          dosage: item.dosageInstructions.isNotEmpty
              ? item.dosageInstructions
              : '1 ${item.route.isNotEmpty ? item.route : 'dose'}',
          frequency: item.frequency,
          form: item.route.isNotEmpty ? item.route : item.dosageForm,
          unit: item.strength,
          reminderTimes: confirmedTimes,
          mealInstruction: item.timing,
          stockCount: item.durationDays > 0
              ? item.durationDays * confirmedTimes.length
              : confirmedTimes.length,
          createdAt: DateTime.now(),
        );
        await repo.addMedication(med, docId: deterministicMedDocId);

        for (final timeStr in confirmedTimes) {
          requestedAlarms++;
          final nextDose = _computeNextDoseDateTime(timeStr);
          final notifId = NotificationService.deterministicReminderId(
            userId: user.uid,
            medicineName: item.medicineName,
            timeSlot: timeStr,
          );

          final scheduledOk = await notif.scheduleReminder(
            notifId,
            'Time for ${item.medicineName}',
            '${med.dosage} (${item.strength})${item.timing.isNotEmpty ? ' • ${item.timing}' : ''}',
            nextDose,
          );

          if (scheduledOk) {
            succeededAlarms++;
            final reminderDocId = 'rem_${notifId}_${user.uid}';
            await repo.addReminder(
              ReminderModel(
                id: reminderDocId,
                userId: user.uid,
                medicationId: deterministicMedDocId,
                medicationName: item.medicineName,
                time: nextDose,
                frequency: item.frequency,
              ),
              docId: reminderDocId,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _isScheduling = false);

      if (succeededAlarms == 0 && requestedAlarms > 0) {
        setState(() {
          _statusIsError = true;
          _statusMessage =
              'Notification permission was denied or alarm scheduling failed. Your prescription history remains saved, but device notifications could not be scheduled.';
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('reminders_scheduled_snackbar'),
          backgroundColor: const Color(0xFF087F8C),
          content: Text(
            '$succeededAlarms of $requestedAlarms reminder alarm(s) confirmed and scheduled.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScheduling = false;
        _statusIsError = true;
        _statusMessage = 'Failed to save reminders: $e';
      });
    }
  }

  DateTime _computeNextDoseDateTime(String formattedTime) {
    final isPm = formattedTime.toUpperCase().contains('PM');
    final isAm = formattedTime.toUpperCase().contains('AM');
    final clean = formattedTime.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = clean.split(':');
    int hour = int.tryParse(parts.first) ?? 8;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? MedScanTheme.surfaceCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.alarm_add_rounded, color: MedScanTheme.primaryTeal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm Medication Reminders (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select exact clock times for each dose below. MedScan Pro never guesses clock times from phrases like "twice daily", and does not auto-schedule "as needed" (PRN) medicines.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            if (_statusMessage != null) ...[
              Container(
                key: const Key('reminder_sheet_status_banner'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusIsError
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusIsError
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...widget.items.map(_buildItemReminderConfig),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('skip_reminders_button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip Reminders'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    key: const Key('confirm_schedule_reminders_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MedScanTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _isScheduling ? 'Scheduling...' : 'Confirm & Schedule',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isScheduling
                        ? null
                        : _confirmAndScheduleReminders,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemReminderConfig(PrescriptionMedicineItem item) {
    final isEnabled = _enabledByItemId[item.id] == true;
    final slots = _selectedTimesByItemId[item.id] ?? <String?>[];
    final isPrn = item.isPrnOrAsNeeded;
    final isAmbiguous = item.isAmbiguousOrTaperingSchedule;

    return Container(
      key: Key('reminder_config_${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isEnabled,
            activeThumbColor: MedScanTheme.primaryTeal,
            title: Text(
              '${item.medicineName} ${item.strength}'.trim(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Frequency: ${item.frequency.isNotEmpty ? item.frequency : 'Unspecified'}',
              style: const TextStyle(fontSize: 12),
            ),
            onChanged: (val) => setState(() => _enabledByItemId[item.id] = val),
          ),
          if (isPrn || isAmbiguous)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPrn
                    ? 'As-needed (PRN) instruction detected: automatic repeating reminders are disabled by default.'
                    : 'Variable, tapering, or unspecified schedule: automatic repeating reminders are disabled until you explicitly configure clock times.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          if (isEnabled) ...[
            const Text(
              'Select exact clock time(s):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...List.generate(slots.length, (slotIdx) {
              final currentVal = slots[slotIdx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: Key('pick_time_${item.id}_$slotIdx'),
                            onPressed: () => _pickClockTime(item.id, slotIdx),
                            icon: const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                            ),
                            label: Text(
                              currentVal ??
                                  'Dose ${slotIdx + 1}: Tap to Pick Clock Time *',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: currentVal == null
                                    ? const Color(0xFFD97706)
                                    : MedScanTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ),
                        if (slots.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                            onPressed: () => setState(() {
                              slots.removeAt(slotIdx);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final preset in const [
                          '08:00 AM',
                          '02:00 PM',
                          '08:00 PM',
                          '10:00 PM',
                        ])
                          ActionChip(
                            key: Key(
                              'preset_time_${item.id}_${slotIdx}_$preset',
                            ),
                            label: Text(
                              preset,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _setQuickPresetTime(item.id, slotIdx, preset),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => slots.add(null)),
              icon: const Icon(Icons.add_alarm_rounded, size: 16),
              label: const Text('Add Another Daily Time Slot'),
            ),
          ],
        ],
      ),
    );
  }
}
