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
      expect(OneBitTypography.title, 20);
      expect(OneBitTypography.sectionTitle, 18);
      expect(OneBitTypography.body, 16);
      expect(OneBitTypography.bodyLarge, 18);
      expect(OneBitTypography.bodySmall, 13);
      expect(OneBitTypography.label, 14);
      expect(OneBitTypography.caption, 12);
      expect(OneBitTypography.overline, 10);
      expect(OneBitTypography.technical, 13);
    });

    test('technical sizes are declared', () {
      expect(OneBitTypography.nodeId, 13);
      expect(OneBitTypography.fingerprint, 12);
      expect(OneBitTypography.packetId, 12);
      expect(OneBitTypography.log, 12);
      expect(OneBitTypography.diagnostic, 11);
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
    final scheme = OneBitColorSchemes.dark();

    test('every style carries the Consolas family', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.fontFamily, OneBitTypography.primaryFamily);
      expect(theme.bodyMedium?.fontFamily, OneBitTypography.primaryFamily);
      expect(theme.labelSmall?.fontFamily, OneBitTypography.primaryFamily);
    });

    test('scale values are honored', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.fontSize, OneBitTypography.display);
      expect(theme.titleLarge?.fontSize, OneBitTypography.title);
      expect(theme.bodyLarge?.fontSize, OneBitTypography.bodyLarge);
      expect(theme.labelSmall?.fontSize, 10);
    });

    test('colors resolve from the scheme', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.displayLarge?.color, scheme.onSurface);
      expect(theme.bodyMedium?.color, scheme.onSurfaceVariant);
    });

    test('overline labels carry tracking', () {
      final theme = OneBitTypography.buildTextTheme(scheme);
      expect(theme.labelSmall?.letterSpacing, OneBitTypography.overlineSpacing);
    });
  });

  group('OneBitTypography.technicalStyle', () {
    test('uses Consolas with a monospace fallback', () {
      final style = OneBitTypography.technicalStyle();
      expect(style.fontFamily, OneBitTypography.technicalFamily);
      expect(style.fontFamilyFallback, OneBitTypography.technicalFallback);
      expect(style.fontSize, OneBitTypography.technical);
    });

    test('overrides are honored', () {
      final style = OneBitTypography.technicalStyle(
        fontSize: 11,
        weight: OneBitTypography.bold,
        color: const Color(0xFFA8A8A8),
      );
      expect(style.fontSize, 11);
      expect(style.fontWeight, OneBitTypography.bold);
      expect(style.color, const Color(0xFFA8A8A8));
    });
  });

  group('OneBitTypography named style helpers', () {
    test('sectionTitleStyle uses sectionTitle size', () {
      final style = OneBitTypography.sectionTitleStyle();
      expect(style.fontSize, OneBitTypography.sectionTitle);
      expect(style.fontWeight, OneBitTypography.semibold);
    });

    test('nodeIdStyle uses nodeId size with technical spacing', () {
      final style = OneBitTypography.nodeIdStyle();
      expect(style.fontSize, OneBitTypography.nodeId);
      expect(style.letterSpacing, OneBitTypography.technicalSpacing);
    });

    test('fingerprintStyle uses fingerprint size', () {
      final style = OneBitTypography.fingerprintStyle();
      expect(style.fontSize, OneBitTypography.fingerprint);
    });

    test('packetIdStyle uses packetId size', () {
      final style = OneBitTypography.packetIdStyle();
      expect(style.fontSize, OneBitTypography.packetId);
    });

    test('logStyle uses log size', () {
      final style = OneBitTypography.logStyle();
      expect(style.fontSize, OneBitTypography.log);
    });

    test('diagnosticStyle uses diagnostic size', () {
      final style = OneBitTypography.diagnosticStyle();
      expect(style.fontSize, OneBitTypography.diagnostic);
    });
  });
}
