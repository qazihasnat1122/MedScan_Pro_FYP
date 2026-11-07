import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scan_providers.dart';
import '../../models/medicine_model.dart';
import '../../shared/widgets/primary_button.dart';

class PriceCheckScreen extends ConsumerStatefulWidget {
  final String? medicineName;
  final double? referencePrice;
  const PriceCheckScreen({super.key, this.medicineName, this.referencePrice});

  @override
  ConsumerState<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends ConsumerState<PriceCheckScreen> {
  final TextEditingController _medicineCtrl = TextEditingController();
  final TextEditingController _printedPriceCtrl = TextEditingController();
  final TextEditingController _chargedPriceCtrl = TextEditingController();

  MedicineModel? _selectedMedicine;
  bool _isSearching = false;
  List<MedicineModel> _searchResults = [];
  _PriceAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    final scanData = ref.read(scanStateProvider);
    if (widget.medicineName != null && widget.medicineName!.isNotEmpty) {
      _medicineCtrl.text = widget.medicineName!;
      _searchMedicine(widget.medicineName!);
    } else if (scanData.extractedName.isNotEmpty) {
      _medicineCtrl.text = scanData.extractedName;
      if (scanData.extractedPrice.isNotEmpty) {
        final numOnly = scanData.extractedPrice.replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        _printedPriceCtrl.text = numOnly;
      }
      _searchMedicine(scanData.extractedName);
    } else {
      _medicineCtrl.text = 'Panadol 500mg';
      _searchMedicine('Panadol 500mg');
    }
  }

