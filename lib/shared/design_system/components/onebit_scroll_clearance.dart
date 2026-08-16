import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Provides the correct bottom padding for scrollable content that sits
/// behind a floating bottom navigation bar.
///
/// The clearance accounts for:
/// * Navigation bar height
/// * Navigation bar bottom margin
/// * Device safe-area bottom inset
/// * Comfortable reading space above the navigation
///
/// Usage:
/// ```dart
/// ListView(
///   padding: EdgeInsets.fromLTRB(
///     OneBitSpacing.m,
///     OneBitSpacing.m,
///     OneBitSpacing.m,
///     OneBitScrollClearance.bottom(context),
///   ),
///   children: [...],
/// )
/// ```
abstract final class OneBitScrollClearance {
  /// Returns the total bottom clearance needed for scrollable content
  /// to sit above the floating navigation bar.
  ///
  /// This value is dynamic and accounts for the device's safe-area inset.
  static double bottom(BuildContext context) {
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    return OneBitFloatingNavigationTokens.barHeight +
        OneBitFloatingNavigationTokens.barBottomMargin +
        safeAreaBottom +
        OneBitFloatingNavigationTokens.readingGap;
  }

  /// Returns an [EdgeInsets] with the given existing padding preserved,
  /// but with the bottom value replaced by the scroll clearance.
  ///
  /// Use this when a widget already has padding that must be kept.
  static EdgeInsets preserve({
    required BuildContext context,
    EdgeInsets existing = EdgeInsets.zero,
  }) {
    return EdgeInsets.only(
      left: existing.left,
      top: existing.top,
      right: existing.right,
      bottom: bottom(context),
    );
  }

  const OneBitScrollClearance._();
}
