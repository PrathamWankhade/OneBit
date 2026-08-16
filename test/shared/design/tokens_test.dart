import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/shared/design_system/design_system.dart';

void main() {
  group('OneBitSpacing', () {
    test('exposes the full scale', () {
      expect(OneBitSpacing.xxs, 2);
      expect(OneBitSpacing.xs, 4);
      expect(OneBitSpacing.sm, 8);
      expect(OneBitSpacing.md, 12);
      expect(OneBitSpacing.lg, 16);
      expect(OneBitSpacing.xl, 20);
      expect(OneBitSpacing.xxl, 24);
      expect(OneBitSpacing.xxxl, 32);
      expect(OneBitSpacing.xxxxl, 40);
      expect(OneBitSpacing.xxxxxl, 48);
      expect(OneBitSpacing.xxxxxxl, 56);
      expect(OneBitSpacing.xxxxxxxl, 64);
    });

    test('backward-compatible aliases work', () {
      expect(OneBitSpacing.s, OneBitSpacing.sm);
      expect(OneBitSpacing.m, OneBitSpacing.lg);
    });

    test('semantic aliases', () {
      expect(OneBitSpacing.page, OneBitSpacing.lg);
      expect(OneBitSpacing.section, OneBitSpacing.xxxl);
    });

    test('border width tokens', () {
      expect(OneBitSpacing.borderWidth, 1);
      expect(OneBitSpacing.borderWidthStrong, 2);
    });
  });

  group('OneBitRadius', () {
    test('radius scale is ordered', () {
      expect(OneBitRadius.xs, 4);
      expect(OneBitRadius.sm, 8);
      expect(OneBitRadius.md, 12);
      expect(OneBitRadius.lg, 16);
      expect(OneBitRadius.xl, 24);
      expect(OneBitRadius.xxl, 28);
      expect(OneBitRadius.xxxl, 32);
    });

    test('pill and circular exceed every fixed radius', () {
      expect(OneBitRadius.pill, greaterThan(OneBitRadius.xxxl));
      expect(OneBitRadius.circular, greaterThan(OneBitRadius.pill));
    });
  });

  group('OneBitShapeTokens', () {
    test('every surface family is tokenized', () {
      expect(OneBitShapeTokens.cardRadius, OneBitRadius.lg);
      expect(OneBitShapeTokens.buttonRadius, OneBitRadius.sm);
      expect(OneBitShapeTokens.inputRadius, OneBitRadius.md);
      expect(OneBitShapeTokens.dialogRadius, OneBitRadius.xl);
      expect(OneBitShapeTokens.bottomSheetRadius, OneBitRadius.xl);
      expect(OneBitShapeTokens.chipRadius, OneBitRadius.pill);
    });
  });

  group('OneBitElevation', () {
    test('levels are ordered', () {
      expect(OneBitElevation.none, const BoxShadow());
      expect(OneBitElevation.level1.blurRadius, 8);
      expect(OneBitElevation.level2.blurRadius, 16);
      expect(OneBitElevation.level3.blurRadius, 24);
      expect(OneBitElevation.level4.blurRadius, 32);
      expect(OneBitElevation.navigation.blurRadius, 16);
    });
  });

  group('OneBitMotion', () {
    test('durations are ordered', () {
      expect(OneBitMotion.fastest.inMilliseconds, 75);
      expect(OneBitMotion.fast.inMilliseconds, 150);
      expect(OneBitMotion.medium.inMilliseconds, 250);
      expect(OneBitMotion.slow.inMilliseconds, 350);
      expect(OneBitMotion.verySlow.inMilliseconds, 600);
      expect(OneBitMotion.opening.inMilliseconds, 1400);
    });

    test('extended durations', () {
      expect(OneBitMotion.pulse.inMilliseconds, 1200);
      expect(OneBitMotion.shimmer.inMilliseconds, 1500);
      expect(OneBitMotion.statusPulse.inMilliseconds, 2000);
    });

    test('snackbar durations', () {
      expect(OneBitMotion.snackbar.inSeconds, 4);
      expect(OneBitMotion.snackbarExtended.inSeconds, 6);
    });

    test('curves are declared', () {
      expect(OneBitMotion.standard, Curves.easeInOutCubic);
      expect(OneBitMotion.emphasized, Curves.easeOutCubic);
      expect(OneBitMotion.decelerate, Curves.easeOut);
      expect(OneBitMotion.accelerate, Curves.easeIn);
      expect(OneBitMotion.linear, Curves.linear);
    });
  });

  group('OneBitButtonTokens', () {
    test('heights are declared', () {
      expect(OneBitButtonTokens.heightSmall, 40);
      expect(OneBitButtonTokens.heightMedium, 48);
      expect(OneBitButtonTokens.heightLarge, 56);
    });

    test('corner radius matches shape tokens', () {
      expect(OneBitButtonTokens.cornerRadius, OneBitRadius.sm);
    });
  });

  group('OneBitInputTokens', () {
    test('field height is 48', () {
      expect(OneBitInputTokens.fieldHeight, 48);
    });

    test('border widths are tokenized', () {
      expect(OneBitInputTokens.borderWidth, 1);
      expect(OneBitInputTokens.errorBorderWidth, 2);
    });
  });

  group('OneBitCardTokens', () {
    test('corner radii are tokenized', () {
      expect(OneBitCardTokens.cornerRadius, OneBitRadius.lg);
      expect(OneBitCardTokens.cornerRadiusCompact, OneBitRadius.md);
    });
  });

  group('OneBitIconSize', () {
    test('scale is ordered', () {
      expect(OneBitIconSize.xs, 16);
      expect(OneBitIconSize.s, 20);
      expect(OneBitIconSize.m, 24);
      expect(OneBitIconSize.l, 28);
      expect(OneBitIconSize.xl, 32);
      expect(OneBitIconSize.feature, 56);
    });
  });

  group('OneBitStatusTokens', () {
    test('chip height is 28', () {
      expect(OneBitStatusTokens.chipHeight, 28);
    });

    test('dot size is 8', () {
      expect(OneBitStatusTokens.dotSize, 8);
    });
  });
}