  @override
  void dispose() {
    _medicineCtrl.dispose();
    _printedPriceCtrl.dispose();
    _chargedPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMedicine(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final repo = ref.read(medicineLookupProvider);
      final list = await repo.searchMedicines(clean);
      if (mounted) {
        setState(() {
          _searchResults = list;
          _isSearching = false;
          if (list.isNotEmpty && _selectedMedicine == null) {
            _selectedMedicine = list.first;
            if (_printedPriceCtrl.text.isEmpty &&
                list.first.referencePrice > 0) {
              _printedPriceCtrl.text = list.first.referencePrice
                  .toStringAsFixed(0);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _calculatePrice() {
    final charged = double.tryParse(_chargedPriceCtrl.text.trim());
    final printed = double.tryParse(_printedPriceCtrl.text.trim());

    if (charged == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the price charged by the pharmacy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final refPrice =
        widget.referencePrice ??
        (_selectedMedicine != null && _selectedMedicine!.referencePrice > 0
            ? _selectedMedicine!.referencePrice
            : printed);

    if (refPrice == null || refPrice <= 0) {
      setState(() {
        _analysis = _PriceAnalysis(
          status: _PriceStatus.noReference,
          headline: 'No Official Reference Price Available',
          explanation:
              'No validated DRAP retail price was found in the database. Without reliable reference data, an overcharge assessment cannot be computed.',
          referencePrice: 0,
          chargedPrice: charged,
          difference: 0,
          percentDelta: 0,
        );
      });
      return;
    }

    final diff = charged - refPrice;
    final percent = (diff / refPrice) * 100;

    if (charged > refPrice * 1.05) {
      // Overcharge indicator
      setState(() {
        _analysis = _PriceAnalysis(
          status: _PriceStatus.overcharged,
          headline: 'Potential Overcharge Indicated',
          explanation:
              'Charged amount exceeds the official maximum retail reference price (MRP) by Rs. ${diff.toStringAsFixed(1)} (+${percent.toStringAsFixed(1)}%).',
          referencePrice: refPrice,
          chargedPrice: charged,
          difference: diff,
          percentDelta: percent,
        );
      });
    } else if (charged < refPrice * 0.7) {
      // Unusually cheap indicator
      setState(() {
        _analysis = _PriceAnalysis(
          status: _PriceStatus.suspiciouslyLow,
          headline: 'Unusually Low Price Detected',
          explanation:
              'Charged amount is significantly below reference price (-${(-percent).toStringAsFixed(1)}%). Verify seller legitimacy and check for expired stock.',
          referencePrice: refPrice,
          chargedPrice: charged,
          difference: diff,
          percentDelta: percent,
        );
      });
    } else {
      // Compliant indicator
      setState(() {
        _analysis = _PriceAnalysis(
          status: _PriceStatus.compliant,
          headline: 'Compliant Price Range',
          explanation:
              'Charged price aligns with the official published Maximum Retail Price (MRP).',
          referencePrice: refPrice,
          chargedPrice: charged,
          difference: diff,
          percentDelta: percent,
        );
      });
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Price Check & MRP Audit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Medicine Card
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARGET PHARMACEUTICAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryTeal,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _medicineCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter brand or product name...',
                          prefixIcon: const Icon(
                            Icons.medication_outlined,
                            color: primaryTeal,
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: () =>
                                      _searchMedicine(_medicineCtrl.text),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _searchMedicine,
                      ),
                      if (_selectedMedicine != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryTeal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: primaryTeal,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Matched: ${_selectedMedicine!.medicineName} • Official MRP: Rs. ${_selectedMedicine!.referencePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_searchResults.length > 1) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _searchResults
                                .map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(
                                        m.medicineName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      onPressed: () {
                                        setState(() {
                                          _selectedMedicine = m;
                                          _medicineCtrl.text = m.medicineName;
                                          _printedPriceCtrl.text = m
                                              .referencePrice
                                              .toStringAsFixed(0);
                                        });
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Pricing Input Card
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRICING DATA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Printed MRP (Rs.)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _printedPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 35',
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
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount Charged (Rs.)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _chargedPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 45',
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        text: 'Check Price',
                        onPressed: _calculatePrice,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Analysis Result
                if (_analysis != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: _analysis!.statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _analysis!.statusColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _analysis!.statusIcon,
                              color: _analysis!.statusColor,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _analysis!.headline,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _analysis!.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_analysis!.status == _PriceStatus.overcharged) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '+ Rs. ${_analysis!.difference.toStringAsFixed(1)} above MRP (+${_analysis!.percentDelta.toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else if (_analysis!.status ==
                            _PriceStatus.compliant) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Compliant Price • At or below official MRP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          _analysis!.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: textPrimary,
                            height: 1.4,
                          ),
                        ),
                        if (_analysis!.referencePrice > 0) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reference MRP: Rs. ${_analysis!.referencePrice.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textMuted,
                                ),
                              ),
                              Text(
                                'Charged: Rs. ${_analysis!.chargedPrice.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Sleek 1-line Non-Definitive Legal Note
                Container(
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
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Indicative reference price based on published records — not a confirmed overcharge finding.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PriceStatus { compliant, overcharged, suspiciouslyLow, noReference }

class _PriceAnalysis {
  final _PriceStatus status;
  final String headline;
  final String explanation;
  final double referencePrice;
  final double chargedPrice;
  final double difference;
  final double percentDelta;

  _PriceAnalysis({
    required this.status,
    required this.headline,
    required this.explanation,
    required this.referencePrice,
    required this.chargedPrice,
    required this.difference,
    required this.percentDelta,
  });

  Color get statusColor {
    switch (status) {
      case _PriceStatus.compliant:
        return const Color(0xFF00897B);
      case _PriceStatus.overcharged:
        return const Color(0xFFDC2626);
      case _PriceStatus.suspiciouslyLow:
        return const Color(0xFFD97706);
      case _PriceStatus.noReference:
        return const Color(0xFF64748B);
    }
  }

  IconData get statusIcon {
    switch (status) {
      case _PriceStatus.compliant:
        return Icons.check_circle_outline_rounded;
      case _PriceStatus.overcharged:
        return Icons.warning_rounded;
      case _PriceStatus.suspiciouslyLow:
        return Icons.report_problem_outlined;
      case _PriceStatus.noReference:
        return Icons.help_outline_rounded;
    }
  }
}
