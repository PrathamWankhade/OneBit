import 'package:flutter/material.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_data.dart';

/// Framework facade over the design system's theme builders.
///
/// Keeps `ThemeData` construction out of the widget layer; features never
/// build a theme themselves. `MaterialApp` binds `OneBitTheme.light` and
/// `OneBitTheme.dark` and lets `themePreferenceProvider` decide the mode.
abstract final class OneBitTheme {
  const OneBitTheme._();

  /// ThemeData for [preference]; `system` resolves to the light identity
  /// because mode resolution happens in `MaterialApp` via
  /// [ThemePreference.themeMode].
  static ThemeData of(ThemePreference preference) =>
      OneBitThemeData.build(preference);

  /// The dark identity (near-black monochrome).
  static ThemeData get dark => OneBitDarkTheme.build();

  /// The light identity (paper-white monochrome).
  static ThemeData get light => OneBitLightTheme.build();
}
