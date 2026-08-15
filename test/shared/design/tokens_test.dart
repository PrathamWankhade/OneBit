import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/design_system.dart';

void main() {
  group('OneBitSpacing', () {
    test('exposes the full 8dp scale', () {
      expect(OneBitSpacing.xs, 4);
      expect(OneBitSpacing.s, 8);
      expect(OneBitSpacing.md, 12);
      expect(OneBitSpacing.m, 16);
      expect(OneBitSpacing.l, 20);
      expect(OneBitSpacing.xl, 24);
      expect(OneBitSpacing.xxl, 32);
      expect(OneBitSpacing.xxxl, 40);
      expect(OneBitSpacing.xxxxl, 48);
    });

    test('page and section composite from the scale', () {
      expect(OneBitSpacing.page, OneBitSpacing.m);
      expect(OneBitSpacing.section, OneBitSpacing.xxl);
    });
  });

  group('OneBitRadius', () {
    test('radius scale is 4-based and ordered', () {
      expect(OneBitRadius.xs, 4);
      expect(OneBitRadius.sm, 8);
      expect(OneBitRadius.md, 12);
      expect(OneBitRadius.lg, 16);
      expect(OneBitRadius.xl, 24);
    });

    test('pill and circular exceed every fixed radius', () {
      expect(OneBitRadius.pill, greaterThan(OneBitRadius.xl));
      expect(OneBitRadius.circular, greaterThan(OneBitRadius.pill));
    });
  });

  group('OneBitShapeTokens', () {
    test('every surface family is tokenized', () {
      expect(OneBitShapeTokens.cardRadius, OneBitRadius.lg);
      expect(OneBitShapeTokens.buttonRadius, OneBitRadius.md);
      expect(OneBitShapeTokens.inputRadius, OneBitRadius.md);
      expect(OneBitShapeTokens.dialogRadius, OneBitRadius.xl);
      expect(OneBitShapeTokens.bottomSheetRadius, OneBitRadius.xl);
      expect(OneBitShapeTokens.chipRadius, OneBitRadius.pill);
    });
  });

  group('OneBitElevation', () {
    test('none is a zero-blur flat shadow', () {
      expect(OneBitElevation.none.blurRadius, 0);
      expect(OneBitElevation.none.offset, Offset.zero);
    });

    test('levels are ordered by intensity', () {
      expect(
        OneBitElevation.level1.blurRadius,
        lessThan(OneBitElevation.level2.blurRadius),
      );
      expect(
        OneBitElevation.level2.blurRadius,
        lessThan(OneBitElevation.level3.blurRadius),
      );
    });
  });

  group('OneBitMotion', () {
    test('durations stay inside the 150–250ms normal window', () {
      expect(OneBitMotion.fast, const Duration(milliseconds: 150));
      expect(OneBitMotion.medium, const Duration(milliseconds: 250));
    });

    test('curves are declared centrally', () {
      expect(OneBitMotion.standard, Curves.easeInOutCubic);
      expect(OneBitMotion.emphasized, Curves.easeOutCubic);
      expect(OneBitMotion.linearCurve, Curves.linear);
    });
  });

  group('OneBitIconSize', () {
    test('icons resolve to discrete sizes', () {
      expect(OneBitIconSize.xs, 16);
      expect(OneBitIconSize.s, 20);
      expect(OneBitIconSize.m, 24);
      expect(OneBitIconSize.l, 28);
      expect(OneBitIconSize.xl, 32);
      expect(OneBitIconSize.feature, 56);
    });
  });

  group('OneBitButtonTokens', () {
    test('heights are declared and ordered', () {
      expect(OneBitButtonTokens.heightSmall, 32);
      expect(OneBitButtonTokens.heightMedium, 40);
      expect(OneBitButtonTokens.heightLarge, 48);
      expect(
        OneBitButtonTokens.heightSmall,
        lessThan(OneBitButtonTokens.heightMedium),
      );
      expect(
        OneBitButtonTokens.heightMedium,
        lessThan(OneBitButtonTokens.heightLarge),
      );
    });

    test('cornerRadius matches design spec', () {
      expect(OneBitButtonTokens.cornerRadius, OneBitRadius.md);
    });
  });

  group('OneBitInputTokens', () {
    test('field height meets 48dp minimum', () {
      expect(OneBitInputTokens.fieldHeight, 48);
    });

    test('border widths are declared', () {
      expect(OneBitInputTokens.borderWidth, 1);
      expect(OneBitInputTokens.errorBorderWidth, 2);
    });
  });

  group('OneBitCardTokens', () {
    test('radii are declared', () {
      expect(OneBitCardTokens.cornerRadius, OneBitRadius.lg);
      expect(OneBitCardTokens.cornerRadiusCompact, OneBitRadius.md);
    });
  });

  group('OneBitNavigationTokens', () {
    test('bar height is 72', () {
      expect(OneBitNavigationTokens.barHeight, 72);
    });
  });

  group('OneBitStatusTokens', () {
    test('chip height and dot size are declared', () {
      expect(OneBitStatusTokens.chipHeight, 28);
      expect(OneBitStatusTokens.dotSize, 8);
    });
  });

  group('OneBitIcons', () {
    test('shell destinations are declared', () {
      expect(OneBitIcons.shellHome, isA<IconData>());
      expect(OneBitIcons.shellMesh, isA<IconData>());
      expect(OneBitIcons.shellChannels, isA<IconData>());
      expect(OneBitIcons.shellSettings, isA<IconData>());
    });
  });
}
