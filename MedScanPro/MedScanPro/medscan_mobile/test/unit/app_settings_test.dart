import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medscan_mobile/core/localization/app_strings.dart';
import 'package:medscan_mobile/providers/app_settings_providers.dart';

void main() {
  group('App Localization & Urdu Strings Tests', () {
    test('English strings are properly populated', () {
      final en = AppStrings(AppLanguage.en);
      expect(en.isUrdu, false);
      expect(en.appTitle, 'MedScan Pro');
      expect(en.navHome, 'Dashboard');
      expect(en.navMedicines, 'Medicines');
      expect(en.signIn, 'Sign In');
      expect(en.alarmsAndReminders, 'Medicine Alarms & Reminders');
      expect(en.testAlarm, 'Test Alarm Now');
    });

    test('Urdu strings are accurate and provide complete coverage', () {
      final ur = AppStrings(AppLanguage.ur);
      expect(ur.isUrdu, true);
      expect(ur.appTitle, 'میڈ اسکین پرو');
      expect(ur.navHome, 'ڈیش بورڈ');
      expect(ur.navMedicines, 'دوائیاں');
      expect(ur.signIn, 'سائن ان کریں');
      expect(ur.alarmsAndReminders, 'دوا کے الارم اور یاد دہانی');
      expect(ur.testAlarm, 'ٹیسٹ الارم بجائیں');
      expect(ur.emergencyProfile, 'ہنگامی طبی پروفائل');
    });
  });

  group('Theme & Language Notifier State Tests', () {
    test('ThemeModeNotifier toggles between light and dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('LanguageNotifier toggles and propagates to AppStrings provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(languageProvider), AppLanguage.en);
      expect(container.read(appStringsProvider).isUrdu, false);

      container.read(languageProvider.notifier).toggleLanguage();
      expect(container.read(languageProvider), AppLanguage.ur);
      expect(container.read(appStringsProvider).isUrdu, true);
      expect(container.read(appStringsProvider).appTitle, 'میڈ اسکین پرو');

      container.read(languageProvider.notifier).setLanguage(AppLanguage.en);
      expect(container.read(languageProvider), AppLanguage.en);
      expect(container.read(appStringsProvider).isUrdu, false);
    });
  });
}
