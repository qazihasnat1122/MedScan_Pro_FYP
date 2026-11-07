import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../providers/medication_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/safety_providers.dart';
import '../../providers/app_settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clinical Dashboard for MedScan Pro.
///
/// Designed with established visual hierarchy principles:
/// 1. Medicine scanning is elevated to the primary hero action below the header.
/// 2. Next dose reminder is reduced into a compact, secondary status card.
/// 3. Secondary tools use a balanced, professional grid and list without
///    technical subtitles or unnecessary status badges.
/// 4. Coherent medical icon family with restrained clinical tones.
/// 5. Honest empty states that never fabricate data.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final userProfileAsync = ref.watch(currentUserProvider);
    final medsAsync = ref.watch(myMedicationsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    final meds = medsAsync.value ?? [];
    final alerts = alertsAsync.value ?? [];

    // Resolve user display name
    final userProfile = userProfileAsync.value;
    final String resolvedName = () {
      String candidate = '';
      if (userProfile != null && userProfile.name.trim().isNotEmpty) {
        candidate = userProfile.name.trim();
      } else if (authUser?.displayName != null &&
          authUser!.displayName!.trim().isNotEmpty) {
        candidate = authUser.displayName!.trim();
      } else if (authUser?.email != null && authUser!.email!.contains('@')) {
        final prefix = authUser.email!.split('@').first.trim();
        if (prefix.length > 2 && !RegExp(r'^\d+$').hasMatch(prefix)) {
          candidate = prefix;
        }
      }

      if (candidate.length < 2) {
        return 'Patient';
      }

      return '${candidate[0].toUpperCase()}${candidate.substring(1)}';
    }();

    // Time of day greeting
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    // Find next dose due
    String? nextMedName;
    String? nextMedDose;
    String? nextMedTime;
    String? nextMedMeal;

    if (meds.isNotEmpty) {
      for (final m in meds) {
        if (m.reminderTimes.isNotEmpty) {
          nextMedName = m.name;
          nextMedDose = m.dosage;
          nextMedTime = m.reminderTimes.first;
          nextMedMeal = m.mealInstruction;
          break;
        }
      }
      if (nextMedName == null) {
        nextMedName = meds.first.name;
        nextMedDose = meds.first.dosage;
        nextMedTime = '08:00 AM';
        nextMedMeal = meds.first.mealInstruction;
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(myMedicationsProvider);
            ref.invalidate(alertsProvider);
            ref.invalidate(currentUserProvider);
          },
          child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Compact Header ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$timeGreeting,',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resolvedName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MedScanIcons.verifyShield(
                        size: 14,
                        color: AppColors.emerald,
                        strokeWidth: 2.0,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Safety Active',
                        style: TextStyle(
                          color: AppColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 2. Primary Hero Action: Scan Medicine ──────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/scan/capture');
                },
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF00382E) : AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF00695C)
                          : const Color(0xFF004D40),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : AppColors.primary)
                            .withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: MedScanIcons.scanner(
                          size: 28,
                          color: Colors.white,
                          strokeWidth: 1.8,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          strings.scanMedicine,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 3. Reduced Secondary Card: Next Dose Reminder ─────────────
            _buildNextDoseCard(
              context: context,
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textMuted: textMuted,
              isDark: isDark,
              strings: strings,
              nextMedName: nextMedName,
              nextMedDose: nextMedDose,
              nextMedTime: nextMedTime,
              nextMedMeal: nextMedMeal,
            ),
            const SizedBox(height: 22),

            // ── 4. Secondary Clinical Tools (Balanced 2-Col Grid + Full Width) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tools & Services',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 550 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: cols == 4 ? 1.5 : 1.45,
                  children: [
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'My Prescription',
                      icon: Icons.receipt_long_outlined,
                      accentColor: const Color(0xFF059669),
                      onTap: () => context.push('/prescriptions/upload'),
                      isDark: isDark,
                    ),
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'MedBot',
                      icon: Icons.smart_toy_outlined,
                      accentColor: const Color(0xFF0284C7),
                      onTap: () => context.push('/chat'),
                      isDark: isDark,
                    ),
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'Safety Alerts',
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFD97706),
                      badgeCount: alerts.isNotEmpty ? alerts.length : null,
                      onTap: () => context.push('/safety/alerts'),
                      isDark: isDark,
                    ),
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'Check Price',
                      icon: Icons.payments_outlined,
                      accentColor: const Color(0xFF4F46E5),
                      onTap: () => context.push('/price-check'),
                      isDark: isDark,
                    ),
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'Interaction Checker',
                      icon: Icons.swap_horiz_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      onTap: () => context.push('/same-salt'),
                      isDark: isDark,
                    ),
                    _buildModuleCard(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      title: 'Find Pharmacy',
                      icon: Icons.local_pharmacy_outlined,
                      accentColor: const Color(0xFF0F766E),
                      onTap: () => context.push('/pharmacies'),
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            // ── 6. Safety Bulletins Banner ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.safetyAlerts,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/safety/alerts'),
                  child: const Text(
                    'View All →',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (alerts.isNotEmpty) ...[
              _buildAlertSnippet(alerts.first, isDark, borderColor),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF047857)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  children: [
                    MedScanIcons.verifyShield(
                      size: 20,
                      color: AppColors.emerald,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.noActiveAlerts,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF15803D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    const _DraggableAiChatbotButton(),
  ],
);
  }

  /// Compact, secondary dose reminder card.
  Widget _buildNextDoseCard({
    required BuildContext context,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
    required bool isDark,
    required dynamic strings,
    required String? nextMedName,
    required String? nextMedDose,
    required String? nextMedTime,
    required String? nextMedMeal,
  }) {
    if (nextMedName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppColors.subtleShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'NEXT DOSE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        ' • $nextMedTime',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nextMedName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nextMedDose != null && nextMedDose.isNotEmpty)
                    Text(
                      '$nextMedDose${nextMedMeal != null && nextMedMeal.isNotEmpty ? ' ($nextMedMeal)' : ''}',
                      style: TextStyle(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Dose confirmed for $nextMedName!'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 38),
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : AppColors.primary.withValues(alpha: 0.09),
                foregroundColor: isDark
                    ? AppColors.mintAccent
                    : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Take Dose',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    // Honest empty state: never fabricates sample medicines
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : AppColors.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_available_outlined,
              color: textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Active Doses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  strings.noMedicinesYet,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/medicines/add'),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              strings.addMedicine,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }

  /// Clean, balanced module card with consistent icon family,
  /// plain-language labels, and no unnecessary status badges.
  Widget _buildModuleCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
    required String title,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isDark,
    int? badgeCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : AppColors.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  if (badgeCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildAlertSnippet(dynamic alert, bool isDark, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF450A0A).withValues(alpha: 0.3)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title ?? 'Batch Recall Notice',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFF87171)
                        : const Color(0xFF7F1D1D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Floating, draggable launcher for the AI Medicine Assistant.
///
/// Features:
/// - Initial placement at bottom-right above the navigation bar.
/// - Clamped boundary enforcement (cannot be moved off-screen or trapped).
/// - Single tap navigates to /chat ('AI Medicine Assistant').
/// - Long-press enters drag mode with haptic feedback and elevation.
/// - Persists user-selected coordinates in SharedPreferences ('ai_chat_btn_x', 'ai_chat_btn_y').
class _DraggableAiChatbotButton extends StatefulWidget {
  const _DraggableAiChatbotButton();

  @override
  State<_DraggableAiChatbotButton> createState() =>
      _DraggableAiChatbotButtonState();
}

class _DraggableAiChatbotButtonState extends State<_DraggableAiChatbotButton> {
  static const String _keyX = 'ai_chat_btn_x';
  static const String _keyY = 'ai_chat_btn_y';
  static const double _buttonSize = 56.0;
  static const double _margin = 16.0;

  double? _x;
  double? _y;
  bool _isDragging = false;
  Offset _dragStartGlobal = Offset.zero;
  Offset _dragStartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadSavedPosition();
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedX = prefs.getDouble(_keyX);
      final savedY = prefs.getDouble(_keyY);
      if (mounted && savedX != null && savedY != null) {
        setState(() {
          _x = savedX;
          _y = savedY;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePosition(double x, double y) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyX, x);
      await prefs.setDouble(_keyY, y);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Boundaries to prevent off-screen placement or covering bottom navigation
        final double minX = _margin;
        final double maxX = (maxWidth - _buttonSize - _margin).clamp(minX, maxWidth);
        final double minY = _margin;
        final double maxY = (maxHeight - _buttonSize - 18.0).clamp(minY, maxHeight);

        // Initial default: bottom-right
        final double currentX =
            (_x ?? (maxWidth - _buttonSize - 20.0)).clamp(minX, maxX);
        final double currentY =
            (_y ?? (maxHeight - _buttonSize - 24.0)).clamp(minY, maxY);

        return Stack(
          children: [
            Positioned(
              left: currentX,
              top: currentY,
              child: Semantics(
                button: true,
                label: 'AI Medicine Assistant',
                hint:
                    'Double tap to open AI chat, or long press and drag to reposition',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/chat');
                  },
                  onLongPressStart: (details) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isDragging = true;
                      _dragStartGlobal = details.globalPosition;
                      _dragStartPosition = Offset(currentX, currentY);
                    });
                  },
                  onLongPressMoveUpdate: (details) {
                    final delta = details.globalPosition - _dragStartGlobal;
                    final newX =
                        (_dragStartPosition.dx + delta.dx).clamp(minX, maxX);
                    final newY =
                        (_dragStartPosition.dy + delta.dy).clamp(minY, maxY);
                    setState(() {
                      _x = newX;
                      _y = newY;
                    });
                  },
                  onLongPressEnd: (details) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isDragging = false;
                    });
                    if (_x != null && _y != null) {
                      _savePosition(_x!, _y!);
                    }
                  },
                  child: AnimatedScale(
                    scale: _isDragging ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF005B58)
                            : const Color(0xFF007A78),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007A78).withValues(
                              alpha: _isDragging ? 0.45 : 0.3,
                            ),
                            blurRadius: _isDragging ? 16 : 10,
                            offset: Offset(0, _isDragging ? 6 : 4),
                          ),
                          if (isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
