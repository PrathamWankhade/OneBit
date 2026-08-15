import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';

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
      expect(theme.colorScheme.surface, const Color(0xFF050505));
      expect(theme.colorScheme.primary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFB8B8B8));
      expect(theme.colorScheme.outline, const Color(0xFF3A3A3A));
      expect(theme.colorScheme.outlineVariant, const Color(0xFF2D2D2D));
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
      expect(OneBitPalette.darkSurface, const Color(0xFF050505));
      expect(OneBitPalette.darkSurfaceAlt, const Color(0xFF101010));
      expect(OneBitPalette.darkCard, const Color(0xFF1E1E1E));
      expect(OneBitPalette.darkBorder, const Color(0xFF3A3A3A));
      expect(OneBitPalette.darkDivider, const Color(0xFF2D2D2D));
      expect(OneBitPalette.darkTextPrimary, const Color(0xFFFFFFFF));
      expect(OneBitPalette.darkTextSecondary, const Color(0xFFB8B8B8));
      expect(OneBitPalette.darkTextMuted, const Color(0xFF777777));
      expect(OneBitPalette.darkTextDisabled, const Color(0xFF555555));
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
  });

  group('OneBitThemeExtension', () {
    test('ships on both identities with card surfaces', () {
      final light = OneBitTheme.light.extension<OneBitThemeExtension>();
      final dark = OneBitTheme.dark.extension<OneBitThemeExtension>();
      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(light!.card, const Color(0xFFFFFFFF));
      expect(dark!.card, OneBitPalette.darkCard);
      expect(dark.monoBackground, OneBitPalette.black);
    });

    test('surface tokens are present on dark identity', () {
      const ext = OneBitThemeExtension.dark;
      expect(ext.background, OneBitPalette.darkBackground);
      expect(ext.surface, OneBitPalette.darkSurface);
      expect(ext.surfaceSecondary, OneBitPalette.darkSurfaceAlt);
      expect(ext.surfaceElevated, OneBitPalette.darkElevated);
      expect(ext.card, OneBitPalette.darkCard);
      expect(ext.border, OneBitPalette.darkBorder);
      expect(ext.divider, OneBitPalette.darkDivider);
    });

    test('text tokens are present on dark identity', () {
      const ext = OneBitThemeExtension.dark;
      expect(ext.textPrimary, OneBitPalette.darkTextPrimary);
      expect(ext.textSecondary, OneBitPalette.darkTextSecondary);
      expect(ext.textMuted, OneBitPalette.darkTextMuted);
      expect(ext.disabled, OneBitPalette.darkTextDisabled);
    });

    test('domain semantic colors map to ANSI palette', () {
      const ext = OneBitThemeExtension.dark;
      expect(ext.identity, OneBitPalette.ansiPurple);
      expect(ext.network, OneBitPalette.ansiCyan);
      expect(ext.relay, OneBitPalette.ansiBlue);
      expect(ext.pending, OneBitPalette.ansiYellow);
    });

    test('bright ANSI colors are present', () {
      const ext = OneBitThemeExtension.dark;
      expect(ext.ansiBrightBlack, OneBitPalette.ansiBrightBlack);
      expect(ext.ansiBrightRed, OneBitPalette.ansiBrightRed);
      expect(ext.ansiBrightGreen, OneBitPalette.ansiBrightGreen);
      expect(ext.ansiBrightYellow, OneBitPalette.ansiBrightYellow);
      expect(ext.ansiBrightBlue, OneBitPalette.ansiBrightBlue);
      expect(ext.ansiBrightPurple, OneBitPalette.ansiBrightPurple);
      expect(ext.ansiBrightCyan, OneBitPalette.ansiBrightCyan);
      expect(ext.ansiBrightWhite, OneBitPalette.ansiBrightWhite);
    });

    test('copyWith and lerp preserve the token set', () {
      const base = OneBitThemeExtension.light;
      final changed = base.copyWith(success: const Color(0xFF123456));
      expect(changed.success, const Color(0xFF123456));
      expect(changed.warning, base.warning);

      final lerped = base.lerp(OneBitThemeExtension.dark, 0.5);
      expect(lerped.card, isNot(base.card));
      final self = base.lerp(null, 0.5);
      expect(self.card, base.card);
    });
  });

  group('Theme system wiring', () {
    test('component themes bind the shape tokens', () {
      final light = OneBitTheme.light;
      expect(light.filledButtonTheme.style, isNotNull);
      expect(light.outlinedButtonTheme.style, isNotNull);
      expect(light.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(light.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(light.dividerTheme.color, light.colorScheme.outlineVariant);
      expect(light.dividerTheme.thickness, 1);
    });

    test('typography resolves to Consolas on both identities', () {
      expect(OneBitTheme.light.textTheme.bodyLarge?.fontFamily, 'Consolas');
      expect(OneBitTheme.dark.textTheme.bodyLarge?.fontFamily, 'Consolas');
      expect(
        OneBitTheme.dark.textTheme.labelSmall?.color,
        const Color(0xFFB8B8B8),
      );
    });

    test('no gradients or glossy effects exist in the theme surface', () {
      final light = OneBitTheme.light;
      expect(light.scaffoldBackgroundColor.a, 1.0);
      expect(light.cardTheme.surfaceTintColor, isNull);
      expect(light.visualDensity, VisualDensity.standard);
    });

    test('page transitions use restrained forward fades', () {
      final builders = OneBitTheme.dark.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<FadeForwardsPageTransitionsBuilder>(),
      );
      expect(builders[TargetPlatform.iOS], isNotNull);
    });
  });
}
