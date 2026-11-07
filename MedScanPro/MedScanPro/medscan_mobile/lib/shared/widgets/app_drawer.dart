import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/safety_providers.dart';

/// Clinical Navigation Drawer for MedScan Pro.
///
/// Organized into distinct, structured sections:
/// - MEDICINES: My Medicines, My Prescriptions, Similar Medicines, Check Price, Dose History, Scan History
/// - SAFETY: Safety Alerts, Find Pharmacy
/// - HEALTH & EMERGENCY: Emergency Profile, Emergency QR Code, SOS
/// - ACCOUNT: Profile, Settings, Privacy
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final userProfileAsync = ref.watch(currentUserProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userProfile = userProfileAsync.value;
    final alerts = alertsAsync.value ?? [];

    final String displayName = () {
      if (userProfile != null && userProfile.name.trim().isNotEmpty) {
        return userProfile.name.trim();
      }
      if (authUser?.displayName != null &&
          authUser!.displayName!.trim().isNotEmpty) {
        return authUser.displayName!.trim();
      }
      if (authUser?.email != null && authUser!.email!.contains('@')) {
        final prefix = authUser.email!.split('@').first.trim();
        if (prefix.isNotEmpty) {
          return '${prefix[0].toUpperCase()}${prefix.substring(1)}';
        }
      }
      return 'Patient User';
    }();

    final String email = authUser?.email ?? 'patient@medscan.pro';

    final surfaceColor = Theme.of(context).cardColor;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final sectionTitleColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF475569);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Drawer(
      backgroundColor: surfaceColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drawer Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Menu ───────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // ── MEDICINES SECTION ──
                  _buildSectionHeader('MEDICINES', sectionTitleColor),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.medication_outlined,
                    title: 'My Medicines',
                    subtitle: 'Medication schedule & reminders',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/medicines');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    title: 'My Prescriptions',
                    subtitle: 'Upload and review digital prescriptions',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/prescriptions/upload');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.smart_toy_outlined,
                    title: 'MedBot',
                    accentColor: const Color(0xFF0284C7),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/chat');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Similar Medicines',
                    subtitle: 'Same-salt generic alternatives',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/same-salt');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.payments_outlined,
                    title: 'Check Price',
                    subtitle: 'Official DRAP maximum retail prices',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/price-check');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.history_rounded,
                    title: 'Dose History',
                    subtitle: 'Past doses & adherence records',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/records');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.history_rounded,
                    title: 'Scan History',
                    subtitle: 'Packaging audit logs & past scans',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/safety/history');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),

                  const Divider(height: 24, thickness: 1),

                  // ── SAFETY SECTION ──
                  _buildSectionHeader('SAFETY', sectionTitleColor),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.warning_amber_rounded,
                    title: 'Safety Alerts',
                    subtitle: 'Recalls and public health advisories',
                    badgeCount: alerts.isNotEmpty ? alerts.length : null,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/safety/alerts');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.local_pharmacy_outlined,
                    title: 'Find Pharmacy',
                    subtitle: 'Locate nearby licensed pharmacies',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/pharmacies');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),

                  const Divider(height: 24, thickness: 1),

                  // ── HEALTH & EMERGENCY SECTION ──
                  _buildSectionHeader('HEALTH & EMERGENCY', sectionTitleColor),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.contact_emergency_outlined,
                    title: 'Emergency Profile',
                    subtitle: 'Conditions, blood group & contacts',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/emergency/profile');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.qr_code_rounded,
                    title: 'Emergency QR Code',
                    subtitle: 'Lockscreen paramedic scan card',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/emergency/qr');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.emergency_outlined,
                    title: 'SOS',
                    subtitle: 'Emergency helpline & quick response',
                    accentColor: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      _showSosDialog(context);
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),

                  const Divider(height: 24, thickness: 1),

                  // ── ACCOUNT SECTION ──
                  _buildSectionHeader('ACCOUNT', sectionTitleColor),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'Patient details and account',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/profile');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Notifications, language, preferences',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/profile');
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy',
                    subtitle: 'Data protection & medical confidentiality',
                    onTap: () {
                      Navigator.pop(context);
                      _showPrivacyDialog(context, isDark);
                    },
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textMuted,
    Color? accentColor,
    int? badgeCount,
  }) {
    final effectiveAccent = accentColor ?? AppColors.primary;
    return ListTile(
      dense: true,
      horizontalTitleGap: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: effectiveAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: effectiveAccent,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text('Emergency SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'In case of medical emergencies or life-threatening adverse reactions:\n\n'
          '• Rescue 1122 / Ambulance\n'
          '• National Poison Control Center\n'
          '• Emergency Medical Profile is accessible via lockscreen QR code.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/emergency/profile');
            },
            icon: const Icon(Icons.contact_emergency_outlined, size: 18),
            label: const Text('View Profile'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Privacy & Data Safety', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'MedScan Pro Privacy Statement:\n\n'
            '1. Health & Medication Data: Your active medications, prescriptions, and reminder logs are stored securely with end-to-end encryption.\n\n'
            '2. No Sale of Health Data: MedScan Pro never sells or trades patient records, scans, or allergy information to third parties.\n\n'
            '3. Paramedic QR: Emergency lockscreen QR data contains only life-critical paramedic indicators (allergies, blood group, emergency contact) which you voluntarily enable.\n\n'
            '4. AI Disclaimers: Interactions with the AI Medicine Assistant are strictly informational and clinical-educational.',
            style: TextStyle(fontSize: 12.5, height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
