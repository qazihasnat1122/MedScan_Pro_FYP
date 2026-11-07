// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/batch_model.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class _BatchDataSource extends DataTableSource {
  final List<BatchModel> batches;
  final BuildContext context;
  final Function(BatchModel) onViewIdentifiers;

  _BatchDataSource({
    required this.batches,
    required this.context,
    required this.onViewIdentifiers,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= batches.length) return null;
    final b = batches[index];
    final isExpired = DateTime.tryParse(b.expiryDate)?.isBefore(DateTime.now()) ?? false;
    
    return DataRow(
      cells: [
        DataCell(Text(b.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(b.medicineId.isNotEmpty ? b.medicineId : "Active Formulation")),
        DataCell(Text(DateFormat.yMMMd().format(DateTime.tryParse(b.manufacturingDate) ?? DateTime.now()))),
        DataCell(Text(DateFormat.yMMMd().format(DateTime.tryParse(b.expiryDate) ?? DateTime.now()), style: TextStyle(color: isExpired ? Colors.red : null))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isExpired ? 'EXPIRED' : b.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF059669),
              ),
            ),
          ),
        ),
        DataCell(Text('${b.totalUnitsReleased} Serial Units')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0284C7)),
            tooltip: 'View Identifiers',
            onPressed: () => onViewIdentifiers(b),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => batches.length;

  @override
  int get selectedRowCount => 0;
}

class BatchesScreen extends ConsumerStatefulWidget {
  const BatchesScreen({super.key});

  @override
  ConsumerState<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends ConsumerState<BatchesScreen> {
  String _searchQuery = '';

  void _showBatchIdentifiersModal(BuildContext context, BatchModel batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0284C7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch: ${batch.batchNumber}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${batch.totalUnitsReleased} Cryptographic GS1 Identifiers Serialized',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Expiry: ${DateFormat.yMMMd().format(DateTime.tryParse(batch.expiryDate) ?? DateTime.now())} • Status: ${batch.status.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Serialized Unit Matrix Codes:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: batch.totalUnitsReleased == 0
                    ? const Center(child: Text('No individual unit codes defined in this batch.'))
                    : ListView.separated(
                        itemCount: batch.totalUnitsReleased,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final id = '${batch.batchNumber}-U${i.toString().padLeft(4, "0")}';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            ),
                            title: Text(
                              id,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            trailing: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(currentUserProvider).value;
    final companyName = userProfile?.name ?? 'Pharmaceutical Organization';
    final batchesAsync = ref.watch(batchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '$companyName • Batches',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 13, color: Color(0xFF2563EB)),
                        SizedBox(width: 5),
                        Text(
                          'Private Serialization Vault',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Serial numbers and packaging matrices below are isolated to your firm and DRAP registry.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search batches by Batch Number, Medicine ID, or Status...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(height: 20),

          // Data Table
          batchesAsync.when(
            loading: () => const LoadingState(),
            error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(batchesProvider)),
            data: (batches) {
              final filtered = batches.where((b) {
                if (_searchQuery.isEmpty) return true;
                return b.batchNumber.toLowerCase().contains(_searchQuery) ||
                    b.medicineId.toLowerCase().contains(_searchQuery) ||
                    b.status.toLowerCase().contains(_searchQuery);
              }).toList();

              if (batches.isEmpty) {
                return const EmptyState(
                  message: 'No batches registered yet.',
                  icon: Icons.layers_outlined,
                );
              }

              if (filtered.isEmpty) {
                return const EmptyState(
                  message: 'No batches match your search query.',
                  icon: Icons.search_off_rounded,
                );
              }

              final dataSource = _BatchDataSource(
                batches: filtered,
                context: context,
                onViewIdentifiers: (b) => _showBatchIdentifiersModal(context, b),
              );

              return Theme(
                data: Theme.of(context).copyWith(
                  // Clean theme for data table
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 56),
                    child: PaginatedDataTable(
                      header: const Text('Registered Batches', style: TextStyle(fontWeight: FontWeight.bold)),
                      columns: const [
                        DataColumn(label: Text('Batch Number')),
                        DataColumn(label: Text('Medicine ID')),
                        DataColumn(label: Text('Mfg Date')),
                        DataColumn(label: Text('Exp Date')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Units')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: dataSource,
                      rowsPerPage: (filtered.length > 10) ? 10 : (filtered.isEmpty ? 1 : filtered.length),
                      showCheckboxColumn: false,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
