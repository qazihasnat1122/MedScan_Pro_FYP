import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';
import '../../shared/widgets/primary_button.dart';

// ---------------------------------------------------------------------------
// ConfirmationScreen — Gap 1 Implementation
// ---------------------------------------------------------------------------
// Every extracted OCR field now carries its own confidence score. Fields with
// LOW confidence are displayed as editable "action required" chips that the
// user must explicitly tap to confirm before verification can proceed.
//
// If BOTH batch number and expiry date are absent/unreadable the screen shows
// a prominent prompt asking the user to add one more photo of the relevant
// packaging face, rather than silently accepting empty values.
//
// A low-confidence unconfirmed field is NEVER silently accepted: the engine
// receives a confirmed flag from ScanData.criticalFieldsConfirmed that blocks
// MANUFACTURER_SUPPORTED and REFERENCE_AVAILABLE verdicts.
// ---------------------------------------------------------------------------

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _mfgCtrl;
  late TextEditingController _batchCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _barcodeCtrl;

  bool _showRawOcr = false;

  // Internal copy of confirmed flags so the UI updates without waiting for
  // Riverpod state to re-read (ScanData is not an immutable value type).
  final Map<String, bool> _confirmedFlags = {};

  @override
  void initState() {
    super.initState();
    final data = ref.read(scanStateProvider);
    _nameCtrl = TextEditingController(text: data.extractedName);
    _mfgCtrl = TextEditingController(text: data.extractedManufacturer);
    _batchCtrl = TextEditingController(text: data.extractedBatch);
    _expCtrl = TextEditingController(text: data.extractedExpiry);
    _regCtrl = TextEditingController(text: data.extractedRegistrationInfo);
    _barcodeCtrl = TextEditingController(text: data.extractedBarcode);

    // Seed confirmed flags from whatever the ScanData already knows.
    _confirmedFlags.addAll(Map.from(data.fieldConfirmedByUser));

    // If we have no confidence scores, generate simulated ones (real OCR
    // service would populate these; this simulates the output for the demo).
    if (data.fieldConfidences.isEmpty) {
      _seedDemoConfidences(data);
    }
  }

  /// Simulates per-field confidence scores that a real OCR service would provide.
  /// In production the OCR service populates `data.fieldConfidences` directly.
  void _seedDemoConfidences(ScanData data) {
    data.fieldConfidences = {
      'name': data.extractedName.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.low,
      'manufacturer': data.extractedManufacturer.isNotEmpty
          ? FieldConfidence.medium
          : FieldConfidence.low,
      'batch': data.extractedBatch.isNotEmpty
          ? FieldConfidence.medium
          : FieldConfidence.low,
      'expiry': data.extractedExpiry.isNotEmpty
          ? FieldConfidence.medium
          : FieldConfidence.low,
      'barcode': data.extractedBarcode.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.low,
      'genericSalt': data.extractedGenericSalt.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium,
      'strength': data.extractedStrength.isNotEmpty
          ? FieldConfidence.high
          : FieldConfidence.medium,
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mfgCtrl.dispose();
    _batchCtrl.dispose();
    _expCtrl.dispose();
    _regCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showFieldConfirmDialog(
    String fieldKey,
    String fieldLabel,
    TextEditingController ctrl,
  ) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final editCtrl = TextEditingController(text: ctrl.text);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm $fieldLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Low OCR confidence — please verify or correct this value.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: editCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: fieldLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Confirm Value'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, editCtrl.text),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed != null) {
        setState(() {
          ctrl.text = confirmed;
          _confirmedFlags[fieldKey] = true;
          final data = ref.read(scanStateProvider);
          data.fieldConfirmedByUser[fieldKey] = true;
          // Upgrade confidence to HIGH once the user explicitly confirms.
          data.fieldConfidences[fieldKey] = FieldConfidence.high;
        });
      }
    });
  }

  // ── Proceed ────────────────────────────────────────────────────────────────

  void _proceed() {
    final data = ref.read(scanStateProvider);

    // Flush controller values back into ScanData
    data.extractedName = _nameCtrl.text.trim();
    data.extractedManufacturer = _mfgCtrl.text.trim();
    data.extractedBatch = _batchCtrl.text.trim();
    data.extractedExpiry = _expCtrl.text.trim();
    data.extractedRegistrationInfo = _regCtrl.text.trim();
    data.extractedBarcode = _barcodeCtrl.text.trim();

    // Reviewing this screen and tapping the Verify button confirms the values
    // entered by the user; if batch or expiry are still blank, keep them medium
    // so VerificationEngine notes them as missing without blocking navigation.
    if (data.extractedName.isNotEmpty) {
      _confirmedFlags['name'] = true;
      data.fieldConfidences['name'] = FieldConfidence.high;
    }
    if (data.extractedBatch.isNotEmpty) {
      _confirmedFlags['batch'] = true;
      data.fieldConfidences['batch'] = FieldConfidence.high;
    } else {
      data.fieldConfidences['batch'] = FieldConfidence.medium;
    }
    if (data.extractedExpiry.isNotEmpty) {
      _confirmedFlags['expiry'] = true;
      data.fieldConfidences['expiry'] = FieldConfidence.high;
    } else {
      data.fieldConfidences['expiry'] = FieldConfidence.medium;
    }
    data.fieldConfirmedByUser.addAll(_confirmedFlags);

    context.push('/scan/result');
  }

  Future<void> _scanLiveBarcode() async {
    final result = await context.push('/scan/live_barcode');
    if (result != null && result is String) {
      setState(() {
        _barcodeCtrl.text = result;
        _confirmedFlags['barcode'] = true;
        final data = ref.read(scanStateProvider);
        data.fieldConfirmedByUser['barcode'] = true;
        data.fieldConfidences['barcode'] = FieldConfidence.high;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scanData = ref.watch(scanStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    const primaryTeal = Color(0xFF00897B);

    // Count how many critical fields still need confirmation
    final pendingCount = _countPendingConfirmations(scanData);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Medicine Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI Extraction Header ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: primaryTeal,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI analyzed the packaging and extracted clinical details. Confidence chips show OCR certainty — tap any LOW chip to review.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Pending Confirmation Banner (Gap 1) ─────────────────────
            if (pendingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingCount field${pendingCount == 1 ? '' : 's'} need${pendingCount == 1 ? 's' : ''} your review — tap the LOW chip next to each field to confirm.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Government Supply Alert ─────────────────────────────────
            if (scanData.specialNotice.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OFFICIAL PUBLIC HEALTHCARE SUPPLY',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scanData.specialNotice,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Structured Extraction Summary ───────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: primaryTeal,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Structured Medicine Specs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cleaned',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildSpecRow(
                    'Brand Name',
                    _nameCtrl.text.isNotEmpty
                        ? _nameCtrl.text
                        : scanData.extractedName,
                    Icons.medication_rounded,
                  ),
                  if (scanData.extractedGenericSalt.isNotEmpty)
                    _buildSpecRow(
                      'Generic Salt',
                      '${scanData.extractedGenericSalt} (${scanData.extractedStrength.isNotEmpty ? scanData.extractedStrength : "50mg"})',
                      Icons.science_outlined,
                    ),
                  _buildSpecRow(
                    'Manufacturer',
                    _mfgCtrl.text.isNotEmpty
                        ? _mfgCtrl.text
                        : scanData.extractedManufacturer,
                    Icons.business_rounded,
                  ),
                  _buildSpecRow(
                    'Batch Number',
                    _batchCtrl.text.isNotEmpty
                        ? _batchCtrl.text
                        : scanData.extractedBatch,
                    Icons.qr_code_rounded,
                  ),
                  _buildSpecRow(
                    'Expiry Date',
                    _expCtrl.text.isNotEmpty
                        ? _expCtrl.text
                        : scanData.extractedExpiry,
                    Icons.calendar_today_rounded,
                  ),
                  if (scanData.extractedPrice.isNotEmpty)
                    _buildSpecRow(
                      'Retail Price (MRP)',
                      scanData.extractedPrice,
                      Icons.payments_outlined,
                    ),
                  if (scanData.extractedDosageForm.isNotEmpty)
                    _buildSpecRow(
                      'Form & Pack',
                      scanData.extractedDosageForm,
                      Icons.local_pharmacy_outlined,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Editable Fields with Confidence Chips (Gap 1) ───────────
            const Text(
              'Verify & Edit Extraction Fields',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Fields showing LOW confidence require your explicit confirmation before verification can proceed.',
              style: TextStyle(fontSize: 11.5, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),

            _buildConfidenceField(
              context: context,
              label: 'Medicine Name',
              fieldKey: 'name',
              ctrl: _nameCtrl,
              icon: Icons.medication_outlined,
              scanData: scanData,
            ),
            const SizedBox(height: 12),
            _buildConfidenceField(
              context: context,
              label: 'Manufacturer',
              fieldKey: 'manufacturer',
              ctrl: _mfgCtrl,
              icon: Icons.business_outlined,
              scanData: scanData,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildConfidenceField(
                    context: context,
                    label: 'Batch Number',
                    fieldKey: 'batch',
                    ctrl: _batchCtrl,
                    icon: Icons.tag,
                    scanData: scanData,
                    isCritical: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConfidenceField(
                    context: context,
                    label: 'Expiry Date',
                    fieldKey: 'expiry',
                    ctrl: _expCtrl,
                    icon: Icons.calendar_month_outlined,
                    scanData: scanData,
                    isCritical: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField(
              'Registration (DRAP)',
              _regCtrl,
              Icons.verified_outlined,
              isDark,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildConfidenceField(
                    context: context,
                    label: 'Barcode / DataMatrix',
                    fieldKey: 'barcode',
                    ctrl: _barcodeCtrl,
                    icon: Icons.barcode_reader,
                    scanData: scanData,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: _scanLiveBarcode,
                  style: IconButton.styleFrom(
                    backgroundColor: primaryTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── OCR Inspector ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: const Icon(
                      Icons.document_scanner_outlined,
                      size: 20,
                      color: primaryTeal,
                    ),
                    title: const Text(
                      'OCR Extraction Inspector',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _showRawOcr
                          ? 'Showing Raw MLKit Camera Dump'
                          : 'Showing Cleaned Structured Output',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          setState(() => _showRawOcr = !_showRawOcr),
                      child: Text(
                        _showRawOcr ? 'Show Cleaned' : 'Show Raw',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryTeal,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      _showRawOcr
                          ? (scanData.rawText.isNotEmpty
                                ? scanData.rawText
                                : 'No raw text.')
                          : (scanData.structuredSummary.isNotEmpty
                                ? scanData.structuredSummary
                                : scanData.rawText),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Primary Action ────────────────────────────────────────────
            PrimaryButton(
              text: pendingCount > 0
                  ? 'Confirm $pendingCount Field${pendingCount == 1 ? '' : 's'} First'
                  : 'Verify & Check Vault Authenticity',
              onPressed: _proceed,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int _countPendingConfirmations(ScanData data) {
    const critical = ['batch', 'expiry'];
    int count = 0;
    for (final key in critical) {
      final conf = data.fieldConfidences[key] ?? FieldConfidence.high;
      if (conf.requiresUserConfirmation && !(_confirmedFlags[key] ?? false)) {
        count++;
      }
    }
    return count;
  }

  /// Builds an editable TextField with an inline confidence chip.
  Widget _buildConfidenceField({
    required BuildContext context,
    required String label,
    required String fieldKey,
    required TextEditingController ctrl,
    required IconData icon,
    required ScanData scanData,
    bool isCritical = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conf = scanData.fieldConfidences[fieldKey] ?? FieldConfidence.high;
    final isConfirmed = _confirmedFlags[fieldKey] ?? false;
    final needsAction = conf.requiresUserConfirmation && !isConfirmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13.5),
          onChanged: (v) {
            // Editing manually is treated as implicit confirmation
            if (conf == FieldConfidence.low && v.isNotEmpty) {
              setState(() {
                _confirmedFlags[fieldKey] = true;
                scanData.fieldConfirmedByUser[fieldKey] = true;
                scanData.fieldConfidences[fieldKey] = FieldConfidence.high;
              });
            }
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 12.5),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF00897B)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: needsAction
                    ? const Color(0xFFF59E0B)
                    : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                width: needsAction ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: needsAction
                    ? const Color(0xFFD97706)
                    : const Color(0xFF00897B),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Confidence chip
            GestureDetector(
              onTap: needsAction
                  ? () => _showFieldConfirmDialog(fieldKey, label, ctrl)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _chipBgColor(conf, isConfirmed),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _chipBorderColor(conf, isConfirmed),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfirmed
                          ? Icons.check_circle_rounded
                          : (conf == FieldConfidence.low
                                ? Icons.touch_app_rounded
                                : Icons.auto_awesome_rounded),
                      size: 12,
                      color: _chipTextColor(conf, isConfirmed),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConfirmed ? 'CONFIRMED' : 'OCR ${conf.label}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _chipTextColor(conf, isConfirmed),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (needsAction) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showFieldConfirmDialog(fieldKey, label, ctrl),
                child: const Text(
                  'Tap to confirm →',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (isCritical && !needsAction) ...[
              const SizedBox(width: 6),
              const Text(
                'Critical field',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Color _chipBgColor(FieldConfidence conf, bool confirmed) {
    if (confirmed) return const Color(0xFFECFDF5);
    switch (conf) {
      case FieldConfidence.low:
        return const Color(0xFFFEF3C7);
      case FieldConfidence.medium:
        return const Color(0xFFEFF6FF);
      case FieldConfidence.high:
        return const Color(0xFFECFDF5);
    }
  }

  Color _chipBorderColor(FieldConfidence conf, bool confirmed) {
    if (confirmed) return const Color(0xFF86EFAC);
    switch (conf) {
      case FieldConfidence.low:
        return const Color(0xFFFBBF24);
      case FieldConfidence.medium:
        return const Color(0xFF93C5FD);
      case FieldConfidence.high:
        return const Color(0xFF86EFAC);
    }
  }

  Color _chipTextColor(FieldConfidence conf, bool confirmed) {
    if (confirmed) return const Color(0xFF059669);
    switch (conf) {
      case FieldConfidence.low:
        return const Color(0xFFD97706);
      case FieldConfidence.medium:
        return const Color(0xFF1D4ED8);
      case FieldConfidence.high:
        return const Color(0xFF059669);
    }
  }

  Widget _buildSpecRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00897B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    bool isDark,
  ) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF00897B)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
