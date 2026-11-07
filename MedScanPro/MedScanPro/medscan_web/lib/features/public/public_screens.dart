import 'package:flutter/material.dart';
import 'public_app_bar.dart';
import 'public_footer.dart';

class SafetyAlertsScreen extends StatelessWidget {
  const SafetyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF071214),
      appBar: buildPublicAppBar(context, 'Safety Alerts'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Safety Alerts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAlertCard(
                          'Batch Recall: Paracetamol 500mg',
                          'High Priority',
                          'A batch of Paracetamol 500mg (Batch #XYZ123) has been recalled due to mislabeling. Please return to your pharmacy.',
                          '2024-05-12',
                          Colors.redAccent,
                          isMobile,
                        ),
                        _buildAlertCard(
                          'Counterfeit Warning: Amoxil',
                          'Warning',
                          'Reports of counterfeit Amoxil circulating in the southern region. Verify all packaging using the MedScan app.',
                          '2024-04-28',
                          Colors.orange,
                          isMobile,
                        ),
                        _buildAlertCard(
                          'System Update',
                          'Info',
                          'MedScan Pro verification API has been updated to support the new v2 DataMatrix standard.',
                          '2024-04-15',
                          Colors.blueAccent,
                          isMobile,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(String title, String type, String desc, String date, Color color, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A191C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(date, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 17 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF071214),
      appBar: buildPublicAppBar(context, 'How It Works'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
                child: Column(
                  children: [
                    Text(
                      '3-Step Verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 28 : 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How to verify your medicine using MedScan Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 15 : 18),
                    ),
                    SizedBox(height: isMobile ? 32 : 60),
                    _buildStep(
                      '1',
                      'Locate the 2D DataMatrix',
                      'Look for the square barcode printed on the medicine box. It is usually located near the manufacturing and expiry date.',
                      Icons.qr_code_scanner,
                      isMobile,
                    ),
                    _buildStep(
                      '2',
                      'Scan with MedScan Mobile',
                      'Open the MedScan Mobile App and point your camera at the DataMatrix code. The app will instantly read the serialized data.',
                      Icons.smartphone,
                      isMobile,
                    ),
                    _buildStep(
                      '3',
                      'Verify Authenticity',
                      'The app cross-checks the scanned code against the DRAP national database. You will see a green shield for authentic medicines.',
                      Icons.verified_user,
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String desc, IconData icon, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 28 : 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 44 : 60,
            height: isMobile ? 44 : 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2DD4BF), width: 2),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: const Color(0xFF2DD4BF),
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 14 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: const Color(0xFF94A3B8), size: isMobile ? 22 : 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(desc, style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 14 : 16, height: 1.5)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF071214),
      appBar: buildPublicAppBar(context, 'About the Platform'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mission Statement', style: TextStyle(color: Colors.white, fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Our mission is to eradicate counterfeit medication from the supply chain by empowering patients, pharmacies, and manufacturers with state-of-the-art track and trace technology.', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 15 : 18, height: 1.6)),
                    SizedBox(height: isMobile ? 28 : 40),
                    Text('Surveillance Model', style: TextStyle(color: Colors.white, fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('The platform utilizes a centralized registry maintained by DRAP. Manufacturers upload serialization data at the time of packaging. This data is then accessible securely to verified pharmacies and the general public via the MedScan Pro app.', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 15 : 18, height: 1.6)),
                    SizedBox(height: isMobile ? 28 : 40),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A191C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF16373A)),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.security, color: Color(0xFF2DD4BF), size: 40),
                                SizedBox(height: 14),
                                Text('Secure Infrastructure', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('All data is encrypted in transit and at rest, ensuring that batch data and patient scan activities remain completely private and secure.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5)),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.security, color: Color(0xFF2DD4BF), size: 64),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Secure Infrastructure', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Text('All data is encrypted in transit and at rest, ensuring that batch data and patient scan activities remain completely private and secure.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, height: 1.5)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                    )
                  ],
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }
}

class BrandAssetsScreen extends StatelessWidget {
  const BrandAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF071214),
      appBar: buildPublicAppBar(context, 'Brand Assets & Media'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Logos & Banners', style: TextStyle(color: Colors.white, fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Download official MedScan Pro logos for press and media use.', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 14 : 16)),
                    SizedBox(height: isMobile ? 24 : 40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF040A0B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF16373A)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D2023),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF16373A)),
                              ),
                              child: const Icon(Icons.shield_outlined, color: Color(0xFF2DD4BF), size: 32),
                            ),
                            const SizedBox(width: 14),
                            Text('MedScan ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 22 : 28)),
                            Text('Pro', style: TextStyle(color: const Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: isMobile ? 22 : 28)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download),
                        label: const Text('Download Vector Logo Kit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2DD4BF),
                          foregroundColor: const Color(0xFF042F2E),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }
}
