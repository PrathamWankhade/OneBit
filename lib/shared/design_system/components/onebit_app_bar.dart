import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// OneBit-styled app bar with consistent terminal-inspired typography.
///
/// Wraps [AppBar] with tokenized geometry and the monospace font family.
/// Use this instead of raw [AppBar] to keep the design language uniform.
///
/// For screens inside the [StatefulShellRoute] navigation, the shell's
/// [AppBar] is managed by [AppShell] — use this bar for full-screen
/// flows (launch, onboarding, deep-link destinations).
class OneBitAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OneBitAppBar({
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.elevation = 0,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  /// Title text; rendered in [titleMedium] style.
  final String? title;

  /// Custom title widget; overrides [title] when provided.
  final Widget? titleWidget;

  /// Leading widget (e.g. back button).
  final Widget? leading;

  /// Whether to automatically show a back button when there's a route below.
  final bool automaticallyImplyLeading;

  /// Trailing action widgets.
  final List<Widget>? actions;

  /// Optional bottom widget (e.g. tab bar).
  final PreferredSizeWidget? bottom;

  /// AppBar elevation; defaults to 0 (flat, terminal-style).
  final double elevation;

  /// Whether to center the title; defaults to true.
  final bool centerTitle;

  /// Background color override; defaults to scaffold background.
  final Color? backgroundColor;

  /// Foreground color override; defaults to scheme.onSurface.
  final Color? foregroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;

    final effectiveTitle =
        titleWidget ??
        (title != null
            ? Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foregroundColor ?? colors.textPrimary,
                  fontWeight: OneBitTypography.semibold,
                ),
              )
            : null);

    return AppBar(
      title: effectiveTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: elevation,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? colors.primarySurface,
      foregroundColor: foregroundColor ?? colors.textPrimary,
      titleSpacing: OneBitSpacing.m,
      toolbarHeight: kToolbarHeight,
    );
  }
}
