import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color darkSlate = AppColors.textPrimary;
  static const Color borderColor = AppColors.border;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.elevated,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.factory_outlined, color: primaryTeal, size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkSlate)),
                    const SizedBox(height: 2),
                    const Text('Manufacturer Operations & Quality Assurance Console', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (title.contains('Verification Data')) ...[
              _buildVerificationDataView(),
            ] else if (title.contains('Suspicious Reports')) ...[
              _buildSuspiciousReportsView(),
            ] else if (title.contains('Alerts')) ...[
              _buildAlertsView(context),
            ] else if (title.contains('Company Profile')) ...[
              _buildCompanyProfileView(),
            ] else ...[
              _buildSettingsView(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationDataView() {
    final scans = [
      {'batch': 'PAN-500', 'city': 'Karachi', 'date': 'Today 18:22', 'status': 'AUTHENTIC', 'conf': '99.9%'},
      {'batch': 'PAN-500', 'city': 'Lahore', 'date': 'Today 17:40', 'status': 'AUTHENTIC', 'conf': '99.8%'},
      {'batch': 'AUG-625', 'city': 'Islamabad', 'date': 'Today 16:15', 'status': 'AUTHENTIC', 'conf': '99.5%'},
      {'batch': 'GLU-850', 'city': 'Peshawar', 'date': 'Today 14:02', 'status': 'AUTHENTIC', 'conf': '99.7%'},
    ];

    return _buildCardWrapper(
      title: 'Consumer Verification Scans Log for Your Products',
      child: Column(
        children: scans.map((s) {
          return ListTile(
            leading: const Icon(Icons.verified, color: primaryTeal, size: 24),
            title: Text('Batch ${s['batch']} Verified in ${s['city']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Scanned: ${s['date']} • Visual Authenticity Match: ${s['conf']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
              child: Text(s['status']!, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuspiciousReportsView() {
    return _buildCardWrapper(
      title: 'Field Quality & Tamper Incident Reports',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active counterfeit incidents reported against your registered batches in the last 30 days. Quality index is 100% compliant.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsView(BuildContext context) {
    return _buildCardWrapper(
      title: 'Broadcast Manufacturer Quality Bulletin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Issue an advisory note to pharmacies and consumers regarding packaging updates, new holographic seals, or batch notices.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 18),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Advisory Headline',
              hintText: 'e.g. New Tamper-Evident Foil Seal Introduced for 2026 Batches',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Advisory Details',
              hintText: 'Describe changes in packaging or storage recommendations...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manufacturer Bulletin Published!'), backgroundColor: primaryTeal),
              );
            },
            icon: const Icon(Icons.send),
            label: const Text('Publish Quality Bulletin'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyProfileView() {
    return _buildCardWrapper(
      title: 'Licensed Manufacturer Enterprise Profile',
      child: Column(
        children: [
          _buildProfileRow('Company Name', 'GSK Consumer Healthcare / Pharmaceuticals Pakistan'),
          _buildProfileRow('DRAP Manufacturing License', 'ML-00214-REG-PK'),
          _buildProfileRow('GMP Certification Status', 'WHO-GMP Compliant & Valid through 2028'),
          _buildProfileRow('Plant Address', 'Plot 22, Korangi Industrial Area, Karachi, Pakistan'),
          _buildProfileRow('Quality Assurance Lead', 'Dr. Farhan Siddiqui (Chief Pharmacist & Compliance Officer)'),
          _buildProfileRow('Emergency Safety Contact', 'qa-recall@gsk.com.pk • +92 21 111-475-475'),
        ],
      ),
    );
  }

  Widget _buildSettingsView(BuildContext context) {
    return _buildCardWrapper(
      title: 'Manufacturer Integration & Cloud Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileRow('Cloudinary Storage Status', 'Connected • Secure Media Cloud Enabled'),
          _buildProfileRow('ML Kit OCR Model', 'Version 3.2 Medical Vision Active'),
          _buildProfileRow('DRAP Sync Webhook', 'https://api.drap.gov.pk/v2/batch-verification (Active)'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Keys & Webhooks verified successfully!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white),
            child: const Text('Test Integration Endpoints'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkSlate)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: darkSlate, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
