import os

base_path = r'd:\medscan\MedScanPro\medscan_mobile\lib'

files = {
    'features/home/home_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/app_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const CustomAppBar(title: 'MedScan Pro', showLogout: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hello, \${user?.email?.split('@')[0] ?? "User"}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify your medicine instantly.',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 48),
              
              // PRIMARY ACTION
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF087F8C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                ),
                onPressed: () => context.push('/scan/capture'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 32),
                    SizedBox(width: 16),
                    Text('Scan Medicine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // SECONDARY ACTIONS GRID
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _ActionCard(
                    icon: Icons.history,
                    title: 'Scan History',
                    color: Colors.blue.shade50,
                    iconColor: Colors.blue.shade700,
                    onTap: () => context.push('/safety/history'),
                  ),
                  _ActionCard(
                    icon: Icons.medical_services,
                    title: 'My Medicines',
                    color: Colors.purple.shade50,
                    iconColor: Colors.purple.shade700,
                    onTap: () => context.push('/medicines'),
                  ),
                  _ActionCard(
                    icon: Icons.report_problem,
                    title: 'Report Issue',
                    color: Colors.orange.shade50,
                    iconColor: Colors.orange.shade700,
                    onTap: () => context.push('/safety/report'),
                  ),
                  _ActionCard(
                    icon: Icons.emergency,
                    title: 'Emergency',
                    color: Colors.red.shade50,
                    iconColor: Colors.red.shade700,
                    onTap: () => context.push('/emergency/profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
'''
}

for filepath, content in files.items():
    full_path = os.path.join(base_path, filepath)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + '\\n')

print("UX Polish generated")
