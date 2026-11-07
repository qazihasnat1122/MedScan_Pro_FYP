import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget _buildNavTextButton(BuildContext context, String title, String route, {bool isActive = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? const Color(0xFF2DD4BF) : const Color(0xFFCBD5E1),
        backgroundColor: isActive ? const Color(0xFF2DD4BF).withValues(alpha: 0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isActive ? const BorderSide(color: Colors.white70, width: 1.5) : BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ),
  );
}

void showPublicMobileNav(BuildContext context, String currentTitle) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF071214),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      Widget navItem(String title, String route, IconData icon, {bool isAccent = false}) {
        final isActive = currentTitle == title;
        return ListTile(
          leading: Icon(icon, color: isActive || isAccent ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8)),
          title: Text(
            title,
            style: TextStyle(
              color: isActive || isAccent ? const Color(0xFF2DD4BF) : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          onTap: () {
            Navigator.pop(ctx);
            context.go(route);
          },
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              navItem('Home', '/', Icons.home_rounded),
              navItem('Medicine Directory', '/medicines', Icons.medication_rounded),
              navItem('Safety Alerts', '/alerts', Icons.warning_amber_rounded),
              navItem('How It Works', '/how-it-works', Icons.checklist_rounded),
              navItem('About Platform', '/about', Icons.info_outline_rounded),
              const Divider(color: Color(0xFF16373A)),
              navItem('Portal Access (Login)', '/login', Icons.login_rounded, isAccent: true),
            ],
          ),
        ),
      );
    },
  );
}

PreferredSizeWidget buildPublicAppBar(BuildContext context, String title, {Widget? leading}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth <= 1100;
  
  return AppBar(
    backgroundColor: const Color(0xFF071214),
    elevation: 0,
    leading: leading,
    toolbarHeight: isMobile ? 64 : 80,
    title: Row(
      children: [
        Container(
          width: isMobile ? 36 : 44,
          height: isMobile ? 36 : 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('MedScan ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Pro', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Text(
                title, 
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      if (!isMobile) ...[
        _buildNavTextButton(context, 'Home', '/'),
        _buildNavTextButton(context, 'Medicines', '/medicines', isActive: title == 'Medicine Directory' || title == 'Public Medicine Reference'),
        _buildNavTextButton(context, 'Safety Alerts', '/alerts', isActive: title == 'Safety Alerts'),
        _buildNavTextButton(context, 'How It Works', '/how-it-works', isActive: title == 'How It Works'),
        _buildNavTextButton(context, 'About', '/about', isActive: title == 'About the Platform' || title == 'Brand Assets & Media'),
        ElevatedButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Portal Access'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F292E),
            foregroundColor: const Color(0xFF2DD4BF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 24),
      ] else ...[
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => showPublicMobileNav(context, title),
        ),
      ]
    ],
  );
}
