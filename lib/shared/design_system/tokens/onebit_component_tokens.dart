import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Component tokens. Each group defines the geometric surface of one Material
/// 3 component so widgets stay free of magic numbers.

abstract final class OneBitButtonTokens {
  static const double heightSmall = 32;
  static const double heightMedium = 40;
  static const double heightLarge = 48;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: OneBitSpacing.l,
    vertical: OneBitSpacing.s,
  );

  static const double cornerRadius = OneBitRadius.md;
  static const double iconGap = OneBitSpacing.xs;

  /// Label styling for button text.
  static const double labelFontSize = OneBitTypography.label;

  const OneBitButtonTokens._();
}

abstract final class OneBitInputTokens {
  static const double fillRadius = OneBitRadius.md;
  static const double fieldHeight = 48;

  static const double horizontalPadding = OneBitSpacing.m;
  static const double verticalPadding = OneBitSpacing.s;

  /// Border width for outlined input.
  static const double borderWidth = 1;

  /// Error border width for emphasized feedback.
  static const double errorBorderWidth = 2;

  const OneBitInputTokens._();
}

abstract final class OneBitCardTokens {
  static const double cornerRadius = OneBitRadius.lg;
  static const double cornerRadiusCompact = OneBitRadius.md;

  static const EdgeInsets contentPadding = EdgeInsets.all(OneBitSpacing.m);
  static const EdgeInsets contentPaddingCompact = EdgeInsets.all(
    OneBitSpacing.s,
  );

  const OneBitCardTokens._();
}

abstract final class OneBitNavigationTokens {
  /// Standard Material navigation-bar height.
  static const double barHeight = 72;

  static const double indicatorRadius = OneBitRadius.pill;
  static const double labelFontSize = OneBitTypography.caption;

  static const double iconSize = OneBitIconSize.m;

  const OneBitNavigationTokens._();
}

/// Centralized corner radii for every surface family.
///
/// Widgets must resolve surface radii through these aliases (or the theme
/// component themes) instead of inventing values.
abstract final class OneBitShapeTokens {
  static const double cardRadius = OneBitCardTokens.cornerRadius;
  static const double buttonRadius = OneBitButtonTokens.cornerRadius;
  static const double inputRadius = OneBitInputTokens.fillRadius;
  static const double dialogRadius = OneBitRadius.xl;
  static const double bottomSheetRadius = OneBitRadius.xl;
  static const double chipRadius = OneBitRadius.pill;

  const OneBitShapeTokens._();
}

abstract final class OneBitIconSize {
  static const double xs = 16;
  static const double s = 20;
  static const double m = 24;
  static const double l = 28;
  static const double xl = 32;

  /// Hero size for state presentations (empty/error/loading hero glyphs).
  static const double feature = 56;

  const OneBitIconSize._();
}

abstract final class OneBitStatusTokens {
  /// Minimum height of a status chip (grows with text scaling).
  static const double chipHeight = 28;

  /// Status dot diameter.
  static const double dotSize = 8;

  /// Padding inside status chips.
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: OneBitSpacing.s + OneBitSpacing.xs,
    vertical: OneBitSpacing.s,
  );

  const OneBitStatusTokens._();
}
