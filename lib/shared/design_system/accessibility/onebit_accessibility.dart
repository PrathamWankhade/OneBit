import 'package:flutter/material.dart';

/// Accessibility foundation for the whole application.
///
/// Accessibility behavior is provided here once, then composed by components
/// and screens — it must never be re-implemented ad-hoc inside individual
/// widgets.
///
/// The foundation guarantees the product builds for:
/// * TalkBack / screen readers — every interactive element carries a
///   semantic label; decorative glyphs are excluded.
/// * Dynamic text — components grow with text scaling instead of clipping.
/// * High contrast — semantic colors are read from `ColorScheme` / the theme
///   extension and pass WCAG AA contrast in both identities.
/// * Reduced motion — durations route through `OneBitMotion.resolve`.
/// * 48dp minimum interactive targets — enforced by [OneBitTapTarget] and
///   component minimum sizes.
abstract final class OneBitAccessibility {
  /// Minimum interactive target per Google Material guidance (48dp).
  static const double minInteractiveSize = 48;

  /// Minimum visual size for touch targets that are not primary controls.
  static const double minVisualSize = 24;

  const OneBitAccessibility._();
}

/// Wraps [child] in a guaranteed ≥48dp hit target.
///
/// Small visual elements (row chevrons, inline icons) that carry an action
/// must be wrapped in [OneBitTapTarget] so TalkBack users and finger touch
/// receive the full target while the visual stays compact.
class OneBitTapTarget extends StatelessWidget {
  const OneBitTapTarget({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
    super.key,
  });

  /// The (compact) visual content.
  final Widget child;

  /// Tap action; disables the target when `null`.
  final VoidCallback? onTap;

  /// Optional long-press action.
  final VoidCallback? onLongPress;

  /// Semantic label for screen readers; defaults to [child]'s own labels.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onLongPress != null;
    return Semantics(
      button: enabled && onTap != null,
      label: semanticsLabel,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: OneBitAccessibility.minInteractiveSize,
            minHeight: OneBitAccessibility.minInteractiveSize,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Semantic helpers shared by components.
abstract final class OneBitSemantics {
  const OneBitSemantics._();

  /// Wraps a decorative glyph so screen readers skip it while surrounding
  /// semantics stay intact.
  static Widget decorative(Widget child) => ExcludeSemantics(child: child);
}
