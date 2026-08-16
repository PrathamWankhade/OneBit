import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Component tokens. Each group defines the geometric surface of one Material
/// 3 component so widgets stay free of magic numbers.

abstract final class OneBitButtonTokens {
  /// Small button height — 40dp for compact UI (secondary actions).
  static const double heightSmall = 40;

  /// Medium button height — 48dp (default, meets WCAG touch target).
  static const double heightMedium = 48;

  /// Large button height — 56dp (prominent permission/confirmation actions).
  static const double heightLarge = 56;

  /// Horizontal padding — generous for comfortable tap targets.
  static const double horizontalPadding = 24;

  /// Vertical padding — computed to fill height.
  static const double verticalPadding = 12;

  /// Corner radius — 8dp (sm scale, consistent with inputs).
  static const double cornerRadius = OneBitRadius.sm;

  /// Gap between icon and label.
  static const double iconGap = OneBitSpacing.sm;

  /// Label font size — 15px (between bodySecondary and body).
  static const double labelFontSize = 15;

  /// Label font weight — w500 (medium, not bold).
  static const double labelFontWeight = 500;

  const OneBitButtonTokens._();
}

abstract final class OneBitInputTokens {
  static const double fillRadius = OneBitRadius.md;
  static const double fieldHeight = 48;

  static const double horizontalPadding = OneBitSpacing.m;
  static const double verticalPadding = OneBitSpacing.sm;

  /// Border width for outlined input.
  static const double borderWidth = OneBitSpacing.borderWidth;

  /// Error border width for emphasized feedback.
  static const double errorBorderWidth = OneBitSpacing.borderWidthStrong;

  const OneBitInputTokens._();
}

abstract final class OneBitCardTokens {
  static const double cornerRadius = OneBitRadius.lg;
  static const double cornerRadiusCompact = OneBitRadius.md;

  static const EdgeInsets contentPadding = EdgeInsets.all(OneBitSpacing.m);
  static const EdgeInsets contentPaddingCompact = EdgeInsets.all(
    OneBitSpacing.sm,
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

/// Tokens for the floating bottom navigation bar.
///
/// These dimensions match the rendered layout of [FloatingBottomNavigation]
/// and must stay in sync with any changes to that widget.
abstract final class OneBitFloatingNavigationTokens {
  /// Icon size inside each nav item (24dp).
  static const double itemIconSize = 24;

  /// Total height of the capsule (60dp).
  static const double capsuleHeight = 60;

  /// Capsule corner radius (28dp, ~half the height for a pill shape).
  static const double capsuleRadius = 28;

  /// Inner padding between capsule edge and item edge (8dp).
  static const double itemPadding = 8;

  /// Selection pill padding around the icon (8dp each side → 40dp pill).
  static const double pillPadding = 8;

  /// Bottom margin around the floating bar (16dp).
  static const double barBottomMargin = 16;

  /// Horizontal margin around the floating bar (18dp).
  static const double barHorizontalMargin = 18;

  /// Additional comfortable reading space above the navigation bar (32dp).
  static const double readingGap = 32;

  /// Total rendered height including bottom margin.
  static const double barHeight = capsuleHeight + barBottomMargin;

  const OneBitFloatingNavigationTokens._();
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
    horizontal: OneBitSpacing.sm + OneBitSpacing.xs,
    vertical: OneBitSpacing.sm,
  );

  const OneBitStatusTokens._();
}
