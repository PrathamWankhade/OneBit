import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';

void main() {
  group('OneBitThemeData construction', () {
    test('light identity builds and binds tokens', () {
      final theme = OneBitTheme.light;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF111111));
      expect(theme.colorScheme.primary, const Color(0xFF111111));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF666666));
      expect(theme.colorScheme.outline, const Color(0xFFD8D8D8));
    });

    test('dark identity builds and binds tokens', () {
      final theme = OneBitTheme.dark;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.colorScheme.surface, const Color(0xFF111111));
      expect(theme.colorScheme.primary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
    });

    test('preference resolution maps to identities', () {
      expect(OneBitTheme.of(ThemePreference.dark).brightness, Brightness.dark);
      expect(
        OneBitTheme.of(ThemePreference.light).brightness,
        Brightness.light,
      );
      expect(
        OneBitTheme.of(ThemePreference.system).brightness,
        Brightness.light,
      );
    });
  });

  group('Palette contracts', () {
    test('dark palette matches the design spec', () {
      expect(OneBitPalette.darkBackground, const Color(0xFF000000));
      expect(OneBitPalette.darkSurface, const Color(0xFF111111));
      expect(OneBitPalette.darkSurfaceAlt, const Color(0xFF161616));
      expect(OneBitPalette.darkCard, const Color(0xFF1D1D1D));
      expect(OneBitPalette.darkBorder, const Color(0xFF2C2C2C));
      expect(OneBitPalette.darkDivider, const Color(0xFF232323));
      expect(OneBitPalette.darkTextPrimary, const Color(0xFFFFFFFF));
      expect(OneBitPalette.darkTextSecondary, const Color(0xFFA8A8A8));
      expect(OneBitPalette.darkTextMuted, const Color(0xFF777777));
      expect(OneBitPalette.darkTextDisabled, const Color(0xFF5E5E5E));
    });

    test('light palette matches the design spec', () {
      expect(OneBitPalette.lightBackground, const Color(0xFFFAFAFA));
      expect(OneBitPalette.lightSurface, const Color(0xFFFFFFFF));
      expect(OneBitPalette.lightBorder, const Color(0xFFD8D8D8));
      expect(OneBitPalette.lightPrimary, const Color(0xFF111111));
      expect(OneBitPalette.lightSecondary, const Color(0xFF666666));
    });

    test('ANSI palette has all 16 colors', () {
      // Normal intensity
      expect(OneBitPalette.ansiBlack, isA<Color>());
      expect(OneBitPalette.ansiRed, isA<Color>());
      expect(OneBitPalette.ansiGreen, isA<Color>());
      expect(OneBitPalette.ansiYellow, isA<Color>());
      expect(OneBitPalette.ansiBlue, isA<Color>());
      expect(OneBitPalette.ansiPurple, isA<Color>());
      expect(OneBitPalette.ansiCyan, isA<Color>());
      expect(OneBitPalette.ansiWhite, isA<Color>());
      // Bright intensity
      expect(OneBitPalette.ansiBrightBlack, isA<Color>());
      expect(OneBitPalette.ansiBrightRed, isA<Color>());
      expect(OneBitPalette.ansiBrightGreen, isA<Color>());
      expect(OneBitPalette.ansiBrightYellow, isA<Color>());
      expect(OneBitPalette.ansiBrightBlue, isA<Color>());
      expect(OneBitPalette.ansiBrightPurple, isA<Color>());
      expect(OneBitPalette.ansiBrightCyan, isA<Color>());
      expect(OneBitPalette.ansiBrightWhite, isA<Color>());
    });

    test('light ANSI palette has all colors', () {
      expect(OneBitPalette.lightAnsiRed, isA<Color>());
      expect(OneBitPalette.lightAnsiGreen, isA<Color>());
      expect(OneBitPalette.lightAnsiYellow, isA<Color>());
      expect(OneBitPalette.lightAnsiBlue, isA<Color>());
      expect(OneBitPalette.lightAnsiPurple, isA<Color>());
      expect(OneBitPalette.lightAnsiCyan, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightRed, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightGreen, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightYellow, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightBlue, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightPurple, isA<Color>());
      expect(OneBitPalette.lightAnsiBrightCyan, isA<Color>());
    });
  });

  group('OneBitThemeExtension', () {
    test('ships on both identities with primary surfaces', () {
      final light = OneBitTheme.light.extension<OneBitThemeExtension>();
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(light!.primarySurface, const Color(0xFFFFFFFF));
      expect(dark!.primarySurface, const Color(0xFF1D1D1D));
    });

    test('semantic status colors are defined', () {
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(dark, isNotNull);
      expect(dark!.success, isA<Color>());
      expect(dark.warning, isA<Color>());
      expect(dark.info, isA<Color>());
      expect(dark.accent, isA<Color>());
    });

    test('text hierarchy is defined', () {
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(dark, isNotNull);
      expect(dark!.textPrimary, isA<Color>());
      expect(dark.textSecondary, isA<Color>());
      expect(dark.textMuted, isA<Color>());
      expect(dark.textDisabled, isA<Color>());
    });

    test('navigation tokens are defined', () {
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(dark, isNotNull);
      expect(dark!.selectedBackground, isA<Color>());
      expect(dark.selectedForeground, isA<Color>());
      expect(dark.selectedIcon, isA<Color>());
      expect(dark.iconPrimary, isA<Color>());
      expect(dark.iconSecondary, isA<Color>());
    });

    test('surface tokens are defined', () {
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(dark, isNotNull);
      expect(dark!.surfaceElevated, isA<Color>());
      expect(dark.monoBackground, isA<Color>());
      expect(dark.border, isA<Color>());
      expect(dark.borderStrong, isA<Color>());
      expect(dark.surfaceInteractive, isA<Color>());
    });
  });
}
