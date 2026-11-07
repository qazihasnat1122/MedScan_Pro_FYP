// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/packaging_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddPackagingScreen extends ConsumerStatefulWidget {
  const AddPackagingScreen({super.key});

  @override
  ConsumerState<AddPackagingScreen> createState() => _AddPackagingScreenState();
}

class _AddPackagingScreenState extends ConsumerState<AddPackagingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imageUrlCtrl = TextEditingController(text: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80');
  final _notesCtrl = TextEditingController(text: 'Holographic 3D security foil on cap, microtext on carton flap, and high-contrast 2D DataMatrix on side panel.');
  String? _selectedMedicineId;
  bool _hasHologram = true;
  bool _hasUvInk = true;
  bool _hasTamperSeal = true;
  bool _isLoading = false;

  Future<void> _pickLocalImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        final b64 = base64Encode(bytes);
        final ext = file.extension?.toLowerCase() ?? 'jpeg';
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        setState(() {
          _imageUrlCtrl.text = 'data:$mime;base64,$b64';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected image: ${file.name} (${(bytes.length / 1024).toStringAsFixed(1)} KB)'),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
      final packRef = PackagingModel(
        referenceId: '',
        medicineId: _selectedMedicineId!,
        manufacturerId: user.uid,
        frontImageUrl: _imageUrlCtrl.text.trim(),
        otherImageUrls: [
          if (_hasHologram) 'FEATURE:HOLOGRAPHIC_STRIP',
          if (_hasUvInk) 'FEATURE:UV_FLUORESCENT_INK',
          if (_hasTamperSeal) 'FEATURE:TAMPER_EVIDENT_SEAL',
          _notesCtrl.text.trim(),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.addPackagingReference(packRef);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Packaging security reference successfully registered to vault.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/manufacturer/packaging_references');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving packaging reference: $e'), backgroundColor: Colors.red),
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
        title: const Text('Register Packaging Security Reference', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/manufacturer/packaging_references'),
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
                  // Notice
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
                                'Packaging Visual AI & Anti-Counterfeit Baseline',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Packaging references serve as the baseline for DRAP field inspectors and AI vision models to detect fake blister packs, inconsistent logos, or counterfeit packaging.',
                                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Container
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
                                child: const Text(
                                  'Your company has no registered medicines yet. Please register a medicine first.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
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

                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              '2. Front Packaging Reference Photo / Hologram',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickLocalImage,
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Choose Image from PC'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF087F8C),
                                side: const BorderSide(color: Color(0xFF087F8C)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _imageUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Reference Image URL or Local Base64 Data *',
                            hintText: 'https://... or click Choose Image from PC above',
                            prefixIcon: Icon(Icons.image_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Image URL or file is required' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 110,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _imageUrlCtrl.text.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(_imageUrlCtrl.text.split(',').last),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                        )
                                      : Image.network(
                                          _imageUrlCtrl.text.trim(),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Packaging Security Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                      SizedBox(height: 4),
                                      Text('This baseline is used by DRAP inspectors and AI models to verify authentic holograms.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        const Text(
                          '3. Security Features Enabled on Carton / Blister',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: _hasHologram,
                          onChanged: (v) => setState(() => _hasHologram = v ?? true),
                          title: const Text('Holographic Security Strip / Rainbow Foil', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: const Text('3D light diffractive strip embedded in carton flap', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _hasUvInk,
                          onChanged: (v) => setState(() => _hasUvInk = v ?? true),
                          title: const Text('UV Invisible Fluorescent Security Ink', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Glows under 365nm ultraviolet lamp inspection', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _hasTamperSeal,
                          onChanged: (v) => setState(() => _hasTamperSeal = v ?? true),
                          title: const Text('Tamper-Evident Cap or Perforated Seal', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Irreversible visual breakage upon initial opening', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          '4. Quality & Microprint Inspection Notes',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Describe microtext position, color scheme codes, or box texture...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : PrimaryButton(
                                text: 'Save Packaging Standard to Vault',
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
