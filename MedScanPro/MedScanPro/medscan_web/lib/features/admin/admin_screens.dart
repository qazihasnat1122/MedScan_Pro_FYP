import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/analytics_providers.dart';

class AdminPlaceholderScreen extends ConsumerStatefulWidget {
  final String title;
  const AdminPlaceholderScreen(this.title, {super.key});

  @override
  ConsumerState<AdminPlaceholderScreen> createState() => _AdminPlaceholderScreenState();
}

class _AdminPlaceholderScreenState extends ConsumerState<AdminPlaceholderScreen> {
  static const Color darkSlate = AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF087F8C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF087F8C), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkSlate),
                      ),
                      const SizedBox(height: 2),
                      const Text('DRAP & National Drug Regulatory Administration Console', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final isDesktop = MediaQuery.of(context).size.width >= 960;
                    return ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: isDesktop ? const Text('New Entry / Action') : const Text('New'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF087F8C),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DYNAMIC CONTENT ACCORDING TO SCREEN
            if (widget.title.contains('Dashboard')) ...[
              _buildAdminDashboardView(),
            ] else if (widget.title.contains('Medicines')) ...[
              _buildMedicinesView(),
            ] else if (widget.title.contains('Manufacturers')) ...[
              _buildManufacturersView(),
            ] else if (widget.title.contains('Approvals')) ...[
              _buildPendingApprovalsView(),
            ] else if (widget.title.contains('Alerts')) ...[
              _buildSystemAlertsView(),
            ] else if (widget.title.contains('Reports')) ...[
              _buildReportsTriageView(),
            ] else if (widget.title.contains('Verification')) ...[
              _buildVerificationActivityView(),
            ] else if (widget.title.contains('Users')) ...[
              _buildAuthorizedUsersView(),
            ] else if (widget.title.contains('Audit Log')) ...[
              _buildAuditLogView(),
            ] else if (widget.title.contains('Settings')) ...[
              _buildSettingsView(),
            ] else ...[
              _buildGeneralTableView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDashboardView() {
    final allMeds = ref.watch(allPublicMedicinesProvider);
    final allBatches = ref.watch(allPublicBatchesProvider);
    
    final medCount = allMeds.when(data: (d) => '${d.length}', loading: () => '...', error: (e, s) => '0');
    final batchCount = allBatches.when(data: (d) => '${d.length}', loading: () => '...', error: (e, s) => '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final cards = [
              _buildMetricCard('Total National Formulations', medCount, 'Medicines Registered', Icons.medication_rounded, const Color(0xFF087F8C)),
              _buildMetricCard('Active Serialized Batches', batchCount, 'Tracked & Traced', Icons.layers_rounded, const Color(0xFF16B8A6)),
              _buildMetricCard('Active Recall Advisories', '0', 'Public Safety Recalls', Icons.warning_amber_rounded, const Color(0xFFEF4444)),
              _buildMetricCard('Pending Approvals', '0', 'Awaiting Sign-off', Icons.pending_actions_rounded, const Color(0xFFF59E0B)),
            ];

            if (isNarrow) {
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth < 600 ? 1 : 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: cards,
              );
            }
            return Row(
              children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: c))).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        _buildCardWrapper(
          title: 'National Verification Breakdown',
          child: Column(
            children: [
              _buildAuditRow('Manufacturer Supported vs Reference Match', 'Ratio', 'STABLE', '85% / 15%', Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicinesView() {
    final allMeds = ref.watch(allPublicMedicinesProvider);

    return _buildCardWrapper(
      title: 'National Medicines Directory',
      child: allMeds.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
        error: (err, stack) => Padding(padding: const EdgeInsets.all(20), child: Text('Error: $err')),
        data: (meds) {
          if (meds.isEmpty) {
            return const Padding(padding: EdgeInsets.all(20), child: Text('No medicines registered nationally.', style: TextStyle(color: AppColors.textSecondary)));
          }
          return Column(
            children: meds.map((m) => _buildAuditRow(
              m.medicineName,
              m.genericName,
              m.verificationLevel,
              '${m.manufacturerName} • Reg: ${m.referenceNumber}',
              m.verificationLevel.contains('Supported') ? Colors.green : Colors.orange,
            )).toList(),
          );
        },
      ),
    );
  }

  Widget _buildManufacturersView() {
    return _buildCardWrapper(
      title: 'Licensed Pharmaceutical Manufacturers',
      child: Column(
        children: [
          _buildAuditRow('GlaxoSmithKline Pakistan Ltd.', 'Manufacturing License: DRAP-LIC-0042', 'Active / Verified Partner', 'Karachi Industrial Area • 142 Formulations', Colors.green),
          _buildAuditRow('Getz Pharma', 'Manufacturing License: DRAP-LIC-0081', 'Active / Verified Partner', 'Korangi, Karachi • 89 Formulations', Colors.green),
          _buildAuditRow('Abbott Laboratories', 'Manufacturing License: DRAP-LIC-0012', 'Active / Verified Partner', 'Landhi, Karachi • 110 Formulations', Colors.green),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsView() {
    return _buildCardWrapper(
      title: 'Regulatory Approvals Queue',
      child: Column(
        children: [
          _buildApprovalCard('GSK Pakistan Ltd', 'Batch Lot Release', 'v2.4', 'PENDING APPROVAL'),
          _buildApprovalCard('Getz Pharma', 'Master Packaging Specification', 'v1.1', 'REQUEST CLARIFICATION'),
        ],
      ),
    );
  }

  Widget _buildSystemAlertsView() {
    return _buildCardWrapper(
      title: 'Emergency Safety Alerts Manager',
      child: Column(
        children: [
          _buildAlertCard('DRAP-ALERT-2026-09', 'Augmentin 625mg', 'AUG-8821', 'High', 'Active'),
        ],
      ),
    );
  }

  Widget _buildReportsTriageView() {
    return _buildCardWrapper(
      title: 'Citizen Counterfeit Reports Triage',
      child: Column(
        children: [
          _buildAuditRow('Panadol Extend', 'Batch: PAN-5001', 'Under Review', 'Reported Pharmacy: Saddar, Karachi • Citizen: "Faded printing on packaging"', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildVerificationActivityView() {
    final allScans = ref.watch(allPublicScanEventsProvider);

    return _buildCardWrapper(
      title: 'National Verification Audit Stream',
      child: allScans.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
        error: (err, stack) => Padding(padding: const EdgeInsets.all(20), child: Text('Error: $err')),
        data: (scans) {
          if (scans.isEmpty) {
            return const Padding(padding: EdgeInsets.all(20), child: Text('No verification activity logged yet.', style: TextStyle(color: AppColors.textSecondary)));
          }
          return Column(
            children: scans.map((s) => _buildAuditRow(
              s.medicineId,
              'Batch: ${s.batchNumber}',
              s.verificationResult,
              '${s.approximateLocation} • Timestamp: ${s.timestamp.toLocal().toString().split('.')[0]}',
              s.verificationResult.contains('100%') ? Colors.green : Colors.red,
            )).toList(),
          );
        },
      ),
    );
  }

  Widget _buildAuthorizedUsersView() {
    return _buildCardWrapper(
      title: 'Authorized Portal Users',
      child: Column(
        children: [
          _buildAuditRow('Dr. Ahmad Ali', 'Federal Drug Inspector', 'Active Security Clearance', 'ahmad.ali@drap.gov.pk', Colors.green),
          _buildAuditRow('Sara Khan', 'Manufacturer Compliance Liaison', 'Active Security Clearance', 'sara.khan@gsk.com', Colors.green),
        ],
      ),
    );
  }

  Widget _buildAuditLogView() {
    return _buildCardWrapper(
      title: 'Immutable Security Audit Log',
      child: Column(
        children: [
          _buildAuditRow('2026-10-10T14:22:01Z', 'regulatory.officer@drap.gov.pk', 'BATCH_QUARANTINED', 'Target: AUG-8821 • IP: 192.168.1.45', Colors.red),
          _buildAuditRow('2026-10-10T10:15:00Z', 'ahmad.ali@drap.gov.pk', 'ARTWORK_APPROVED', 'Target: PAN-5001-ART • IP: 192.168.1.12', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSettingsView() {
    return _buildCardWrapper(
      title: 'Registry Settings',
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('National serialization rules configuration, GS1 2D DataMatrix compliance thresholds, and duplicate scan sensitivity levels.', style: TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildGeneralTableView() {
    return const Center(child: Text('Placeholder Screen for Admin', style: TextStyle(color: AppColors.textSecondary)));
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Live', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }

  Widget _buildAuditRow(String col1, String col2, String status, String desc, Color statusColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(col1, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(col2, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(col1, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(col2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalCard(String company, String type, String version, String status) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final actionButtons = [
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF087F8C), foregroundColor: Colors.white),
            child: const Text('APPROVE & SIGN'),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), side: const BorderSide(color: Color(0xFFF59E0B))),
            child: const Text('REQUEST CLARIFICATION'),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
            child: const Text('REJECT / QUARANTINE'),
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('$type • Version: $version', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actionButtons,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(company, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('$type • Version: $version', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actionButtons,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAlertCard(String ref, String medicine, String batch, String severity, String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alert Ref: $ref', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Affected: $medicine • Batch: $batch', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Severity: $severity', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('Status: $status', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert Ref: $ref', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Affected: $medicine • Batch: $batch', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Text('Severity: $severity', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Text('Status: $status', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ],
          );
        },
      ),
    );
  }
}
