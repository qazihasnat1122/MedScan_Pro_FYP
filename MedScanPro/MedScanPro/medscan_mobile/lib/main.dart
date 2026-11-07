import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/theme/theme.dart';
import 'core/routing/app_router.dart';
import 'firebase_options.dart';

import 'core/localization/app_strings.dart';
import 'providers/app_settings_providers.dart';
import 'providers/auth_providers.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set transparent system status bar with dark icons initially
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning: $e');
  }

  // Initialize medicine dose alarm & notifications
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('NotificationService initialization warning: $e');
  }

  runApp(const ProviderScope(child: MedScanMobileApp()));
}

class MedScanMobileApp extends ConsumerWidget {
  const MedScanMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);
    final strings = ref.watch(appStringsProvider);
    final authState = ref.watch(authStateProvider);
    final onboardingState = ref.watch(hasSeenOnboardingProvider);

    // Show a branded splash while Firebase auth or onboarding prefs are initializing
    if (authState.isLoading || onboardingState.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const _SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: strings.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: lang == AppLanguage.ur
          ? const Locale('ur', 'PK')
          : const Locale('en', 'US'),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Branded clinical splash screen shown during auth hydration
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppColors.primaryGlow,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MedScan Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next-Gen Medicine Verification & Health Tracking',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
