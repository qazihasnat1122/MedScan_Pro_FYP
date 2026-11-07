import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/safety_providers.dart';
import '../../providers/medication_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_settings_providers.dart';

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            strings.medicalRecords,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                text: 'Verification Audits',
                icon: Icon(Icons.verified_outlined, size: 20),
              ),
              Tab(
                text: 'Prescriptions',
                icon: Icon(Icons.receipt_long, size: 20),
              ),
              Tab(
                text: 'Safety Reports',
                icon: Icon(Icons.report_problem_outlined, size: 20),
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const TabBarView(
              children: [
                _ScansHistoryTab(),
                _PrescriptionsTab(),
                _ReportsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScansHistoryTab extends ConsumerWidget {
  const _ScansHistoryTab();

  Color _getStatusColor(String code) {
    switch (code) {
      case 'MANUFACTURER_SUPPORTED':
        return const Color(0xFF00897B); // Medical Teal
      case 'REFERENCE_AVAILABLE':
        return const Color(0xFF0284C7); // Clinical Blue
      case 'LIMITED_VERIFICATION':
        return const Color(0xFFD97706); // Amber
      case 'SUSPICIOUS_DETECTED':
        return const Color(0xFFDC2626); // Crimson
      case 'NO_REFERENCE_FOUND':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF00897B);
    }
  }

  IconData _getStatusIcon(String code) {
    switch (code) {
      case 'MANUFACTURER_SUPPORTED':
        return Icons.verified_user_rounded;
      case 'REFERENCE_AVAILABLE':
        return Icons.menu_book_rounded;
      case 'LIMITED_VERIFICATION':
        return Icons.help_outline_rounded;
      case 'SUSPICIOUS_DETECTED':
        return Icons.warning_amber_rounded;
      case 'NO_REFERENCE_FOUND':
        return Icons.search_off_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryTeal = Color(0xFF00897B);
    final historyAsync = ref.watch(verificationHistoryProvider);
    final records = historyAsync.value ?? [];
    final strings = ref.watch(appStringsProvider);
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

    if (records.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: primaryTeal,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Verification Audits Recorded',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan any pharmaceutical packaging, barcode, or DataMatrix to generate an evidence-based audit record.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => context.push('/scan/capture'),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(
                  strings.scanMedicine,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final item = records[index];
        final badgeColor = _getStatusColor(item.riskLevel);
        final label = item.statusLabel ?? item.riskLevel;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Icon(
                _getStatusIcon(item.riskLevel),
                color: badgeColor,
                size: 20,
              ),
            ),
            title: Text(
              item.medicineName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: textPrimary,
              ),
            ),
            subtitle: Text(
              '${item.verifiedAt.day}/${item.verifiedAt.month}/${item.verifiedAt.year} • Batch: ${item.batchNumber.isNotEmpty ? item.batchNumber : "N/A"}',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 3.13 Field 1: Observed Data
                    const Text(
                      '1. Observed Packaging Data',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.observedData.isNotEmpty)
                      ...item.observedData.entries.map(
                        (e) => _buildDetailRow(e.key, e.value, textMuted),
                      )
                    else
                      Text(
                        'Observed data not archived for this record.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    const Divider(height: 18),

                    // Section 3.13 Field 2: Reference Match
                    const Text(
                      '2. Reference Registry Match',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.referenceMatch.isNotEmpty)
                      ...item.referenceMatch.entries.map(
                        (e) => _buildDetailRow(e.key, e.value, textMuted),
                      )
                    else
                      Text(
                        'No linked reference metadata recorded.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    const Divider(height: 18),

                    // Section 3.13 Field 3: Unresolved Uncertainty
                    const Text(
                      '3. Unresolved Uncertainty',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.unresolvedUncertainty.isNotEmpty)
                      ...item.unresolvedUncertainty.map(
                        (u) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $u',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ),
                      )
                    else
                      const Text(
                        'No unresolved discrepancies noted at time of scan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionsTab extends ConsumerWidget {
  const _PrescriptionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryTeal = Color(0xFF00897B);
    final prescriptionsAsync = ref.watch(userPrescriptionsProvider);
    final prescriptions = prescriptionsAsync.value ?? [];
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

    if (prescriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: textMuted),
              const SizedBox(height: 12),
              Text(
                'No prescriptions uploaded yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Capture your doctor prescription to automatically extract medicine regimens.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/prescriptions/upload'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final p = prescriptions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          child: ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.description, color: Color(0xFF0284C7)),
            ),
            title: Text(
              'Prescription (${p.extractedMedicines.length} medicines)',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
            subtitle: Text(
              'Uploaded on ${p.uploadedAt.day}/${p.uploadedAt.month}/${p.uploadedAt.year}${p.prescriptionDate.isNotEmpty ? ' • Rx Date: ${p.prescriptionDate}' : ''}',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Confirmed Medicines:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...p.extractedMedicines.map(
                      (m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: primaryTeal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (p.imagePath.trim().isNotEmpty) ...[
                          TextButton.icon(
                            onPressed: () => _showDocumentAttachmentDialog(
                              context: context,
                              path: p.imagePath,
                              mimeType: p.mimeType,
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: primaryTeal,
                            ),
                            label: const Text(
                              'View Document',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final user = ref.read(authStateProvider).value;
                              if (user == null) return;
                              await ref
                                  .read(medicationRepositoryProvider)
                                  .removePrescriptionOriginalFile(
                                    p,
                                    currentUserId: user.uid,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Original prescription file deleted.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.hide_image_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Delete Stored File',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: () async {
                            final user = ref.read(authStateProvider).value;
                            if (user == null) return;
                            await ref
                                .read(medicationRepositoryProvider)
                                .deletePrescription(p, currentUserId: user.uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Prescription record deleted from history.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Delete Record',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentAttachmentDialog({
    required BuildContext context,
    required String path,
    required String mimeType,
  }) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return;
    final isPdf = mimeType.contains('pdf') || cleanPath.toLowerCase().endsWith('.pdf');
    final isRemote = cleanPath.startsWith('http://') || cleanPath.startsWith('https://');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  isPdf ? 'PDF Document' : 'Prescription Image',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  if (isRemote)
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open Link',
                      onPressed: () {
                        const MethodChannel('com.medscan.pro/document_picker')
                            .invokeMethod('launchExternalUri', {'uri': cleanPath});
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: isPdf
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 64,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cleanPath.split('/').last.split('\\').last,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                final uri = isRemote ? cleanPath : 'file://$cleanPath';
                                const MethodChannel('com.medscan.pro/document_picker')
                                    .invokeMethod('launchExternalUri', {'uri': uri});
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open PDF in System Viewer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: isRemote
                            ? Image.network(
                                cleanPath,
                                fit: BoxFit.contain,
                                loadingBuilder: (c, child, progress) => progress == null
                                    ? child
                                    : const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                errorBuilder: (context, error, stackTrace) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Unable to load prescription image from cloud.'),
                                ),
                              )
                            : Image.file(
                                File(cleanPath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Original file not found on local device storage.'),
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryTeal = Color(0xFF00897B);
    final reportsAsync = ref.watch(userReportsProvider);
    final reports = reportsAsync.value ?? [];
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

    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 64, color: textMuted),
              const SizedBox(height: 12),
              Text(
                'No safety reports submitted',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Found suspicious packaging or compromised medicine? File a confidential report with DRAP authorities.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/safety/report'),
                icon: const Icon(Icons.report_problem),
                label: const Text('Report Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final r = reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFEF3C7),
              child: Icon(Icons.report, color: Color(0xFFD97706)),
            ),
            title: Text(
              r.medicineName,
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
            subtitle: Text(
              'Status: ${r.status.toUpperCase()} • Batch: ${r.batchNumber.isNotEmpty ? r.batchNumber : "N/A"}',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: textMuted),
          ),
        );
      },
    );
  }
}
