import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/core/theme/theme_preference_provider.dart';

void main() {
  group('ThemePreference', () {
    test('maps to ThemeMode for MaterialApp', () {
      expect(ThemePreference.system.themeMode, ThemeMode.system);
      expect(ThemePreference.light.themeMode, ThemeMode.light);
      expect(ThemePreference.dark.themeMode, ThemeMode.dark);
    });

    test('fromName falls back to system for unknown values', () {
      expect(ThemePreference.fromName('dark'), ThemePreference.dark);
      expect(ThemePreference.fromName('light'), ThemePreference.light);
      expect(ThemePreference.fromName('system'), ThemePreference.system);
      expect(ThemePreference.fromName('terminal'), ThemePreference.system);
      expect(ThemePreference.fromName(null), ThemePreference.system);
    });

    test('settingsKey maps to ARB suffixes', () {
      expect(ThemePreference.system.settingsKey, 'settingsThemeSystem');
      expect(ThemePreference.light.settingsKey, 'settingsThemeLight');
      expect(ThemePreference.dark.settingsKey, 'settingsThemeDark');
    });
  });

  group('themePreferenceProvider', () {
    test('defaults to system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themePreferenceProvider), ThemePreference.system);
    });

    test('setTheme persists the selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(themePreferenceProvider.notifier);
      controller.setTheme(ThemePreference.dark);
      expect(container.read(themePreferenceProvider), ThemePreference.dark);
    });

    test('cycleTheme walks system → light → dark → system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(themePreferenceProvider.notifier);
      expect(container.read(themePreferenceProvider), ThemePreference.system);
      controller.cycleTheme();
      expect(container.read(themePreferenceProvider), ThemePreference.light);
      controller.cycleTheme();
      expect(container.read(themePreferenceProvider), ThemePreference.dark);
      controller.cycleTheme();
      expect(container.read(themePreferenceProvider), ThemePreference.system);
    });
  });
}
