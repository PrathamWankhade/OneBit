import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Icon/selectable action of a OneBit action or selection sheet.
@immutable
class OneBitSheetAction<T> {
  const OneBitSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.destructive = false,
    this.enabled = true,
    this.subtitle,
  });

  /// Visible label; callers localize.
  final String label;

  /// Value returned by the sheet when the action is chosen.
  final T value;

  /// Optional leading glyph.
  final IconData? icon;

  /// Renders the row in the error color.
  final bool destructive;

  /// Disabled rows are dimmed and not tappable.
  final bool enabled;

  /// Optional supporting text under the label.
  final String? subtitle;
}

/// Shows the base tokenized bottom sheet and returns the chosen action's
/// value, or `null` when dismissed.
///
/// The base sheet hosts the drag handle, title and list of [actions] as
/// 48dp rows. Use [showOneBitSheetContent] for custom content (filters,
/// details) inside the same surface.
Future<T?> showOneBitActionSheet<T>(
  BuildContext context, {
  required List<OneBitSheetAction<T>> actions,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ActionSheet<T>(title: title, actions: actions),
  );
}

final class _ActionSheet<T> extends StatelessWidget {
  const _ActionSheet({required this.actions, this.title});

  final String? title;
  final List<OneBitSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          0,
          OneBitSpacing.m,
          OneBitSpacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.xs),
                child: Text(title!, style: textTheme.titleMedium),
              ),
            ],
            for (final action in actions)
              OneBitSheetRow<T>(
                action: action,
                onTap: action.enabled
                    ? () => Navigator.of(context).pop(action.value)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the base bottom sheet surface wrapping arbitrary [content]
/// (filters, details, forms). Closes with `Navigator.pop`.
Future<void> showOneBitSheetContent(
  BuildContext context, {
  required Widget content,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          0,
          OneBitSpacing.m,
          OneBitSpacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.xs),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
            content,
          ],
        ),
      ),
    ),
  );
}

/// Shows a single-select sheet: options are pre-ordered rows with a
/// checkmark on the [selected] entry. Returns the chosen value or `null`.
Future<T?> showOneBitSelectionSheet<T>(
  BuildContext context, {
  required List<OneBitSheetAction<T>> options,
  String? title,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          0,
          OneBitSpacing.m,
          OneBitSpacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.xs),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
            for (final option in options)
              OneBitSheetRow<T>(
                action: option,
                onTap: option.enabled
                    ? () => Navigator.of(context).pop(option.value)
                    : null,
                trailing: option.value == selected
                    ? Icon(
                        OneBitIcons.check,
                        size: OneBitIconSize.s,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
}

/// A 48dp tappable label row shared by sheets and menus.
@visibleForTesting
class OneBitSheetRow<T> extends StatelessWidget {
  const OneBitSheetRow({
    required this.action,
    this.trailing,
    this.onTap,
    super.key,
  });

  final OneBitSheetAction<T> action;

  /// Optional trailing glyph rendered on the right (checkmarks, chevrons).
  final Widget? trailing;

  /// Tap callback; `null` renders the row disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = action.destructive ? scheme.error : scheme.onSurface;

    return Opacity(
      opacity: onTap == null ? 0.38 : 1.0,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OneBitSpacing.s,
              vertical: OneBitSpacing.s,
            ),
            child: Row(
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: OneBitIconSize.s, color: color),
                  const SizedBox(width: OneBitSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: textTheme.labelLarge?.copyWith(color: color),
                      ),
                      if (action.subtitle != null)
                        Text(action.subtitle!, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: OneBitSpacing.m),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
