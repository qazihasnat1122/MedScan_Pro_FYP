// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/medicine_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController(text: '500mg');
  final _packSizeCtrl = TextEditingController(text: '20 Tablets (2 x 10 Blister Pack)');
  final _regCtrl = TextEditingController(text: 'DRAP-001244');
  final _priceCtrl = TextEditingController(text: '120.00');
  final _indicationsCtrl = TextEditingController(text: 'Relief of mild-to-moderate pain, headache, and fever.');
  final _storageCtrl = TextEditingController(text: 'Store below 25°C in a dry place. Protect from direct sunlight.');
  final _precautionsCtrl = TextEditingController(text: 'Do not exceed recommended dosage. Keep out of reach of children.');
  final _descCtrl = TextEditingController();

  String _dosageForm = 'Film-Coated Tablet';
  bool _isLoading = false;

  final List<String> _dosageForms = [
    'Film-Coated Tablet',
    'Scored Round Tablet',
    'Effervescent Tablet',
    'Chewable Tablet',
    'Hard Gelatin Capsule',
    'Softgel Capsule',
    'Oral Suspension / Syrup',
    'Injection / Ampoule',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(currentUserProvider).value;
      if (userProfile != null && userProfile.name.isNotEmpty) {
        _companyCtrl.text = userProfile.name;
      } else {
        _companyCtrl.text = 'GSK Pakistan Ltd';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _companyCtrl.dispose();
    _genericCtrl.dispose();
    _strengthCtrl.dispose();
    _packSizeCtrl.dispose();
    _regCtrl.dispose();
    _priceCtrl.dispose();
    _indicationsCtrl.dispose();
    _storageCtrl.dispose();
    _precautionsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated as manufacturer');

      final repo = ref.read(manufacturerRepositoryProvider);
      final medicine = MedicineModel(
        id: '',
        manufacturerId: user.uid,
        manufacturerName: _companyCtrl.text.trim().isEmpty ? 'Pharmaceutical Manufacturer' : _companyCtrl.text.trim(),
        medicineName: _nameCtrl.text.trim(),
        genericName: _genericCtrl.text.trim(),
        strength: _strengthCtrl.text.trim(),
        dosageForm: _dosageForm,
        referenceNumber: _regCtrl.text.trim(),
        registrationStatus: 'Approved',
        dataSourceType: 'manufacturer_verified',
        manufacturerVerified: true,
        verificationLevel: 'manufacturer',
        approvedStatus: 'approved',
        description: _descCtrl.text.trim().isEmpty ? '${_nameCtrl.text.trim()} manufactured by ${_companyCtrl.text.trim()}' : _descCtrl.text.trim(),
        indications: [_indicationsCtrl.text.trim()],
        storageConditions: _storageCtrl.text.trim(),
        packagingSidesAvailable: [_packSizeCtrl.text.trim()],
        activeAlertsCount: 0,
        updatedAt: DateTime.now(),
      );

      await repo.addMedicine(medicine);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered "${medicine.medicineName}" to company vault.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/manufacturer/products');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.elevated,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text('Register New Medicine & Tablet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/manufacturer/products'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Strict Isolation & Privacy Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Company Privacy & Strict Multi-Tenant Isolation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 14.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'This product is stored in your private manufacturer vault. Competitors and other pharmaceutical companies cannot view, edit, or access your manufacturing records. Verified specifications will be surfaced publicly to consumers for authentic batch verification.',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card 1: Company & Brand Identity
                  _buildSectionCard(
                    title: '1. Brand & Manufacturing Identity',
                    icon: Icons.business_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _companyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Manufacturing Company Name *',
                                hintText: 'e.g. GlaxoSmithKline Pakistan Ltd',
                                prefixIcon: Icon(Icons.domain_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _brandCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Brand Umbrella Name *',
                                hintText: 'e.g. Panadol, Augmentin, Brufen',
                                prefixIcon: Icon(Icons.branding_watermark_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Brand name is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Complete Product & Tablet Name *',
                          hintText: 'e.g. Panadol Extra 500mg/65mg Coated Tablets',
                          prefixIcon: Icon(Icons.medication_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card 2: Pharmaceutical Formula & Dosage
                  _buildSectionCard(
                    title: '2. Pharmaceutical Formula & Dosage Form',
                    icon: Icons.science_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _genericCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Active Ingredients / Generic Salt *',
                                hintText: 'e.g. Paracetamol + Caffeine',
                                prefixIcon: Icon(Icons.biotech_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Active ingredients required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _strengthCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Strength & Potency *',
                                hintText: 'e.g. 500mg, 625mg',
                                prefixIcon: Icon(Icons.speed_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Strength is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dosageForm,
                              decoration: const InputDecoration(
                                labelText: 'Dosage Form *',
                                prefixIcon: Icon(Icons.pie_chart_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: _dosageForms.map((form) => DropdownMenuItem(value: form, child: Text(form))).toList(),
                              onChanged: (v) => setState(() => _dosageForm = v ?? _dosageForm),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _packSizeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Packaging & Pack Size',
                                hintText: 'e.g. 20 Tablets (2 x 10 Blister)',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card 3: Regulatory & Commercial Details
                  _buildSectionCard(
                    title: '3. DRAP Regulatory Compliance & Pricing',
                    icon: Icons.gavel_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _regCtrl,
                              decoration: const InputDecoration(
                                labelText: 'DRAP Registration Number *',
                                hintText: 'e.g. DRAP-001244',
                                prefixIcon: Icon(Icons.verified_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'DRAP Reg number is required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Retail Price (PKR) *',
                                hintText: '120.00',
                                prefixIcon: Icon(Icons.payments_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Price is required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card 4: Consumer Specification Sheet
                  _buildSectionCard(
                    title: '4. Consumer Specification & Safety Sheet',
                    icon: Icons.assignment_outlined,
                    children: [
                      TextFormField(
                        controller: _indicationsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Therapeutic Indications & Medical Use',
                          hintText: 'What symptoms or diseases this tablet is prescribed for',
                          prefixIcon: Icon(Icons.healing_rounded),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _storageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Storage Specifications',
                          hintText: 'Temperature, moisture, and light instructions',
                          prefixIcon: Icon(Icons.thermostat_rounded),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _precautionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Safety Warnings & Contraindications',
                          hintText: 'Overdose warnings, contraindications, pregnancy warnings',
                          prefixIcon: Icon(Icons.warning_amber_rounded),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'General Product Overview (Optional)',
                          hintText: 'Short summary for clinical and patient view',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : PrimaryButton(
                          text: 'Register Product to Company Vault',
                          onPressed: _save,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF087F8C), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }
}

