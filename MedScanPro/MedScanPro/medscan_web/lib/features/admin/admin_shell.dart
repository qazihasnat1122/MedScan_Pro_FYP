// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 960;
    final currentPath = GoRouterState.of(context).uri.toString();
    final userProfile = ref.watch(currentUserProvider).value;
    final adminName = userProfile?.name ?? 'System Administrator';
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
              // Brand & DRAP Badge
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087F8C), Color(0xFF16B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.card, size: 20),
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
                              color: const Color(0xFF087F8C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DRAP REGULATORY CONSOLE',
                              style: TextStyle(color: Color(0xFF087F8C), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      adminName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Just Sign Out
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
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, ref, currentPath, adminName)),
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
              child: _buildSidebar(context, ref, currentPath, adminName),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }


  Widget _buildSidebar(BuildContext context, WidgetRef ref, String currentPath, String adminName) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              // Regulatory Authority Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF087F8C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF087F8C).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 16, color: Color(0xFF16B8A6)),
                        SizedBox(width: 6),
                        Text(
                          'DRAP OVERSIGHT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF087F8C)),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Drug Regulatory Authority of Pakistan',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF087F8C)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Federal Drug Inspectorate • Directorate of Market Surveillance',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF16B8A6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader('OVERVIEW'),
              _buildNavItem(context, Icons.dashboard_outlined, 'Dashboard', '/admin/dashboard', currentPath),

              const SizedBox(height: 16),
              _buildSectionHeader('REGISTRY'),
              _buildNavItem(context, Icons.medication_liquid_outlined, 'Medicines', '/admin/medicines', currentPath),
              _buildNavItem(context, Icons.business_outlined, 'Manufacturers', '/admin/manufacturers', currentPath),
              _buildNavItem(context, Icons.file_download_done_outlined, 'Approvals Queue', '/admin/approvals', currentPath),

              const SizedBox(height: 16),
              _buildSectionHeader('SAFETY'),
              _buildNavItem(context, Icons.map_outlined, 'National Threat Map', '/admin/threat-map', currentPath),
              _buildNavItem(context, Icons.notifications_active_outlined, 'Safety Alerts', '/admin/alerts', currentPath),
              _buildNavItem(context, Icons.report_problem_outlined, 'Suspicious Reports', '/admin/reports', currentPath),
              _buildNavItem(context, Icons.local_activity_outlined, 'Verification Activity', '/admin/verification', currentPath),

              const SizedBox(height: 16),
              _buildSectionHeader('SYSTEM'),
              _buildNavItem(context, Icons.people_outline, 'Authorized Users', '/admin/users', currentPath),
              _buildNavItem(context, Icons.history_outlined, 'Audit Logs', '/admin/audit', currentPath),
              _buildNavItem(context, Icons.settings_outlined, 'Registry Settings', '/admin/settings', currentPath),
            ],
          ),
        ),
        
        // Officer Session Bar (Bottom)
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
                  children: [
                    const Text('Federal Inspector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Text('regulatory.officer@drap.gov.pk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route, String currentPath) {
    final bool isSelected = currentPath.startsWith(route);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF087F8C).withOpacity(0.1) : Colors.transparent,
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
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.pop(context);
          context.go(route);
        },
      ),
    );
  }
}
