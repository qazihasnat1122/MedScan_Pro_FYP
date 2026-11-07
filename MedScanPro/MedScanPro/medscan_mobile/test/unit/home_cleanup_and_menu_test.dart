import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medscan_mobile/shared/widgets/app_drawer.dart';
import 'package:medscan_mobile/features/home/home_screen.dart';
import 'package:medscan_mobile/features/profile/profile_screen.dart';
import 'package:medscan_mobile/providers/auth_providers.dart';
import 'package:medscan_mobile/providers/medication_providers.dart';
import 'package:medscan_mobile/providers/safety_providers.dart';
import 'package:medscan_mobile/core/localization/app_strings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppDrawer Section & Item Verification', () {
    testWidgets('Renders all four organized sections with exact items', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: AppDrawer(),
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Section Headers
      expect(find.text('MEDICINES'), findsOneWidget);
      expect(find.text('SAFETY'), findsOneWidget);
      expect(find.text('HEALTH & EMERGENCY'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Section 1: MEDICINES
      expect(find.text('My Medicines'), findsOneWidget);
      expect(find.text('My Prescriptions'), findsOneWidget);
      expect(find.text('Similar Medicines'), findsOneWidget);
      expect(find.text('Check Price'), findsOneWidget);
      expect(find.text('Dose History'), findsOneWidget);
      expect(find.text('Scan History'), findsOneWidget);

      // Section 2: SAFETY (misleading 'Medicine Safety' removed)
      expect(find.text('Medicine Safety'), findsNothing);
      expect(find.text('Safety Alerts'), findsOneWidget);
      expect(find.text('Find Pharmacy'), findsOneWidget);

      // Section 3: HEALTH & EMERGENCY
      expect(find.text('Emergency Profile'), findsOneWidget);
      expect(find.text('Emergency QR Code'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);

      // Section 4: ACCOUNT
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('Tapping Privacy shows Privacy Policy Dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: AppDrawer(),
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap Privacy item
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Data Safety'), findsOneWidget);
      expect(find.text('I Understand'), findsOneWidget);
    });

    testWidgets('Tapping SOS shows Emergency SOS dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: AppDrawer(),
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap SOS item
      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
    });

    testWidgets('Tapping Scan History in AppDrawer pushes /safety/history route', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? pushedLocation;
      final testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              drawer: AppDrawer(),
              body: Center(child: Text('Home Content')),
            ),
          ),
          GoRoute(
            path: '/safety/history',
            builder: (context, state) {
              pushedLocation = '/safety/history';
              return const Scaffold(body: Text('Scan History Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap Scan History item
      await tester.tap(find.text('Scan History'));
      await tester.pumpAndSettle();

      expect(pushedLocation, '/safety/history');
      expect(find.text('Scan History Screen'), findsOneWidget);
    });

    testWidgets('Tapping Scan History in ProfileScreen pushes /safety/history route', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? pushedLocation;
      final testRouter = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: ProfileScreen()),
          ),
          GoRoute(
            path: '/safety/history',
            builder: (context, state) {
              pushedLocation = '/safety/history';
              return const Scaffold(body: Text('Scan History Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            alertsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap Scan History tile in ProfileScreen
      await tester.scrollUntilVisible(find.text('Scan History'), 100);
      await tester.tap(find.text('Scan History'));
      await tester.pumpAndSettle();

      expect(pushedLocation, '/safety/history');
      expect(find.text('Scan History Screen'), findsOneWidget);
    });
  });

  group('HomeScreen Cleanup & Floating AI Launcher Verification', () {
    testWidgets('Home excludes Similar Medicines and Dose History chart', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myMedicationsProvider.overrideWith((ref) => Stream.value([])),
            alertsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Similar Medicines must NOT be on Home
      expect(find.text('Similar Medicines'), findsNothing);

      // Dose History must NOT be on Home
      expect(find.text('Dose History'), findsNothing);

      // Primary scan hero card is present
      expect(find.text('Scan Medicine'), findsOneWidget);

      // Compact Next Dose card is present
      expect(find.text('No Active Doses'), findsOneWidget);

      // Remaining secondary tools present
      expect(find.text('My Prescription'), findsOneWidget);
      expect(find.text('Safety Alerts'), findsOneWidget);
      expect(find.text('Check Price'), findsOneWidget);
      expect(find.text('Find Pharmacy'), findsOneWidget);

      // Floating AI Assistant Launcher present with semantics
      final aiSemantics = find.bySemanticsLabel('AI Medicine Assistant');
      expect(aiSemantics, findsOneWidget);
    });
  });

  group('AI Disclaimer Verification', () {
    test('English disclaimer contains clinical reference & non-diagnosis guidance', () {
      final strings = AppStrings(AppLanguage.en);
      expect(strings.aiDisclaimer, contains('reference only'));
      expect(strings.aiDisclaimer, contains('may be incorrect'));
      expect(strings.aiDisclaimer, contains('does not provide medical diagnosis'));
    });

    test('Urdu disclaimer contains accurate guidance', () {
      final strings = AppStrings(AppLanguage.ur);
      expect(strings.aiDisclaimer, contains('حوالہ اور آگاہی'));
      expect(strings.aiDisclaimer, contains('طبی تشخیص کا متبادل نہیں'));
    });
  });
}
