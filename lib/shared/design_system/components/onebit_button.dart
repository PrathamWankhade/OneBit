import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Visual variants of [OneBitButton].
enum OneBitButtonVariant {
  /// Filled, highest emphasis.
  primary,

  /// Outlined, medium emphasis.
  secondary,

  /// Filled tonal, medium-low emphasis.
  tonal,

  /// Text-only, low emphasis.
  text,

  /// Filled error-colored, destructive actions.
  destructive,
}

/// Predefined sizes of [OneBitButton].
enum OneBitButtonSize {
  small,
  medium,
  large;

  double get height => switch (this) {
    OneBitButtonSize.small => OneBitButtonTokens.heightSmall,
    OneBitButtonSize.medium => OneBitButtonTokens.heightMedium,
    OneBitButtonSize.large => OneBitButtonTokens.heightLarge,
  };
}

/// Tokenized Material 3 button.
///
/// Use everywhere instead of raw `FilledButton` so the button language stays
/// consistent and component tokens remain the only source of geometry.
///
/// The height is a **minimum**: the button grows with text scaling instead
/// of clipping, preserving legibility under large accessibility fonts.
class OneBitButton extends StatelessWidget {
  const OneBitButton({
    required this.label,
    required this.onPressed,
    this.variant = OneBitButtonVariant.primary,
    this.size = OneBitButtonSize.medium,
    this.icon,
    this.loading = false,
    super.key,
  });

  /// Button label.
  final String label;

  /// Callback; `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Visual variant.
  final OneBitButtonVariant variant;

  /// Geometric size.
  final OneBitButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// When true the button shows a spinner and ignores taps.
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: OneBitButtonTokens.labelFontSize,
    );

    final Widget content = loading
        ? Semantics(
            label: '$label loading',
            liveRegion: true,
            child: SizedBox(
              width: OneBitButtonTokens.heightSmall,
              height: OneBitButtonTokens.heightSmall,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: switch (variant) {
                  OneBitButtonVariant.text ||
                  OneBitButtonVariant.secondary => scheme.primary,
                  _ => scheme.onPrimary,
                },
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: OneBitButtonTokens.heightMedium - 4),
                const SizedBox(width: OneBitButtonTokens.iconGap),
              ],
              Text(label, style: labelStyle),
            ],
          );

    final Widget button = switch (variant) {
      OneBitButtonVariant.primary => FilledButton(
        onPressed: _enabled ? onPressed : null,
        child: content,
      ),
      OneBitButtonVariant.secondary => OutlinedButton(
        onPressed: _enabled ? onPressed : null,
        child: content,
      ),
      OneBitButtonVariant.tonal => FilledButton.tonal(
        onPressed: _enabled ? onPressed : null,
        child: content,
      ),
      OneBitButtonVariant.text => TextButton(
        onPressed: _enabled ? onPressed : null,
        child: content,
      ),
      OneBitButtonVariant.destructive => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        onPressed: _enabled ? onPressed : null,
        child: content,
      ),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height),
      child: button,
    );
  }
}

/// Outlined medium-emphasis button.
///
/// Composition over the [OneBitButtonVariant.secondary] variant — identical
/// tokens, tighter call-site semantics.
class OneBitOutlinedButton extends StatelessWidget {
  const OneBitOutlinedButton({
    required this.label,
    required this.onPressed,
    this.size = OneBitButtonSize.medium,
    this.icon,
    this.loading = false,
    super.key,
  });

  /// Button label.
  final String label;

  /// Callback; `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Geometric size.
  final OneBitButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// When true the button shows a spinner and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OneBitButton(
      label: label,
      onPressed: onPressed,
      size: size,
      icon: icon,
      loading: loading,
      variant: OneBitButtonVariant.secondary,
    );
  }
}
