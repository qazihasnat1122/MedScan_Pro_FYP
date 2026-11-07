// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/batch_model.dart';
import '../../shared/widgets/primary_button.dart';
import 'package:intl/intl.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({super.key});

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController(text: 'BATCH-${DateTime.now().year}-${math.Random().nextInt(9000) + 1000}');
  final _identifiersCtrl = TextEditingController();
  String? _selectedMedicineId;
  DateTime _mfgDate = DateTime.now();
  DateTime _expDate = DateTime.now().add(const Duration(days: 730)); // 2 years standard shelf life
  bool _isLoading = false;

  @override
  void dispose() {
    _batchCtrl.dispose();
    _identifiersCtrl.dispose();
    super.dispose();
  }

  void _generateSampleIdentifiers(int count) {
    final batchNum = _batchCtrl.text.trim().replaceAll(' ', '-');
    final list = <String>[];
    for (int i = 1; i <= count; i++) {
      final code = '$batchNum-U${i.toString().padLeft(4, '0')}-${math.Random().nextInt(900) + 100}';
      list.add(code);
    }
    setState(() {
      _identifiersCtrl.text = list.join(', ');
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate() || _selectedMedicineId == null) {
      if (_selectedMedicineId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a formulation from your company vault')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated as manufacturer');

      final repo = ref.read(manufacturerRepositoryProvider);
      final rawIdentifiers = _identifiersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final batch = BatchModel(
        id: '',
        medicineId: _selectedMedicineId!,
        medicineName: _selectedMedicineId!,
        manufacturerId: user.uid,
        batchNumber: _batchCtrl.text.trim(),
        manufacturingDate: _mfgDate.toIso8601String(),
        expiryDate: _expDate.toIso8601String(),
        status: 'active',
        totalUnitsReleased: rawIdentifiers.isNotEmpty ? rawIdentifiers.length : 1,
        reportedScans: 0,
        hasActiveAlert: false,
        createdAt: DateTime.now(),
      );

      await repo.addBatch(batch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch "${batch.batchNumber}" successfully serialized with ${batch.totalUnitsReleased} units.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/manufacturer/batches');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error serializing batch: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesProvider);

    return Scaffold(
      backgroundColor: AppColors.elevated,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text('Serialize Production Batch', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/manufacturer/batches'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Company Isolation Notice
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GS1 Dual-Bar Serialization & Secure DRAP Registry',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Batch numbers and serialized packaging matrix codes are encrypted in your private company vault. Consumers scanning these batches in stores will receive instant authenticity verification.',
                                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Select Linked Medicine Formulation',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        medicinesAsync.when(
                          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                          error: (e, _) => Text('Error loading formulations: $e'),
                          data: (medicines) {
                            if (medicines.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Your company has no registered medicines yet. Please register a medicine first.',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/manufacturer/add_product'),
                                      child: const Text('Add Medicine'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Formulation in Vault *',
                                prefixIcon: Icon(Icons.medication_liquid_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: medicines.map((m) {
                                return DropdownMenuItem(
                                  value: m.medicineName,
                                  child: Text('${m.medicineName} (${m.strength}) • ${m.dosageForm}'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedMedicineId = v),
                              validator: (v) => v == null ? 'Please select a formulation' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          '2. Batch Identification & Dates',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _batchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Official Batch Lot Number *',
                            hintText: 'e.g. BATCH-2026-9021',
                            prefixIcon: Icon(Icons.tag_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Batch number is required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _mfgDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null) setState(() => _mfgDate = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Manufacturing Date *',
                                    prefixIcon: Icon(Icons.event_available_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(DateFormat.yMMMd().format(_mfgDate), style: const TextStyle(fontSize: 14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _expDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2038),
                                  );
                                  if (d != null) setState(() => _expDate = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry Date *',
                                    prefixIcon: Icon(Icons.event_busy_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    DateFormat.yMMMd().format(_expDate),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          '3. Serialized Unit Identifiers (GS1 DataMatrix Codes)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Quick Auto-Generate:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            ActionChip(
                              label: const Text('10 Units', style: TextStyle(fontSize: 11)),
                              onPressed: () => _generateSampleIdentifiers(10),
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              label: const Text('25 Units', style: TextStyle(fontSize: 11)),
                              onPressed: () => _generateSampleIdentifiers(25),
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              label: const Text('50 Units', style: TextStyle(fontSize: 11)),
                              onPressed: () => _generateSampleIdentifiers(50),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _identifiersCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Serialized Unit Matrix Codes (Comma Separated)',
                            hintText: 'e.g. BATCH-2026-U0001, BATCH-2026-U0002...',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 32),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : PrimaryButton(
                                text: 'Serialize & Release Batch to Vault',
                                onPressed: _save,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
