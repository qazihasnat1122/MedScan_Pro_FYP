import os

def create_files(base_path, file_map):
    for filepath, content in file_map.items():
        full_path = os.path.join(base_path, filepath)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content.strip() + '\n')

base_path = r"d:\medscan\MedScanPro\medscan_web\lib"

files = {
    "core/theme/app_colors.dart": """
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF087F8C);
  static const Color softMint = Color(0xFFE8F6F3);
  static const Color background = Color(0xFFF8FAFA);
  static const Color text = Color(0xFF172126);
  static const Color error = Colors.redAccent;
}
""",
    "core/theme/app_theme.dart": """
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        background: AppColors.background,
        error: AppColors.error,
        onBackground: AppColors.text,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        background: const Color(0xFF121212),
        error: AppColors.error,
        onBackground: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
    );
  }
}
""",
    "core/routing/app_router.dart": """
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/login/login_screen.dart';
import '../../features/manufacturer/manufacturer_shell.dart';
import '../../features/admin/admin_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => ManufacturerShell(child: child),
      routes: [
        GoRoute(
          path: '/manufacturer/dashboard',
          builder: (context, state) => const Center(child: Text('Manufacturer Dashboard')),
        ),
        GoRoute(
          path: '/manufacturer/products',
          builder: (context, state) => const Center(child: Text('Products')),
        ),
        GoRoute(
          path: '/manufacturer/batches',
          builder: (context, state) => const Center(child: Text('Batches')),
        ),
        GoRoute(
          path: '/manufacturer/packaging_references',
          builder: (context, state) => const Center(child: Text('Packaging References')),
        ),
        GoRoute(
          path: '/manufacturer/verification_data',
          builder: (context, state) => const Center(child: Text('Verification Data')),
        ),
        GoRoute(
          path: '/manufacturer/scan_activity',
          builder: (context, state) => const Center(child: Text('Scan Activity')),
        ),
        GoRoute(
          path: '/manufacturer/reports',
          builder: (context, state) => const Center(child: Text('Reports')),
        ),
        GoRoute(
          path: '/manufacturer/alerts',
          builder: (context, state) => const Center(child: Text('Alerts')),
        ),
        GoRoute(
          path: '/manufacturer/analytics',
          builder: (context, state) => const Center(child: Text('Analytics')),
        ),
        GoRoute(
          path: '/manufacturer/company_profile',
          builder: (context, state) => const Center(child: Text('Company Profile')),
        ),
        GoRoute(
          path: '/manufacturer/settings',
          builder: (context, state) => const Center(child: Text('Settings')),
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const Center(child: Text('Admin Dashboard')),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const Center(child: Text('Users')),
        ),
        GoRoute(
          path: '/admin/manufacturers',
          builder: (context, state) => const Center(child: Text('Manufacturers')),
        ),
        GoRoute(
          path: '/admin/medicines',
          builder: (context, state) => const Center(child: Text('Medicines')),
        ),
        GoRoute(
          path: '/admin/batches',
          builder: (context, state) => const Center(child: Text('Batches')),
        ),
        GoRoute(
          path: '/admin/verification_records',
          builder: (context, state) => const Center(child: Text('Verification Records')),
        ),
        GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const Center(child: Text('Reports')),
        ),
        GoRoute(
          path: '/admin/alerts',
          builder: (context, state) => const Center(child: Text('Alerts')),
        ),
        GoRoute(
          path: '/admin/analytics',
          builder: (context, state) => const Center(child: Text('Analytics')),
        ),
        GoRoute(
          path: '/admin/audit_logs',
          builder: (context, state) => const Center(child: Text('Audit Logs')),
        ),
        GoRoute(
          path: '/admin/system_management',
          builder: (context, state) => const Center(child: Text('System Management')),
        ),
      ],
    ),
  ],
);
""",
    "features/login/login_screen.dart": """
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/primary_button.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_hospital, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'MedScan Pro',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Login as Manufacturer',
                onPressed: () => context.go('/manufacturer/dashboard'),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Login as Admin',
                onPressed: () => context.go('/admin/dashboard'),
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
""",
    "features/manufacturer/manufacturer_shell.dart": """
import 'package:flutter/material.dart';
import '../../shared/widgets/sidebar.dart';
import '../../shared/widgets/topbar.dart';

class ManufacturerShell extends StatelessWidget {
  final Widget child;

  const ManufacturerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(
            role: 'Manufacturer',
            items: [
              SidebarItem(icon: Icons.dashboard, title: 'Dashboard', route: '/manufacturer/dashboard'),
              SidebarItem(icon: Icons.inventory, title: 'Products', route: '/manufacturer/products'),
              SidebarItem(icon: Icons.layers, title: 'Batches', route: '/manufacturer/batches'),
              SidebarItem(icon: Icons.qr_code, title: 'Packaging References', route: '/manufacturer/packaging_references'),
              SidebarItem(icon: Icons.verified, title: 'Verification Data', route: '/manufacturer/verification_data'),
              SidebarItem(icon: Icons.center_focus_strong, title: 'Scan Activity', route: '/manufacturer/scan_activity'),
              SidebarItem(icon: Icons.bar_chart, title: 'Reports', route: '/manufacturer/reports'),
              SidebarItem(icon: Icons.warning, title: 'Alerts', route: '/manufacturer/alerts'),
              SidebarItem(icon: Icons.analytics, title: 'Analytics', route: '/manufacturer/analytics'),
              SidebarItem(icon: Icons.business, title: 'Company Profile', route: '/manufacturer/company_profile'),
              SidebarItem(icon: Icons.settings, title: 'Settings', route: '/manufacturer/settings'),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                const TopBar(title: 'Manufacturer Portal'),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "features/admin/admin_shell.dart": """
import 'package:flutter/material.dart';
import '../../shared/widgets/sidebar.dart';
import '../../shared/widgets/topbar.dart';

class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(
            role: 'Admin',
            items: [
              SidebarItem(icon: Icons.dashboard, title: 'Dashboard', route: '/admin/dashboard'),
              SidebarItem(icon: Icons.people, title: 'Users', route: '/admin/users'),
              SidebarItem(icon: Icons.factory, title: 'Manufacturers', route: '/admin/manufacturers'),
              SidebarItem(icon: Icons.medication, title: 'Medicines', route: '/admin/medicines'),
              SidebarItem(icon: Icons.layers, title: 'Batches', route: '/admin/batches'),
              SidebarItem(icon: Icons.verified, title: 'Verification Records', route: '/admin/verification_records'),
              SidebarItem(icon: Icons.bar_chart, title: 'Reports', route: '/admin/reports'),
              SidebarItem(icon: Icons.warning, title: 'Alerts', route: '/admin/alerts'),
              SidebarItem(icon: Icons.analytics, title: 'Analytics', route: '/admin/analytics'),
              SidebarItem(icon: Icons.history, title: 'Audit Logs', route: '/admin/audit_logs'),
              SidebarItem(icon: Icons.settings_system_daydream, title: 'System Management', route: '/admin/system_management'),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                const TopBar(title: 'Admin Portal'),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "shared/widgets/sidebar.dart": """
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class SidebarItem {
  final IconData icon;
  final String title;
  final String route;
  const SidebarItem({required this.icon, required this.title, required this.route});
}

class Sidebar extends StatelessWidget {
  final String role;
  final List<SidebarItem> items;

  const Sidebar({super.key, required this.role, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.primary,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.centerLeft,
            child: Text(
              'MedScan Pro\\n$role',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(item.icon, color: Colors.white70),
                  title: Text(item.title, style: const TextStyle(color: Colors.white70)),
                  onTap: () => context.go(item.route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "shared/widgets/topbar.dart": """
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TopBar extends StatelessWidget {
  final String title;

  const TopBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
""",
    "shared/widgets/dashboard_card.dart": """
import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                Icon(icon, color: Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
""",
    "shared/widgets/data_table_wrapper.dart": """
import 'package:flutter/material.dart';

class DataTableWrapper extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const DataTableWrapper({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}
""",
    "shared/widgets/primary_button.dart": """
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}
""",
    "shared/widgets/dialog.dart": """
import 'package:flutter/material.dart';
import 'primary_button.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          text: 'Confirm',
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
""",
    "shared/widgets/loading_state.dart": """
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}
""",
    "shared/widgets/empty_state.dart": """
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
""",
    "shared/widgets/error_state.dart": """
import 'package:flutter/material.dart';
import 'primary_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
""",
    "main.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MedScanWebApp(),
    ),
  );
}

class MedScanWebApp extends StatelessWidget {
  const MedScanWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MedScan Pro Web',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
""",
    "models/.gitkeep": "",
    "services/.gitkeep": "",
    "repositories/.gitkeep": "",
    "providers/.gitkeep": "",
}

create_files(base_path, files)
print("Web files generated successfully.")
