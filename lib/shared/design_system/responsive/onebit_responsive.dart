import 'package:flutter/material.dart';

/// Responsive breakpoints for OneBit.
///
/// The product targets phones, large phones, foldables, tablets and
/// landscape layouts without device-specific dimensions: every layout
/// decision is derived from the available width at build time.
///
/// Widths follow Material 3 window classes:
/// * **Compact** (<600dp) — phones in portrait.
/// * **Medium** (600–839dp) — large phones, foldables unfolded, small
///   tablets and phones in landscape.
/// * **Expanded** (≥840dp) — tablets, desktop-style windows.
abstract final class OneBitBreakpoints {
  static const double compactMaxWidth = 599;
  static const double mediumMaxWidth = 839;

  const OneBitBreakpoints._();
}

/// Width class of the current viewport.
enum OneBitBreakpoint {
  /// Phones in portrait.
  compact,

  /// Large phones, foldables unfolded, small tablets, landscape phones.
  medium,

  /// Tablets and desktop windows.
  expanded;

  /// Whether this class uses a bottom navigation bar vs. a side rail.
  bool get usesBottomNavigation => this == OneBitBreakpoint.compact;
}

/// Builds a layout from the ambient viewport width.
class OneBitResponsiveLayout extends StatelessWidget {
  const OneBitResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  /// Builder for [OneBitBreakpoint.compact] viewports.
  final WidgetBuilder compact;

  /// Builder for [OneBitBreakpoint.medium] viewports; falls back to
  /// [compact] when `null`.
  final WidgetBuilder? medium;

  /// Builder for [OneBitBreakpoint.expanded] viewports; falls back to
  /// [medium] then [compact] when `null`.
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return switch (context.breakpoint) {
      OneBitBreakpoint.compact => compact(context),
      OneBitBreakpoint.medium => (medium ?? compact)(context),
      OneBitBreakpoint.expanded => (expanded ?? medium ?? compact)(context),
    };
  }
}

/// Responsive helpers mounted on [BuildContext].
extension OneBitResponsiveContextX on BuildContext {
  /// The [OneBitBreakpoint] for the ambient viewport width.
  OneBitBreakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width <= OneBitBreakpoints.compactMaxWidth) {
      return OneBitBreakpoint.compact;
    }
    if (width <= OneBitBreakpoints.mediumMaxWidth) {
      return OneBitBreakpoint.medium;
    }
    return OneBitBreakpoint.expanded;
  }

  /// True on phones in portrait.
  bool get isCompact => breakpoint == OneBitBreakpoint.compact;

  /// True on anything at least medium-sized (large phone, tablet,
  /// foldable-unfolded, landscape).
  bool get isTablet => breakpoint != OneBitBreakpoint.compact;

  /// True on tablet/desktop-sized viewports (≥840dp).
  bool get isExpanded => breakpoint == OneBitBreakpoint.expanded;
}
