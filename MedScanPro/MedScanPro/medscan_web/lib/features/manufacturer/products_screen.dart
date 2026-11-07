// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/medicine_model.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';

class _MedicineDataSource extends DataTableSource {
  final List<MedicineModel> medicines;
  final BuildContext context;
  final Function(MedicineModel) onViewSpecifications;
  final Function(MedicineModel) onDelete;

  _MedicineDataSource({
    required this.medicines,
    required this.context,
    required this.onViewSpecifications,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= medicines.length) return null;
    final med = medicines[index];
    
    return DataRow(
      cells: [
        DataCell(Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(med.genericName)),
        DataCell(Text(med.medicineName.isNotEmpty ? med.medicineName : 'N/A')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              med.referenceNumber.isNotEmpty ? med.referenceNumber : 'Approved',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, color: Color(0xFF087F8C)),
                tooltip: 'Specifications',
                onPressed: () => onViewSpecifications(med),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                tooltip: 'Delete',
                onPressed: () => onDelete(med),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => medicines.length;

  @override
  int get selectedRowCount => 0;
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';

  void _showSpecificationModal(BuildContext context, MedicineModel med) {
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
                color: const Color(0xFF087F8C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF087F8C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.medicineName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Brand: ${med.medicineName.isNotEmpty ? med.medicineName : "Official"} • ${med.manufacturerName.isNotEmpty ? med.manufacturerName : "Private Vault"}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalDetailRow('Generic Active Salt', med.genericName, Icons.science_outlined),
                _buildModalDetailRow('Strength & Potency', med.strength, Icons.speed_outlined),
                _buildModalDetailRow('Dosage Form', med.dosageForm, Icons.pie_chart_outline),
                _buildModalDetailRow('Packaging / Pack Size', med.packagingSidesAvailable.join(', ').isNotEmpty ? med.packagingSidesAvailable.join(', ') : 'Standard Packaging', Icons.inventory_2_outlined),
                _buildModalDetailRow('DRAP Registration No', med.referenceNumber, Icons.verified_outlined),
                _buildModalDetailRow('Max Retail Price', med.approvedStatus, Icons.payments_outlined),
                const Divider(height: 24),
                const Text('Therapeutic Indications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(med.indications.isNotEmpty ? med.indications.join(', ') : 'Prescription indicated formulation.', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                const Text('Storage Specifications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(med.storageConditions.isNotEmpty ? med.storageConditions : 'Store below 30°C in dry conditions.', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                const Text('Safety Precautions & Warnings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626))),
                const SizedBox(height: 4),
                Text(med.description.isNotEmpty ? med.description : 'Take as advised by physician.', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
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

  Widget _buildModalDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF087F8C)),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MedicineModel med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Vault?'),
        content: Text('Are you sure you want to remove "${med.medicineName}" from your private company catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(manufacturerRepositoryProvider).deleteMedicine(med.id);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Removed ${med.medicineName}')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(currentUserProvider).value;
    final companyName = userProfile?.name ?? 'Pharmaceutical Organization';
    final medicinesAsync = ref.watch(medicinesProvider);

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
                    companyName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                        Icon(Icons.lock_rounded, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 5),
                        Text(
                          'Private Vault • Strict Company Isolation',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'All products and formulas below are isolated to your company. Add new products via the Dashboard Quick Actions.',
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
                hintText: 'Search your company products by name, active salt, brand, or DRAP reg...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(height: 20),

          // Data Table
          medicinesAsync.when(
            loading: () => const LoadingState(),
            error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(medicinesProvider)),
            data: (medicines) {
              final filtered = medicines.where((m) {
                if (_searchQuery.isEmpty) return true;
                return m.medicineName.toLowerCase().contains(_searchQuery) ||
                    m.medicineName.toLowerCase().contains(_searchQuery) ||
                    m.genericName.toLowerCase().contains(_searchQuery) ||
                    m.referenceNumber.toLowerCase().contains(_searchQuery);
              }).toList();

              if (medicines.isEmpty) {
                return const EmptyState(
                  message: 'Your company vault has no registered products yet.',
                  icon: Icons.inventory_2_outlined,
                );
              }

              if (filtered.isEmpty) {
                return const EmptyState(
                  message: 'No products match your search query.',
                  icon: Icons.search_off_rounded,
                );
              }

              final dataSource = _MedicineDataSource(
                medicines: filtered,
                context: context,
                onViewSpecifications: (med) => _showSpecificationModal(context, med),
                onDelete: (med) => _confirmDelete(context, med),
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
                      header: const Text('Registered Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
                      columns: const [
                        DataColumn(label: Text('Medicine Name')),
                        DataColumn(label: Text('Generic Salt')),
                        DataColumn(label: Text('Brand')),
                        DataColumn(label: Text('Registration')),
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

