import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scan_providers.dart';
import '../../repositories/medicine_lookup_repository.dart';

class SameSaltFinderScreen extends ConsumerStatefulWidget {
  final String? initialSalt;
  const SameSaltFinderScreen({super.key, this.initialSalt});

  @override
  ConsumerState<SameSaltFinderScreen> createState() =>
      _SameSaltFinderScreenState();
}

class _SameSaltFinderScreenState extends ConsumerState<SameSaltFinderScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  SameSaltResult? _searchResult;
  bool _isLoading = false;
  String? _searchedQuery;

  final List<String> _quickSearches = [
    'Panadol',
    'Augmentin',
    'Glucophage',
    'Voltral',
    'Disprin',
    'Brufen',
    'Paracetamol',
  ];

  @override
  void initState() {
    super.initState();
    final scanData = ref.read(scanStateProvider);
    final saltToUse =
        widget.initialSalt ??
        (scanData.extractedGenericSalt.isNotEmpty
            ? scanData.extractedGenericSalt
            : (scanData.extractedName.isNotEmpty
                  ? scanData.extractedName
                  : ''));
    if (saltToUse.isNotEmpty) {
      _searchCtrl.text = saltToUse;
      _performSearch(saltToUse);
    } else {
      _searchCtrl.text = 'Panadol';
      _performSearch('Panadol');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchedQuery = clean;
    });

    try {
      final repo = ref.read(medicineLookupProvider);
      final result = await repo.findSameSaltAlternatives(clean);
      if (mounted) {
        setState(() {
          _searchResult = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00897B);
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

    final res = _searchResult;
    final exact = res?.exactMatches ?? [];
    final other = res?.otherFormulations ?? [];
    final totalCount = (res?.totalCount ?? 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Same-Salt Alternative Finder',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // 1. Search Bar & Quick Suggestion Chips
              Container(
                padding: const EdgeInsets.all(16),
                color: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'Search brand or active salt (e.g. Panadol, Paracetamol)...',
                        hintStyle: TextStyle(fontSize: 13, color: textMuted),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: primaryTeal,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryTeal,
                          ),
                          onPressed: () => _performSearch(_searchCtrl.text),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _performSearch,
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickSearches.map((item) {
                          final isSelected =
                              _searchedQuery?.toLowerCase() ==
                              item.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isSelected
                                      ? Colors.white
                                      : primaryTeal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: isSelected
                                  ? primaryTeal
                                  : primaryTeal.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : primaryTeal.withValues(alpha: 0.2),
                              ),
                              onPressed: () {
                                _searchCtrl.text = item;
                                _performSearch(item);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Clinical Substitution Notice
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF087F8C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Always confirm brand substitutions with your doctor or pharmacist.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Search Results or Honest Empty State
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (res == null || totalCount == 0)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color: textMuted,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Registered Formulations Found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No registered alternatives were found in the official DRAP database for "$_searchedQuery". Ensure the medicine or salt name is spelled accurately. MedScan Pro does not fabricate unverified alternatives.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Salt Summary Banner
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: primaryTeal.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  color: primaryTeal,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'Active Salt: ',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 12,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: res.activeSalt,
                                          style: const TextStyle(
                                            color: primaryTeal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        if (res.sourceMedicine != null) ...[
                                          const TextSpan(
                                            text: ' • Reference: ',
                                          ),
                                          TextSpan(
                                            text: res.sourceMedicine!.brandName,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Section A: Exact Bioequivalent Matches
                          if (exact.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                                top: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Exact Bioequivalent Alternatives (${exact.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...exact.map(
                              (c) => _buildMedicineCard(
                                context,
                                c,
                                cardBg,
                                borderColor,
                                textPrimary,
                                textMuted,
                                isExact: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Section B: Alternative Strengths & Formulations
                          if (other.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                                top: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Other Formulations & Strengths (${other.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...other.map(
                              (c) => _buildMedicineCard(
                                context,
                                c,
                                cardBg,
                                borderColor,
                                textPrimary,
                                textMuted,
                                isExact: false,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineCard(
    BuildContext context,
    SameSaltCandidate candidate,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted, {
    required bool isExact,
  }) {
    final med = candidate.medicine;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isExact
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    med.medicineName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00897B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    med.referencePrice > 0
                        ? 'Rs. ${med.referencePrice.toStringAsFixed(0)}'
                        : 'Ref Price N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isExact
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isExact
                        ? 'Exact Bioequivalent'
                        : 'Alternative Form / Strength',
                    style: TextStyle(
                      color: isExact
                          ? const Color(0xFF059669)
                          : const Color(0xFF0284C7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    med.genericName,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildBadge(
                    Icons.business_outlined,
                    med.companyName.isNotEmpty
                        ? med.companyName
                        : med.manufacturerId,
                    textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  Icons.medication_outlined,
                  '${med.dosageForm} • ${med.strength}',
                  textMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Evidence: ${candidate.evidenceSource}',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
