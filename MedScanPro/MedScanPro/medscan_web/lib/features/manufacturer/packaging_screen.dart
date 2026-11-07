// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';

class PackagingScreen extends ConsumerWidget {
  const PackagingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProvider).value;
    final companyName = userProfile?.name ?? 'Pharmaceutical Organization';
    final packagingAsync = ref.watch(packagingReferencesProvider);

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
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
                          '$companyName • Packaging References',
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
                                'Anti-Counterfeit Hologram Standards',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'High-resolution packaging references used by AI visual verification and DRAP inspectors.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                text: 'Upload Packaging Reference',
                onPressed: () => context.go('/manufacturer/add_packaging'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Packaging Grid
          Expanded(
            child: packagingAsync.when(
              loading: () => const LoadingState(),
              error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(packagingReferencesProvider)),
              data: (refs) {
                if (refs.isEmpty) {
                  return const EmptyState(
                    message: 'No packaging security standards uploaded yet. Click "Upload Packaging Reference" to configure anti-counterfeit benchmarks.',
                    icon: Icons.qr_code_2_rounded,
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: refs.length,
                  itemBuilder: (context, i) {
                    final r = refs[i];
                    final hasImage = r.frontImageUrl != null && r.frontImageUrl!.isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: hasImage
                                ? _buildPackagingImage(r.frontImageUrl!, r.medicineId)
                                : _buildPlaceholderGraphic(r.medicineId),
                          ),
                          Container(
                            padding: const EdgeInsets.all(14),
                            color: AppColors.card,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.medication_rounded, size: 16, color: Color(0xFF087F8C)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        r.medicineId.isNotEmpty ? r.medicineId : 'Active Formulation',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Uploaded ${DateFormat.yMMMd().format(r.createdAt)}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'GS1 Verified',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderGraphic(String medId) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C242E), Color(0xFF0A3A40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xFF2DD4BF)),
            ),
            const SizedBox(height: 8),
            const Text(
              'GS1 Dual-Bar Standard',
              style: TextStyle(color: AppColors.card, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              'Security Hologram Ref',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingImage(String url, String medicineId) {
    if (url.startsWith('data:image')) {
      try {
        final b64 = url.contains(',') ? url.split(',').last : url;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderGraphic(medicineId),
        );
      } catch (_) {
        return _buildPlaceholderGraphic(medicineId);
      }
    } else if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderGraphic(medicineId),
      );
    } else {
      return _buildPlaceholderGraphic(medicineId);
    }
  }
}
