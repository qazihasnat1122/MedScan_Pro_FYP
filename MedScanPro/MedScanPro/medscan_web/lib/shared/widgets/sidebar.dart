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
              'MedScan Pro\n$role',
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
