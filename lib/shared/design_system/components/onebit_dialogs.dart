import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Dialog emphasis, controlling the leading glyph.
enum OneBitDialogVariant {
  /// Neutral information.
  information,

  /// Positive confirmation context.
  confirmation,

  /// Caution.
  warning,

  /// Failure.
  error,
}

/// Immutable action of a [showOneBitDialog] result.
@immutable
class OneBitDialogAction<T> {
  const OneBitDialogAction({required this.label, required this.value});

  /// Visible label; callers localize.
  final String label;

  /// Value returned by the dialog when the action is chosen.
  final T value;
}

/// Shows a tokenized OneBit dialog returning the chosen action's value, or
/// `null` when dismissed.
///
/// Variants: use [OneBitDialogs.confirm], [.warn], [.error] and [.info] for
/// the boolean confirmation pattern, or pass [actions] directly for N-way
/// choices.
Future<T?> showOneBitDialog<T>(
  BuildContext context, {
  required String title,
  required List<OneBitDialogAction<T>> actions,
  String? message,
  OneBitDialogVariant variant = OneBitDialogVariant.information,
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (context) => OneBitDialog(
      title: title,
      message: message,
      variant: variant,
      actions: actions,
    ),
  );
}

/// Preset boolean-confirmation dialog helpers.
///
/// Each returns `true`/`false`; `onConfirm`/label overrides must be
/// localized by callers.
abstract final class OneBitDialogs {
  const OneBitDialogs._();

  /// Ask before a neutral or positive action.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    VoidCallback? onConfirm,
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      variant: OneBitDialogVariant.confirmation,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    );
  }

  /// Ask before a destructive action.
  static Future<bool> destructive(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Delete',
    VoidCallback? onConfirm,
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      variant: OneBitDialogVariant.error,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    );
  }

  /// Present a failure.
  static Future<bool> error(
    BuildContext context, {
    required String title,
    String? message,
    String dismissLabel = 'Dismiss',
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      variant: OneBitDialogVariant.error,
      confirmLabel: dismissLabel,
    );
  }

  /// Present a caution.
  static Future<bool> warn(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Continue',
    VoidCallback? onConfirm,
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      variant: OneBitDialogVariant.warning,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    );
  }

  /// Present information.
  static Future<bool> info(
    BuildContext context, {
    required String title,
    String? message,
    String dismissLabel = 'Dismiss',
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      variant: OneBitDialogVariant.information,
      confirmLabel: dismissLabel,
    );
  }

  static Future<bool> _ask(
    BuildContext context, {
    required String title,
    required OneBitDialogVariant variant,
    required String confirmLabel,
    String? message,
    VoidCallback? onConfirm,
  }) async {
    final confirmed = await showOneBitDialog<bool>(
      context,
      title: title,
      message: message,
      variant: variant,
      actions: [
        const OneBitDialogAction(label: 'Cancel', value: false),
        OneBitDialogAction(label: confirmLabel, value: true),
      ],
    );
    if (confirmed == true) onConfirm?.call();
    return confirmed ?? false;
  }
}

/// The dialog surface bound to the theme's dialog tokens.
class OneBitDialog<T> extends StatelessWidget {
  const OneBitDialog({
    required this.title,
    required this.actions,
    this.message,
    this.variant = OneBitDialogVariant.information,
    super.key,
  });

  final String title;
  final String? message;
  final OneBitDialogVariant variant;
  final List<OneBitDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    final (glyph, color) = switch (variant) {
      OneBitDialogVariant.information => (OneBitIcons.info, colors.info),
      OneBitDialogVariant.confirmation => (OneBitIcons.check, colors.success),
      OneBitDialogVariant.warning => (OneBitIcons.warning, colors.warning),
      OneBitDialogVariant.error => (OneBitIcons.error, scheme.error),
    };

    return AlertDialog(
      title: Row(
        children: [
          Icon(glyph, size: OneBitIconSize.s, color: color),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(child: Text(title, style: textTheme.titleLarge)),
        ],
      ),
      content: message == null
          ? null
          : Text(message!, style: textTheme.bodyMedium),
      actions: [
        for (final action in actions)
          OneBitButton(
            label: action.label,
            variant:
                variant == OneBitDialogVariant.error && action == actions.last
                ? OneBitButtonVariant.destructive
                : OneBitButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(action.value),
          ),
      ],
    );
  }
}
