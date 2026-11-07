import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scan_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/verification_providers.dart';
import '../../models/batch_model.dart';
import '../../models/scan_event_model.dart';
import '../../models/verification_record_model.dart';
import '../../shared/widgets/primary_button.dart';
import '../../services/verification_engine.dart';

// ---------------------------------------------------------------------------
// LookupResultScreen — Gaps 2, 4, 5
// ---------------------------------------------------------------------------
// Gap 2: The 3-field audit breakdown (Observed Data, Reference Match,
//        Unresolved Uncertainty) is now exposed inside a persistent DraggableScrollableSheet
//        so users can always deep-dive regardless of verification state.
//
// Gap 4: When previousScanCount > 2 a dedicated anomaly warning card appears
//        prominently at the top of the result page with scan-frequency details.
//
// Gap 5: A 1-tap "Report this medicine" button appears on SUSPICIOUS_DETECTED
//        and NO_REFERENCE_FOUND states, wired to VerificationService.submitSuspiciousReport().
// ---------------------------------------------------------------------------

class LookupResultScreen extends ConsumerStatefulWidget {
  const LookupResultScreen({super.key});

  @override
  ConsumerState<LookupResultScreen> createState() => _LookupResultScreenState();
}

class _LookupResultScreenState extends ConsumerState<LookupResultScreen> {
  bool _isLoading = true;
  String? _error;
  VerificationResult? _result;
  int _previousScanCount = 0;
  bool _reportSubmitted = false;
  bool _isSubmittingReport = false;

  // Cached fields for the report
  String _resolvedIdentifier = '';
  String _resolvedName = '';
  String _resolvedBatch = '';

  @override
  void initState() {
    super.initState();
    _performVerification();
  }

