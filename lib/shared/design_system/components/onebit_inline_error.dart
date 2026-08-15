import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Compact inline error row for forms and lists.
///
/// Composes with [OneBitButtonSize.small] actions; the message is read to
/// screen readers once per change (live region).
class OneBitInlineError extends StatelessWidget {
  const OneBitInlineError({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Error message; callers localize.
  final String message;

  /// Optional single action (usually "Retry").
  final String? actionLabel;

  /// Action callback; ignored without [actionLabel].
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(OneBitIcons.error, size: OneBitIconSize.s, color: scheme.error),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: OneBitSpacing.m),
            OneBitButton(
              label: actionLabel!,
              variant: OneBitButtonVariant.text,
              size: OneBitButtonSize.small,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
