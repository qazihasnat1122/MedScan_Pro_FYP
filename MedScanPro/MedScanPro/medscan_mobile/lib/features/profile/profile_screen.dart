import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../core/localization/app_strings.dart';
import '../../services/notification_service.dart';

/// Clean, list-tile-based Profile and Settings screen with theme & language
/// toggles, emergency health features, and a distinct high-contrast Sign Out zone.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(
              strings.signOut,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          strings.confirmSignOut,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              strings.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              strings.signOut,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final strings = ref.watch(appStringsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentLang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final profile = userAsync.value;
    final name = (profile?.name != null && profile!.name.isNotEmpty)
        ? profile.name
        : (firebaseUser?.displayName ??
              (firebaseUser?.email?.split('@').first ?? 'Valued Patient'));
    final email = (profile?.email != null && profile!.email.isNotEmpty)
        ? profile.email
        : (firebaseUser?.email ?? 'patient@medscan.local');
    final role = (profile?.role ?? 'Patient').toUpperCase();

    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              // ── 1. User Identity Profile Card ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? [] : AppColors.subtleShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── 2. App Preferences (Theme & Language Toggles) ─────────────
              _buildSectionHeader(strings.appearance, textMuted),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? [] : AppColors.subtleShadow,
                ),
                child: Column(
                  children: [
                    // Theme Switch Tile
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.amber : AppColors.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_rounded,
                            color: isDark ? Colors.amber : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.themeMode,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                isDark ? strings.darkTheme : strings.lightTheme,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSlidingSegmentedControl<ThemeMode>(
                          groupValue: themeMode,
                          children: const {
                            ThemeMode.light: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wb_sunny_rounded, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Light',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ThemeMode.dark: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.nightlight_round, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Dark',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setTheme(val);
                            }
                          },
                        ),
                      ],
                    ),
                    Divider(height: 20, color: borderColor),

                    // Language Switch Tile
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0284C7,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: Color(0xFF0284C7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.languageSettings,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                currentLang == AppLanguage.ur
                                    ? 'اردو (Urdu Active)'
                                    : 'English Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSlidingSegmentedControl<AppLanguage>(
                          groupValue: currentLang,
                          children: const {
                            AppLanguage.en: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                'EN',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            AppLanguage.ur: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                'اردو',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(languageProvider.notifier)
                                  .setLanguage(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── 3. Alarms & Sound Alerts ──────────────────────────────────
              _buildSectionHeader(strings.alarmsAndReminders, textMuted),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? [] : AppColors.subtleShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alarm_on_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.alarmsAndReminders,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Audio alerts & scheduled push notifications',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final notif = NotificationService();
                          await notif.showInstantAlarm(
                            id: 9999,
                            title: '🔔 ${strings.timeForDose}',
                            body:
                                'Panadol 500mg • Take 1 Tablet after meal with water.',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.testAlarmTriggered),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.ring_volume_rounded, size: 16),
                        label: Text(strings.testAlarm),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── 4. Emergency & Medical ID ─────────────────────────────────
              _buildSectionHeader(strings.emergencyProfile, textMuted),
              const SizedBox(height: 8),
              _buildActionTile(
                context: context,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
                icon: Icons.emergency_rounded,
                iconColor: const Color(0xFFEF4444),
                title: strings.emergencyProfile,
                subtitle:
                    '${strings.bloodGroup}, ${strings.allergies}, ${strings.emergencyContact}',
                onTap: () => context.push('/emergency/profile'),
              ),
              _buildActionTile(
                context: context,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
                icon: Icons.qr_code_rounded,
                iconColor: AppColors.primary,
                title: 'Emergency Medical QR Code',
                subtitle: 'Offline emergency access card for first responders',
                onTap: () => context.push('/emergency/qr'),
              ),
              const SizedBox(height: 20),

              // ── 5. Safety, Recalls & History ──────────────────────────────
              _buildSectionHeader(strings.safetyAlerts, textMuted),
              const SizedBox(height: 8),
              _buildActionTile(
                context: context,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
                icon: Icons.notification_important_rounded,
                iconColor: const Color(0xFFD97706),
                title: strings.safetyAlerts,
                subtitle: 'Official batch recall notices & adulteration flags',
                onTap: () => context.push('/safety/alerts'),
              ),
              _buildActionTile(
                context: context,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Scan History',
                subtitle: 'Log of genuine and inspected medicine scans',
                onTap: () => context.push('/safety/history'),
              ),
              const SizedBox(height: 20),

              // ── 6. Clinical Disclaimer Banner ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF162032)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.aiDisclaimer,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 7. Distinct & High-Visibility Sign Out Zone ───────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D1515)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFECACA),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Account Session',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Signing out clears active temporary session tokens. Your saved medications and scan history remain securely backed up in Cloud Firestore.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF991B1B),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmSignOut(context, ref, strings),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          strings.signOut,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSectionHeader(String title, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static Widget _buildActionTile({
    required BuildContext context,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? []
            : AppColors.subtleShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}
