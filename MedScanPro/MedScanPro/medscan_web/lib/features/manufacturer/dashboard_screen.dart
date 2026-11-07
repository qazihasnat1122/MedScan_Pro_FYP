// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import 'package:intl/intl.dart';

class ManufacturerDashboard extends ConsumerWidget {
  const ManufacturerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProvider).value;
    final companyName = userProfile?.name ?? 'Pharmaceutical Organization';
    final medicinesAsync = ref.watch(medicinesProvider);
    final batchesAsync = ref.watch(batchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Executive Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          companyName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 5),
                              Text(
                                'DRAP Licensed Manufacturer',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'GS1 DataMatrix Serialization, Anti-Counterfeit Telemetry & Quality Control Gateway',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.public, size: 16),
                    label: const Text('View Public Catalog'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF087F8C),
                      side: const BorderSide(color: Color(0xFF087F8C)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/manufacturer/add_product'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Register Medicine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF087F8C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Executive KPI Cards & Quick Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final kpiCards = [
                _buildMetricCard(
                  title: 'Private Vault Medicines',
                  value: medicinesAsync.when(
                    data: (d) => '${d.length}',
                    loading: () => '...',
                    error: (err, stack) => '0',
                  ),
                  subtitle: 'Formulations in Vault',
                  icon: Icons.medication_rounded,
                  color: const Color(0xFF087F8C),
                  onTap: () => context.go('/manufacturer/products'),
                ),
                _buildMetricCard(
                  title: 'Active Batches',
                  value: batchesAsync.when(
                    data: (d) => '${d.length}',
                    loading: () => '...',
                    error: (err, stack) => '0',
                  ),
                  subtitle: 'GS1 Serialized Units',
                  icon: Icons.layers_rounded,
                  color: const Color(0xFF0284C7),
                  onTap: () => context.go('/manufacturer/batches'),
                ),
                _buildMetricCard(
                  title: 'Verification Requests',
                  value: '12,845',
                  subtitle: 'Live API Checks',
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => context.go('/manufacturer/verification_data'),
                ),
                _buildMetricCard(
                  title: 'Suspicious Scans',
                  value: '42',
                  subtitle: 'Anomalies Flagged',
                  icon: Icons.report_problem_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => context.go('/manufacturer/suspicious_reports'),
                ),
              ];

              final actionCards = [
                _buildQuickActionCard(
                  title: '1. Register New Medicine',
                  subtitle: 'Save formula, generic salts, DRAP registration & safety specs.',
                  icon: Icons.post_add_rounded,
                  color: const Color(0xFF087F8C),
                  buttonText: 'Open Form',
                  onTap: () => context.go('/manufacturer/add_product'),
                ),
                _buildQuickActionCard(
                  title: '2. Serialize New Batch',
                  subtitle: 'Generate cryptographic 2D DataMatrix batch identifiers.',
                  icon: Icons.barcode_reader,
                  color: const Color(0xFF0284C7),
                  buttonText: 'Add Batch',
                  onTap: () => context.go('/manufacturer/add_batch'),
                ),
                _buildQuickActionCard(
                  title: '3. Packaging Security Standard',
                  subtitle: 'Upload official packaging photos, microprints & holograms.',
                  icon: Icons.inventory_rounded,
                  color: const Color(0xFF10B981),
                  buttonText: 'Add Standard',
                  onTap: () => context.go('/manufacturer/add_packaging'),
                ),
              ];

              return Column(
                children: [
                  if (isNarrow)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: constraints.maxWidth < 600 ? 1 : 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.8,
                      children: kpiCards,
                    )
                  else
                    Row(
                      children: kpiCards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 28),
                  if (isNarrow)
                    Column(
                      children: actionCards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: c,
                              ))
                          .toList(),
                    )
                  else
                    Row(
                      children: actionCards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Dual Column: Recent Formulations & Recent Batches
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              
              final vaultCol = Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFF087F8C)),
                            SizedBox(width: 8),
                            Text(
                              'Company Product Vault',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.go('/manufacturer/products'),
                          child: const Text('View All', style: TextStyle(color: Color(0xFF087F8C), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    medicinesAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                      error: (e, _) => Text('Error loading vault: $e'),
                      data: (meds) {
                        if (meds.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No medicines registered yet. Use "Register Medicine" above.', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return Column(
                          children: meds.take(4).map((m) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF087F8C).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.medication_rounded, size: 20, color: Color(0xFF087F8C)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        Text('${m.genericName} • ${m.dosageForm}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m.referenceNumber.isNotEmpty ? m.referenceNumber : 'Approved',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );

              final batchesCol = Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.layers_rounded, size: 20, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Text(
                              'Recent Production Batches',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.go('/manufacturer/batches'),
                          child: const Text('View All', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    batchesAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                      error: (e, _) => Text('Error loading batches: $e'),
                      data: (batches) {
                        if (batches.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No batches created yet. Click "Serialize New Batch" above.', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return Column(
                          children: batches.take(4).map((b) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.batchNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        Text('Expires: ${DateFormat.yMMMd().format(DateTime.tryParse(b.expiryDate) ?? DateTime.now())}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${b.totalUnitsReleased} Units',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
              
              if (isNarrow) {
                return Column(
                  children: [
                    vaultCol,
                    const SizedBox(height: 24),
                    batchesCol,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: vaultCol),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: batchesCol),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
