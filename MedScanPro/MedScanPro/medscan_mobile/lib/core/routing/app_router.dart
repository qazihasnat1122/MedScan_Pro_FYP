import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme.dart';
import '../../features/home/home_screen.dart';
import '../../features/medicines/my_medicines_screen.dart';
import '../../features/medicines/add_medicine_screen.dart';
import '../../features/prescriptions/prescription_upload_screen.dart';
import '../../features/safety/alerts_screen.dart';
import '../../features/safety/report_reaction_screen.dart';
import '../../features/safety/report_suspicious_screen.dart';
import '../../features/safety/verification_history_screen.dart';
import '../../features/emergency/emergency_profile_screen.dart';
import '../../features/emergency/emergency_qr_screen.dart';
import '../../features/emergency/emergency_qr_scanner_screen.dart';
import '../../features/records/records_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../providers/auth_providers.dart';

import '../../features/scan/processing_screen.dart';
import '../../features/scan/confirmation_screen.dart';
import '../../features/scan/lookup_result_screen.dart';
import '../../features/scan/live_barcode_scanner.dart';
import '../../features/scan/smart_scanner_screen.dart';
import '../../features/prescriptions/prescription_review_screen.dart';
import '../../services/prescription_parser.dart';
import '../../features/chat/ai_chat_screen.dart';
import '../../providers/app_settings_providers.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/medicines/same_salt_finder_screen.dart';
import '../../features/scan/price_check_screen.dart';
import '../../features/pharmacies/nearby_pharmacies_screen.dart';
import '../../shared/widgets/app_drawer.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (prev, next) => notifyListeners(),
    );
    _ref.listen<AsyncValue<bool>>(
      hasSeenOnboardingProvider,
      (prev, next) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final onboardingState = _ref.read(hasSeenOnboardingProvider);
    final currentLoc = state.matchedLocation;

    // Wait for both Firebase auth AND onboarding prefs to resolve
    if (authState.isLoading || onboardingState.isLoading) return null;

    final isAuth = authState.value != null;
    final hasSeenOnboarding = onboardingState.value ?? false;

    // 1. Allow user to view onboarding freely without being bounced
    if (currentLoc == '/onboarding') {
      return null;
    }

    // 2. Unauthenticated first-time visitors go to onboarding
    if (!hasSeenOnboarding && !isAuth) {
      return '/onboarding';
    }

    // 3. Unauthenticated users must be on /auth
    if (!isAuth) {
      return currentLoc == '/auth' ? null : '/auth';
    }

    // 4. Authenticated users on /auth or onboarding go to home
    if (isAuth && (currentLoc == '/auth' || currentLoc == '/onboarding')) {
      return '/';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: notifier.redirect,
    errorBuilder: (context, state) {
      debugPrint('GoRouter fallback route for error: ${state.error}');
      return const AuthScreen();
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/chat', builder: (context, state) => const AiChatScreen()),
      GoRoute(
        path: '/medicines/add',
        builder: (context, state) => const AddMedicineScreen(),
      ),
      GoRoute(
        path: '/prescriptions/upload',
        builder: (context, state) => const PrescriptionUploadScreen(),
      ),
      GoRoute(
        path: '/prescriptions/review',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PrescriptionReviewScreen(
            initialItems: extra?['items'] as List<PrescriptionMedicineItem>?,
            imagePath: extra?['imagePath'] as String?,
            previewImagePaths: (extra?['previewImagePaths'] as List?)
                ?.map((e) => e.toString())
                .toList(),
            rawText: extra?['rawText'] as String?,
            prescriptionDate: extra?['prescriptionDate'] as String?,
            mimeType: extra?['mimeType'] as String?,
            fileName: extra?['fileName'] as String?,
            extractionSource: extra?['extractionSource'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/safety/reaction',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ReportReactionScreen(
            prefilledMedicineName: extra?['medicineName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/safety/report',
        builder: (context, state) => const ReportSuspiciousScreen(),
      ),
      GoRoute(
        path: '/safety/history',
        builder: (context, state) => const VerificationHistoryScreen(),
      ),
      GoRoute(
        path: '/emergency/profile',
        builder: (context, state) => const EmergencyProfileScreen(),
      ),
      GoRoute(
        path: '/emergency/qr',
        builder: (context, state) => const EmergencyQrScreen(),
      ),
      GoRoute(
        path: '/emergency/scan',
        builder: (context, state) => const EmergencyQrScannerScreen(),
      ),
      GoRoute(
        path: '/records',
        builder: (context, state) => const RecordsScreen(),
      ),
      GoRoute(
        path: '/scan/capture',
        builder: (context, state) => const SmartScannerScreen(),
      ),
      GoRoute(
        path: '/scan/smart',
        builder: (context, state) => const SmartScannerScreen(),
      ),
      GoRoute(
        path: '/scan/processing',
        builder: (context, state) => const ProcessingScreen(),
      ),
      GoRoute(
        path: '/scan/confirm',
        builder: (context, state) => const ConfirmationScreen(),
      ),
      GoRoute(
        path: '/scan/result',
        builder: (context, state) => const LookupResultScreen(),
      ),
      GoRoute(
        path: '/scan/live_barcode',
        builder: (context, state) => const LiveBarcodeScannerScreen(),
      ),
      GoRoute(
        path: '/same-salt',
        builder: (context, state) => const SameSaltFinderScreen(),
      ),
      GoRoute(
        path: '/price-check',
        builder: (context, state) => const PriceCheckScreen(),
      ),
      GoRoute(
        path: '/pharmacies',
        builder: (context, state) => const NearbyPharmaciesScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/medicines',
            builder: (context, state) => const MyMedicinesScreen(),
          ),
          GoRoute(
            path: '/safety/alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int idx = _calculateSelectedIndex(context);
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).cardColor;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final activeColor = AppColors.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.medical_services_outlined,
                color: activeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                text: 'MedScan ',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
                children: [
                  TextSpan(
                    text: 'Pro',
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Quick Clinical AI Chat Icon
          IconButton(
            tooltip: strings.aiAssistant,
            onPressed: () => GoRouter.of(context).push('/chat'),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF0284C7),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Emergency Medical Profile / SOS Button
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => GoRouter.of(context).push('/emergency/profile'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emergency_outlined,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavBarItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: strings.navHome,
                          isSelected: idx == 0,
                          onTap: () => _onItemTapped(0, context),
                        ),
                        _NavBarItem(
                          icon: Icons.medication_outlined,
                          activeIcon: Icons.medication_rounded,
                          label: strings.navMedicines,
                          isSelected: idx == 1,
                          onTap: () => _onItemTapped(1, context),
                        ),
                        const SizedBox(width: 58), // Space for Scan button
                        _NavBarItem(
                          icon: Icons.notifications_outlined,
                          activeIcon: Icons.notifications_rounded,
                          label: strings.navAlerts,
                          isSelected: idx == 2,
                          onTap: () => _onItemTapped(2, context),
                          hasBadge: true,
                        ),
                        _NavBarItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: strings.navProfile,
                          isSelected: idx == 3,
                          onTap: () => _onItemTapped(3, context),
                        ),
                      ],
                    ),
                    Positioned(
                      top: -18,
                      child: GestureDetector(
                        onTap: () => context.push('/scan/capture'),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF00382E)
                                    : activeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: surfaceColor,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: MedScanIcons.scanner(
                                size: 26,
                                color: Colors.white,
                                strokeWidth: 1.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.navScan,
                              style: TextStyle(
                                color: activeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/medicines')) return 1;
    if (location == '/safety/alerts') return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/medicines');
        break;
      case 2:
        context.go('/safety/alerts');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasBadge;

  const _NavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF00897B);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? (activeIcon ?? icon) : icon,
                  color: color,
                  size: 24,
                ),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
