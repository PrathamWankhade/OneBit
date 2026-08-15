import 'package:flutter/material.dart';

/// Theme preference: how the app decides between the light and dark
/// identities.
///
/// The product ships exactly two visual identities — light and dark — plus
/// a system-follow mode. There is no third "terminal" identity: the whole
/// design language is monochrome in both directions.
enum ThemePreference {
  /// Follow the platform brightness.
  system,

  /// Force the light identity.
  light,

  /// Force the dark identity.
  dark;

  /// The [ThemeMode] driving `MaterialApp`.
  ThemeMode get themeMode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  /// Resolves from a raw string; unknown names fall back to
  /// [ThemePreference.system].
  static ThemePreference fromName(String? name) => values.firstWhere(
    (t) => t.name == name,
    orElse: () => ThemePreference.system,
  );

  /// Localization key suffix (matches ARB keys, e.g. `settingsThemeSystem`).
  String get settingsKey =>
      'settingsTheme${name[0].toUpperCase()}${name.substring(1)}';
}
