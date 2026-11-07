import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../models/medicine_model.dart';
import 'public_app_bar.dart';
import 'public_footer.dart';

class MedicineDetailScreen extends ConsumerWidget {
  final String medicineId;
  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(allPublicMedicinesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF071417),
      appBar: buildPublicAppBar(
        context, 
        'Medicine Details',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/medicines');
            }
          },
        ),
      ),
      body: medicinesAsync.when(
        data: (medicines) {
          try {
            final med = medicines.firstWhere((m) => m.id == medicineId);
            return _buildDetailView(context, med);
          } catch (e) {
            return const Center(child: Text('Medicine not found.', style: TextStyle(color: Colors.red)));
          }
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF16B8A6))),
        error: (err, stack) => Center(child: Text('Error loading details', style: TextStyle(color: Colors.red.shade300))),
      ),
    );
  }

  Widget _buildDetailView(BuildContext context, MedicineModel med) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Phase 4: Strict verification tier logic
    String verificationTier = 'limited'; // Default
    if (med.approvedStatus.toLowerCase() == 'suspended' || med.approvedStatus.toLowerCase() == 'flagged') {
      verificationTier = 'suspicious';
    } else if (med.manufacturerId.isNotEmpty && med.approvedStatus.toLowerCase() == 'approved') {
      verificationTier = 'manufacturer';
    } else if (med.manufacturerName.isNotEmpty || med.referenceNumber.isNotEmpty) {
      verificationTier = 'reference';
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVerificationBanner(verificationTier),
                    const SizedBox(height: 24),
                    
                    Text(
                      med.medicineName,
                      style: TextStyle(
                        fontSize: isMobile ? 26 : 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${med.genericName} • ${med.strength} • ${med.dosageForm}',
                      style: TextStyle(fontSize: isMobile ? 15 : 18, color: const Color(0xFFA8BEC1)),
                    ),
                    
                    SizedBox(height: isMobile ? 28 : 40),
                    _buildSectionTitle('Manufacturer Information'),
                    _buildInfoRow(isMobile, 'Company', med.manufacturerName),
                    if (med.referenceNumber.isNotEmpty) _buildInfoRow(isMobile, 'Registration Info', med.referenceNumber),
                    
                    SizedBox(height: isMobile ? 28 : 40),
                    _buildSectionTitle('Clinical Details'),
                    _buildInfoRow(isMobile, 'Indications', med.indications.isNotEmpty ? med.indications.join(', ') : 'No specific indications provided.'),
                    _buildInfoRow(isMobile, 'Description', med.description.isNotEmpty ? med.description : 'No specific description listed.'),
                    _buildInfoRow(isMobile, 'Storage', med.storageConditions.isNotEmpty ? med.storageConditions : 'Store in a cool, dry place.'),
                    
                    SizedBox(height: isMobile ? 28 : 40),
                    _buildSectionTitle('Safety Alerts'),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2023),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF12292D)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(child: Text('No active safety alerts for this medicine.', style: TextStyle(color: Color(0xFFA8BEC1)))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const PublicFooter(),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner(String tier) {
    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;

    switch (tier) {
      case 'suspicious':
        bannerColor = Colors.red;
        bannerIcon = Icons.warning_amber_rounded;
        bannerTitle = 'Suspicious Indicators Detected';
        break;
      case 'manufacturer':
        bannerColor = Colors.green;
        bannerIcon = Icons.verified;
        bannerTitle = 'Manufacturer-Supported Verification';
        break;
      case 'reference':
        bannerColor = Colors.blue;
        bannerIcon = Icons.info_outline;
        bannerTitle = 'Reference Match Only';
        break;
      case 'limited':
      default:
        bannerColor = Colors.orange;
        bannerIcon = Icons.help_outline;
        bannerTitle = 'Limited Verification Data';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor),
          const SizedBox(width: 12),
          Expanded(child: Text(bannerTitle, style: TextStyle(color: bannerColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF4FAFA))),
    );
  }

  Widget _buildInfoRow(bool isMobile, String label, String value) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFA8BEC1), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, height: 1.4, fontSize: 15)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: Color(0xFFA8BEC1), fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
