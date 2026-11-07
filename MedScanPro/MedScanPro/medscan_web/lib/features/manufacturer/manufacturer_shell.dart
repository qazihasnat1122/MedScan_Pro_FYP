// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';

class ManufacturerShell extends ConsumerWidget {
  final Widget child;
  const ManufacturerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 960;
    final currentPath = GoRouterState.of(context).uri.toString();
    final userProfile = ref.watch(currentUserProvider).value;
    final companyName = userProfile?.name ?? 'Pharmaceutical Organization';
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.elevated,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: const Border(bottom: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
              // Brand
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'MedScan Pro',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        if (isDesktop)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF087F8C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MANUFACTURER VAULT',
                              style: TextStyle(color: Color(0xFF087F8C), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              if (isDesktop) const SizedBox(width: 20),

              // Sign Out
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                tooltip: 'Sign Out',
                onPressed: () {
                  ref.read(authRepositoryProvider).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, ref, currentPath, companyName)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: _buildSidebar(context, ref, currentPath, companyName),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }



  Widget _buildSidebar(BuildContext context, WidgetRef ref, String currentPath, String companyName) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              // Company Identity Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'LICENSE ID: MFG-GSK',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('Verified Partner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader('MAIN'),
              _buildNavItem(
                context: context,
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                route: '/manufacturer/dashboard',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.medication_liquid_outlined,
                label: 'Medicines',
                route: '/manufacturer/products',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.layers_outlined,
                label: 'Batches',
                route: '/manufacturer/batches',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.image_outlined,
                label: 'Packaging References',
                route: '/manufacturer/packaging',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.check_box_outlined,
                label: 'Verification Data',
                route: '/manufacturer/verification',
                currentPath: currentPath,
              ),

              const SizedBox(height: 16),
              _buildSectionHeader('MONITORING'),
              _buildNavItem(
                context: context,
                icon: Icons.local_activity_outlined,
                label: 'Scan Activity',
                route: '/manufacturer/scans',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.report_problem_outlined,
                label: 'Suspicious Reports',
                route: '/manufacturer/reports',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.notifications_active_outlined,
                label: 'Safety Alerts',
                route: '/manufacturer/alerts',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.bar_chart_outlined,
                label: 'Analytics',
                route: '/manufacturer/analytics',
                currentPath: currentPath,
              ),

              const SizedBox(height: 16),
              _buildSectionHeader('COMPANY'),
              _buildNavItem(
                context: context,
                icon: Icons.business_outlined,
                label: 'Company Profile',
                route: '/manufacturer/profile',
                currentPath: currentPath,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.settings_outlined,
                label: 'Settings',
                route: '/manufacturer/settings',
                currentPath: currentPath,
              ),
            ],
          ),
        ),
        
        // User Profile & Logout Bar (Bottom)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('GSK Regulatory Lead', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('corporate@gsk.pk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                tooltip: 'Logout',
                onPressed: () {
                  ref.read(authRepositoryProvider).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required String currentPath,
  }) {
    final bool isSelected = currentPath.startsWith(route);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF087F8C).withOpacity(0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF087F8C) : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF087F8C) : AppColors.textPrimary,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF087F8C),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
          context.go(route);
        },
      ),
    );
  }
}
