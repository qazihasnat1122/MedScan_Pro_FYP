import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medscan_mobile/main.dart';
import 'package:medscan_mobile/features/onboarding/onboarding_screen.dart';
import 'package:medscan_mobile/features/auth/auth_screen.dart';
import 'package:medscan_mobile/features/home/home_screen.dart';
import 'package:medscan_mobile/core/routing/app_router.dart';
import 'package:medscan_mobile/providers/auth_providers.dart';
import 'package:medscan_mobile/providers/app_settings_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'mock-patient-123';
  @override
  String? get email => 'patient@medscan.pk';
  @override
  String? get displayName => 'Patient';
}

class FakeOnboardingNotifier extends OnboardingNotifier {
  final bool initial;
  FakeOnboardingNotifier(this.initial);

  @override
  Future<bool> build() async => initial;
}

void main() {
  testWidgets('Fresh install shows OnboardingScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => FakeOnboardingNotifier(false),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MedScanMobileApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Returning unauthenticated user shows AuthScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => FakeOnboardingNotifier(true),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MedScanMobileApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Authenticated user shows MainShell with HomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSeenOnboardingProvider.overrideWith(
            () => FakeOnboardingNotifier(true),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(MockUser())),
        ],
        child: const MedScanMobileApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(MainShell), findsOneWidget);
  });
}
