import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../models/medicine_model.dart';
import 'public_app_bar.dart';
import 'public_footer.dart';

class MedicinesScreen extends ConsumerStatefulWidget {
  const MedicinesScreen({super.key});

  @override
  ConsumerState<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends ConsumerState<MedicinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(allPublicMedicinesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF040A0B),
      appBar: buildPublicAppBar(context, 'Medicine Directory'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroHeader(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 60,
                vertical: isMobile ? 16 : 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchAndFilterBox(),
                      SizedBox(height: isMobile ? 20 : 32),
                      medicinesAsync.when(
                        data: (medicines) {
                          final filtered = medicines.where((med) =>
                              med.medicineName.toLowerCase().contains(_searchQuery) ||
                              med.genericName.toLowerCase().contains(_searchQuery) ||
                              med.manufacturerName.toLowerCase().contains(_searchQuery)).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildResultsHeader(filtered.length),
                              const SizedBox(height: 20),
                              if (filtered.isEmpty)
                                const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No reference information found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 16))))
                              else if (_isGridView)
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: filtered.map((med) => SizedBox(
                                    width: isMobile ? double.infinity : 370,
                                    child: _buildMedicineGridCard(med),
                                  )).toList(),
                                )
                              else
                                Column(
                                  children: filtered.map((med) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: _buildMedicineGridCard(med),
                                  )).toList(),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))),
                        error: (err, stack) => Center(child: Text('Error loading medicines', style: TextStyle(color: Colors.red.shade300))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      width: double.infinity,
      color: const Color(0xFF071214),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: isMobile ? 24 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_user_outlined, color: Color(0xFF2DD4BF), size: 14),
                        SizedBox(width: 8),
                        Text('Public Medicine Reference Registry', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Medicine Directory & References',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Search registered medicine formulations, check manufacturer participation status, and inspect authorized packaging references.',
                    style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 14 : 16, height: 1.5),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showReportDialog,
                icon: const Icon(Icons.error_outline, size: 18),
                label: const Text('Report Suspicious Pack'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFCA5A5),
                  backgroundColor: const Color(0xFF450A0A).withValues(alpha: 0.3),
                  side: const BorderSide(color: Color(0xFF7F1D1D)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBox() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071214),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16373A)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search medicine name, generic molecule, manufacturer or reference number...',
                hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF475569)),
              ),
            ),
          ),
          const Divider(color: Color(0xFF16373A), height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.filter_alt_outlined, color: Color(0xFF64748B), size: 18),
                        SizedBox(width: 6),
                        Text('Filter:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                    _buildDropdown('Form: All'),
                    _buildDropdown('Manufacturer: All'),
                    _buildDropdown('All Verification Tiers'),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2023),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16373A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isGridView = true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isGridView ? const Color(0xFF2DD4BF) : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                          ),
                          child: Icon(Icons.grid_view, size: 18, color: _isGridView ? const Color(0xFF042F2E) : const Color(0xFF64748B)),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isGridView = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: !_isGridView ? const Color(0xFF2DD4BF) : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                          ),
                          child: Icon(Icons.list, size: 18, color: !_isGridView ? const Color(0xFF042F2E) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A191C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF16373A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 14),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Showing ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Text(' medicines', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
        const Text('Registry Source: MedScan Pro Reference DB', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ],
    );
  }

  Widget _buildMedicineGridCard(MedicineModel med) {
    return InkWell(
      onTap: () => context.go('/medicine/${med.id}'),
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF071214),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF16373A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(med.medicineName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: const Text('Tablet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text('${med.genericName} • ${med.strength}', style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 13)),
            const SizedBox(height: 16),
            Text('${med.medicineName} by ${med.manufacturerName}.. Registered pharmaceutical formulation.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SingleChildScrollView(
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2023),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF16373A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF450A0A).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7F1D1D)),
                      ),
                      child: const Icon(Icons.gpp_maybe, color: Color(0xFFFCA5A5), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Report Suspicious Medicine', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Submissions are reviewed by regulatory officers & manufacturer QA', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildDialogField('Medicine Name *', 'e.g. Panadol Extra or Augmentin 625mg'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDialogField('Batch Number', 'e.g. PE-24098')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDialogField('Manufacturer (if known)', 'e.g. GSK, Getz, Searle...')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDialogField('Purchase City / Pharmacy', 'e.g. Blue Area Islamabad or Mall Road Lahore'),
                const SizedBox(height: 16),
                _buildDialogField('Reason for Suspicion *', 'Describe defects: blurred print, missing hologram, unusual tablet color, broken seal...', maxLines: 3),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Suspicious package report submitted successfully. Thank you.')),
                        );
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Submit Anomaly Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E), // Rose red
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildDialogField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFF071214),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF16373A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF16373A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
            ),
          ),
        ),
      ],
    );
  }
}