  Future<void> _performVerification() async {
    try {
      final repo = ref.read(medicineLookupProvider);
      final verifService = ref.read(verificationServiceProvider);
      final engine = ref.read(verificationEngineProvider);
      final data = ref.read(scanStateProvider);
      final user = ref.read(authStateProvider).value;

      var meds = await repo
          .searchMedicines(data.extractedName)
          .timeout(const Duration(seconds: 2), onTimeout: () => []);

      if (meds.isEmpty && data.extractedGenericSalt.isNotEmpty) {
        meds = await repo
            .searchMedicines(data.extractedGenericSalt)
            .timeout(const Duration(seconds: 2), onTimeout: () => []);
      }
      if (meds.isEmpty && data.extractedBatch.isNotEmpty) {
        meds = await repo
            .searchMedicines(data.extractedBatch)
            .timeout(const Duration(seconds: 2), onTimeout: () => []);
      }

      List<BatchModel> matchingBatches = [];
      if (data.extractedBatch.isNotEmpty) {
        if (meds.isNotEmpty) {
          for (var m in meds) {
            try {
              final b = await repo
                  .searchBatches(m.medicineId, data.extractedBatch)
                  .timeout(const Duration(seconds: 2), onTimeout: () => []);
              matchingBatches.addAll(b);
            } catch (_) {}
          }
        }
        if (matchingBatches.isEmpty) {
          try {
            final b = await repo
                .searchBatches('', data.extractedBatch)
                .timeout(const Duration(seconds: 2), onTimeout: () => []);
            matchingBatches.addAll(b);
            if (meds.isEmpty && matchingBatches.isNotEmpty) {
              final foundMeds = await repo.searchMedicines(
                matchingBatches.first.medicineId,
              );
              if (foundMeds.isNotEmpty) meds = foundMeds;
            }
          } catch (_) {}
        }
      }

      final identifier = data.extractedBarcode.isNotEmpty
          ? data.extractedBarcode
          : data.extractedBatch;
      final scanCount = await verifService
          .getIdentifierScanCount(identifier)
          .timeout(const Duration(seconds: 2), onTimeout: () => 0);

      final result = engine.verify(
        scanData: data,
        matchedMedicines: meds,
        matchedBatches: matchingBatches,
        previousScanCount: scanCount,
      );

      final activeUserId = user?.uid ?? 'consumer_mobile_app';
      final resolvedName = meds.isNotEmpty
          ? meds.first.medicineName
          : (data.extractedName.isNotEmpty
                ? data.extractedName
                : 'Scanned Medicine');
      final resolvedMfg = meds.isNotEmpty
          ? meds.first.manufacturerId
          : (data.extractedManufacturer.isNotEmpty
                ? data.extractedManufacturer
                : 'UNASSIGNED');

      // Cache for report submission (Gap 5)
      _resolvedIdentifier = identifier;
      _resolvedName = resolvedName;
      _resolvedBatch = data.extractedBatch.isNotEmpty
          ? data.extractedBatch
          : 'NOT_DETECTED';

      // Log Scan Event with Section 8 verification states & 3 audit fields
      final event = ScanEventModel(
        eventId: '',
        userId: activeUserId,
        identifier: identifier,
        medicineId: meds.isNotEmpty ? meds.first.medicineId : 'unknown',
        medicineName: resolvedName,
        manufacturerId: resolvedMfg,
        batchNumber: data.extractedBatch.isNotEmpty
            ? data.extractedBatch
            : 'NOT_DETECTED',
        timestamp: DateTime.now(),
        resultCode: result.state.code,
        verificationResult: result.state.label,
        approximateLocation: 'Pakistan (Consumer Mobile Device)',
        reasons: result.reasons,
        observedData: result.audit.observedData,
        referenceMatch: result.audit.referenceMatch,
        unresolvedUncertainty: result.audit.unresolvedUncertainty,
      );
      verifService.logScanEvent(event).ignore();

      // Log Verification Record with Section 8 vocabulary
      final record = VerificationRecordModel(
        id: '',
        userId: activeUserId,
        medicineName: resolvedName,
        batchNumber: data.extractedBatch,
        riskLevel: result.state.code,
        statusLabel: result.state.label,
        verifiedAt: DateTime.now(),
        observedData: result.audit.observedData,
        referenceMatch: result.audit.referenceMatch,
        unresolvedUncertainty: result.audit.unresolvedUncertainty,
      );
      verifService.logVerificationRecord(record).ignore();

      if (mounted) {
        setState(() {
          _result = result;
          _previousScanCount = scanCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── Gap 5: 1-tap suspicious report ──────────────────────────────────────

  Future<void> _submitSuspiciousReport() async {
    final user = ref.read(authStateProvider).value;
    final verifService = ref.read(verificationServiceProvider);

    setState(() => _isSubmittingReport = true);
    HapticFeedback.mediumImpact();

    await verifService.submitSuspiciousReport(
      identifier: _resolvedIdentifier,
      medicineName: _resolvedName,
      batchNumber: _resolvedBatch,
      resultCode: _result!.state.code,
      userId: user?.uid ?? 'anonymous',
    );

    if (mounted) {
      setState(() {
        _reportSubmitted = true;
        _isSubmittingReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report submitted. Regulatory staff will review this medicine.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00897B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Gap 2: Full audit bottom sheet ──────────────────────────────────────

  void _showAuditBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = _result!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (ctx2, scrollCtrl) {
            final cardBg = Theme.of(context).cardColor;
            final borderColor = isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0);

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          size: 20,
                          color: Color(0xFF00897B),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Full Verification Audit Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildAuditCard(
                          title: '1. Observed Packaging Data (Extracted)',
                          icon: Icons.camera_alt_outlined,
                          accentColor: const Color(0xFF00897B),
                          cardBg: cardBg,
                          borderColor: borderColor,
                          content: Column(
                            children: result.audit.observedData.entries
                                .map((e) => _buildKeyValueRow(e.key, e.value))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildAuditCard(
                          title: '2. Reference Registry Match',
                          icon: Icons.library_books_outlined,
                          accentColor: const Color(0xFF0284C7),
                          cardBg: cardBg,
                          borderColor: borderColor,
                          content: Column(
                            children: result.audit.referenceMatch.entries
                                .map((e) => _buildKeyValueRow(e.key, e.value))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildAuditCard(
                          title: '3. Unresolved Uncertainty & Notes',
                          icon: Icons.warning_amber_rounded,
                          accentColor:
                              result.audit.unresolvedUncertainty.isNotEmpty
                              ? const Color(0xFFD97706)
                              : const Color(0xFF00897B),
                          cardBg: cardBg,
                          borderColor: borderColor,
                          content: result.audit.unresolvedUncertainty.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'No unresolved discrepancies detected in scanned packaging fields.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF00897B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: result.audit.unresolvedUncertainty
                                      .map(
                                        (u) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '• ',
                                                style: TextStyle(
                                                  color: Color(0xFFD97706),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  u,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 20),
                        // Verification reasons
                        _buildAuditCard(
                          title: '4. Verification Reasoning',
                          icon: Icons.fact_check_outlined,
                          accentColor: _getStateColor(result.state),
                          cardBg: cardBg,
                          borderColor: borderColor,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: result.reasons
                                .map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.arrow_right_rounded,
                                          size: 18,
                                          color: _getStateColor(result.state),
                                        ),
                                        Expanded(
                                          child: Text(
                                            r,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── State helpers ────────────────────────────────────────────────────────

  Color _getStateColor(VerificationState state) {
    switch (state) {
      case VerificationState.manufacturerSupported:
        return const Color(0xFF00897B);
      case VerificationState.referenceAvailable:
        return const Color(0xFF0284C7);
      case VerificationState.limitedVerification:
        return const Color(0xFFD97706);
      case VerificationState.suspiciousDetected:
        return const Color(0xFFDC2626);
      case VerificationState.noReferenceFound:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStateIcon(VerificationState state) {
    switch (state) {
      case VerificationState.manufacturerSupported:
        return Icons.verified_user_rounded;
      case VerificationState.referenceAvailable:
        return Icons.menu_book_rounded;
      case VerificationState.limitedVerification:
        return Icons.help_outline_rounded;
      case VerificationState.suspiciousDetected:
        return Icons.warning_amber_rounded;
      case VerificationState.noReferenceFound:
        return Icons.search_off_rounded;
    }
  }

  bool get _shouldShowReportButton {
    return _result != null &&
        (_result!.state == VerificationState.suspiciousDetected ||
            _result!.state == VerificationState.noReferenceFound);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification Audit Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'View Full Audit',
              onPressed: _showAuditBottomSheet,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Verification error: $_error'))
          : _result == null
          ? const Center(child: Text('Verification failed.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Gap 4: Anomaly Warning Card ─────────────────────────
                  if (_previousScanCount > 2) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1308)
                            : const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _previousScanCount > 5
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFF59E0B),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (_previousScanCount > 5
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFD97706))
                                      .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _previousScanCount > 5
                                  ? Icons.report_problem_rounded
                                  : Icons.info_outline_rounded,
                              size: 20,
                              color: _previousScanCount > 5
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _previousScanCount > 5
                                      ? 'HIGH-FREQUENCY SCAN ANOMALY'
                                      : 'DUPLICATE SCAN DETECTED',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: _previousScanCount > 5
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'This identifier has been recorded $_previousScanCount time${_previousScanCount == 1 ? '' : 's'} across different scan sessions. '
                                  '${_previousScanCount > 5 ? 'Serial numbers should be unique — this frequency is unusual and may indicate re-use or counterfeiting.' : 'Verify that this is not a previously scanned unit.'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: isDark
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 1. Evidence-Based Verification State Banner (§8) ────
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStateColor(
                          _result!.state,
                        ).withValues(alpha: 0.12),
                        border: Border.all(
                          color: _getStateColor(_result!.state),
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        _getStateIcon(_result!.state),
                        size: 44,
                        color: _getStateColor(_result!.state),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _result!.state.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _getStateColor(_result!.state),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _result!.state.meaning,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Anti-Fabrication Regulatory Caution Banner (§1) ─
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF00897B),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Anti-Fabrication Notice: Database and packaging matches verify official registry alignment. Optical verification does not chemically test internal pharmaceutical contents.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Gap 2: Condensed 3-Field Audit Summary + "View Full Audit" CTA ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                size: 16,
                                color: Color(0xFF00897B),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Verification Audit Summary',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00897B),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showAuditBottomSheet,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Full Report',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0284C7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 18, indent: 14, endIndent: 14),
                        // Condensed audit rows
                        _buildAuditSummaryRow(
                          icon: Icons.camera_alt_outlined,
                          label: 'Observed',
                          value:
                              '${_result!.audit.observedData.length} fields captured from packaging',
                          color: const Color(0xFF00897B),
                        ),
                        _buildAuditSummaryRow(
                          icon: Icons.library_books_outlined,
                          label: 'Reference',
                          value: _result!.audit.referenceMatch.isEmpty
                              ? 'No registry match found'
                              : '${_result!.audit.referenceMatch.length} registry fields matched',
                          color: const Color(0xFF0284C7),
                        ),
                        _buildAuditSummaryRow(
                          icon: Icons.warning_amber_rounded,
                          label: 'Uncertainty',
                          value: _result!.audit.unresolvedUncertainty.isEmpty
                              ? 'None detected'
                              : '${_result!.audit.unresolvedUncertainty.length} unresolved item${_result!.audit.unresolvedUncertainty.length == 1 ? '' : 's'}',
                          color: _result!.audit.unresolvedUncertainty.isNotEmpty
                              ? const Color(0xFFD97706)
                              : const Color(0xFF00897B),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Gap 5: 1-Tap Suspicious Report Button ───────────────
                  if (_shouldShowReportButton) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _reportSubmitted
                          ? Container(
                              key: const ValueKey('reported'),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF86EFAC),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF059669),
                                    size: 22,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Report submitted successfully. Regulatory staff will review this medicine.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              key: const ValueKey('report-btn'),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C0A0A)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.flag_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Flag for Regulatory Review',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'If you suspect this medicine is counterfeit, expired, or otherwise unsafe, report it to DRAP with one tap. Your report is confidential.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSubmittingReport
                                          ? null
                                          : _submitSuspiciousReport,
                                      icon: _isSubmittingReport
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.report_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        _isSubmittingReport
                                            ? 'Submitting...'
                                            : 'Report this Medicine',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 4. Clinical Guidance & Alternatives ─────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: const Text(
                            'Same-Salt Finder',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: const Color(0xFF00897B),
                            side: const BorderSide(color: Color(0xFF00897B)),
                          ),
                          onPressed: () => context.push('/same-salt'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.price_check_rounded, size: 16),
                          label: const Text(
                            'Price Check',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                          onPressed: () => context.push('/price-check'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 5. Primary Dashboard Action ─────────────────────────
                  PrimaryButton(
                    text: 'Back to Dashboard',
                    onPressed: () => context.go('/'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _buildAuditSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    required Color borderColor,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          content,
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
