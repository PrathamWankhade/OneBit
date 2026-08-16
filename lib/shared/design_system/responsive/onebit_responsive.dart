import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

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

  /// Maximum content width on expanded viewports to prevent giant cards.
  static const double maxContentWidth = 720;

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

/// Responsive horizontal margin tokens.
///
/// Returns appropriate horizontal padding based on viewport width:
/// * Compact: 16dp
/// * Medium: 20dp
/// * Expanded: 24dp (centered content region)
abstract final class OneBitResponsiveMargin {
  /// Horizontal margin for compact viewports (phones).
  static const double compact = OneBitSpacing.lg;

  /// Horizontal margin for medium viewports (large phones, foldables).
  static const double medium = OneBitSpacing.xl;

  /// Horizontal margin for expanded viewports (tablets).
  static const double expanded = OneBitSpacing.xxl;

  const OneBitResponsiveMargin._();
}

/// A widget that constrains content width on large screens and centers it.
///
/// On compact/medium viewports, the child fills available width.
/// On expanded viewports, content is constrained to [maxWidth] and centered
/// to prevent giant cards and text on tablets.
class OneBitConstrainedContent extends StatelessWidget {
  const OneBitConstrainedContent({
    required this.child,
    this.maxWidth = OneBitBreakpoints.maxContentWidth,
    this.padding,
    super.key,
  });

  /// The child widget to constrain.
  final Widget child;

  /// Maximum width on expanded viewports.
  final double maxWidth;

  /// Optional padding applied on all sides.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isExpanded = context.isExpanded;

    if (!isExpanded && padding == null) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: isExpanded
            ? BoxConstraints(maxWidth: maxWidth)
            : const BoxConstraints.expand(),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
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

  /// Responsive horizontal margin based on current breakpoint.
  double get responsiveMargin => switch (breakpoint) {
    OneBitBreakpoint.compact => OneBitResponsiveMargin.compact,
    OneBitBreakpoint.medium => OneBitResponsiveMargin.medium,
    OneBitBreakpoint.expanded => OneBitResponsiveMargin.expanded,
  };
}
