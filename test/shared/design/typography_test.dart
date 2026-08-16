import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

void main() {
  group('OneBitTypography families', () {
    test('primary family is Consolas, technical family is Consolas', () {
      expect(OneBitTypography.primaryFamily, 'Consolas');
      expect(OneBitTypography.technicalFamily, 'Consolas');
      expect(OneBitTypography.primaryFallback, contains('monospace'));
      expect(OneBitTypography.technicalFallback, contains('monospace'));
    });
  });

  group('OneBitTypography scale', () {
    test('scale tokens match the design spec', () {
      expect(OneBitTypography.display, 32);
      expect(OneBitTypography.headline, 24);
      expect(OneBitTypography.pageTitle, 28);
      expect(OneBitTypography.sectionTitle, 18);
      expect(OneBitTypography.body, 16);
      expect(OneBitTypography.cardTitle, 17);
      expect(OneBitTypography.bodySecondary, 14);
      expect(OneBitTypography.caption, 12);
      expect(OneBitTypography.overline, 10);
      expect(OneBitTypography.terminal, 16);
      expect(OneBitTypography.numeric, 13);
      expect(OneBitTypography.button, 14);
    });

    test('technical sizes are declared', () {
      expect(OneBitTypography.nodeId, 13);
      expect(OneBitTypography.fingerprint, 12);
      expect(OneBitTypography.packetId, 12);
      expect(OneBitTypography.log, 12);
      expect(OneBitTypography.diagnostic, 10);
    });

    test('weights are declared', () {
      expect(OneBitTypography.regular, FontWeight.w400);
      expect(OneBitTypography.medium, FontWeight.w500);
      expect(OneBitTypography.semibold, FontWeight.w600);
      expect(OneBitTypography.bold, FontWeight.w700);
    });

    test('letter spacing values are declared', () {
      expect(OneBitTypography.displaySpacing, -0.5);
      expect(OneBitTypography.headlineSpacing, -0.25);
      expect(OneBitTypography.bodySpacing, 0);
      expect(OneBitTypography.technicalSpacing, 0.2);
      expect(OneBitTypography.overlineSpacing, 1.2);
    });
  });

  group('OneBitTypography.buildTextTheme', () {
    const scheme = OneBitColorSchemes.dark;

    test('every style carries the Consolas family', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.fontFamily, OneBitTypography.primaryFamily);
      expect(theme.bodyMedium?.fontFamily, OneBitTypography.primaryFamily);
      expect(theme.labelSmall?.fontFamily, OneBitTypography.primaryFamily);
    });

    test('scale values are honored', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.fontSize, OneBitTypography.display);
      expect(theme.titleLarge?.fontSize, OneBitTypography.cardTitle);
      expect(theme.bodyMedium?.fontSize, OneBitTypography.bodySecondary);
      expect(theme.labelSmall?.fontSize, 10);
    });

    test('colors resolve from the scheme', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.color, scheme.onSurface);
      expect(theme.bodyMedium?.color, scheme.onSurfaceVariant);
    });

    test('overline labels carry tracking', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(
        theme.labelSmall?.letterSpacing,
        OneBitTypography.overlineSpacing,
      );
    });
  });

  group('OneBitTypography named style helpers', () {
    test('oneBitDisplay returns correct properties', () {
      final style = OneBitTypography.oneBitDisplay();
      expect(style.fontSize, OneBitTypography.display);
      expect(style.fontWeight, OneBitTypography.semibold);
      expect(style.letterSpacing, OneBitTypography.displaySpacing);
    });

    test('oneBitBody returns correct properties', () {
      final style = OneBitTypography.oneBitBody();
      expect(style.fontSize, OneBitTypography.body);
      expect(style.fontWeight, OneBitTypography.regular);
    });

    test('oneBitTerminal uses technical family', () {
      final style = OneBitTypography.oneBitTerminal();
      expect(style.fontFamily, OneBitTypography.technicalFamily);
      expect(style.letterSpacing, OneBitTypography.technicalSpacing);
    });

    test('oneBitTitle matches oneBitPageTitle', () {
      final style = OneBitTypography.oneBitTitle();
      expect(style.fontSize, OneBitTypography.pageTitle);
      expect(style.fontWeight, OneBitTypography.semibold);
    });
  });
}
