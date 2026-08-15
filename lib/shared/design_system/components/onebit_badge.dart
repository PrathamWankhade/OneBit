import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Count badge (unread counts, pending items).
///
/// Renders nothing when [count] is `null` or zero (unless [showZero]), so
/// parents can slot it unconditionally. Counts above 99 render as "99+".
class OneBitBadge extends StatelessWidget {
  const OneBitBadge({
    this.count,
    this.showZero = false,
    this.semanticsLabel,
    super.key,
  });

  /// The number to display; `null` hides the badge.
  final int? count;

  /// Keep the badge visible for a count of zero.
  final bool showZero;

  /// Semantic label; defaults to "`count` unread items".
  final String? semanticsLabel;

  bool get _visible => count != null && (count! > 0 || showZero);

  String get _display => count! > 99 ? '99+' : '${count!}';

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: semanticsLabel ?? '$_display unread items',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitSpacing.xs + 2,
          vertical: 1,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ExcludeSemantics(
          child: Text(
            _display,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onInverseSurface,
              fontSize: OneBitTypography.caption,
              fontWeight: OneBitTypography.bold,
            ),
          ),
        ),
      ),
    );
  }
}
