import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Visual variants of [OneBitButton].
///
/// Primary actions use solid fills. Secondary actions may use surface + border.
/// All variants maintain clear foreground/background contrast.
enum OneBitButtonVariant {
  /// Solid fill — highest emphasis. Primary actions.
  ///
  /// Light: near-black background, white text.
  /// Dark: white background, black text.
  primary,

  /// Surface + border — medium emphasis. Secondary actions.
  ///
  /// Light: white surface, dark border, dark text.
  /// Dark: dark surface, gray border, light text.
  secondary,

  /// Tonal fill — medium-low emphasis. Tertiary actions.
  ///
  /// Uses container colors with contrasting text.
  tonal,

  /// Text-only — low emphasis. Inline actions.
  text,

  /// Solid error fill — destructive actions (delete, remove, etc.).
  destructive,
}

/// Predefined sizes of [OneBitButton].
enum OneBitButtonSize {
  /// 40dp — compact UI, secondary actions in tight spaces.
  small,

  /// 48dp — default, meets WCAG touch target minimum.
  medium,

  /// 56dp — prominent permission/confirmation actions.
  large;

  double get height => switch (this) {
    OneBitButtonSize.small => OneBitButtonTokens.heightSmall,
    OneBitButtonSize.medium => OneBitButtonTokens.heightMedium,
    OneBitButtonSize.large => OneBitButtonTokens.heightLarge,
  };
}

/// Solid, intentional button control.
///
/// Use everywhere instead of raw `FilledButton` so the button language stays
/// consistent. Primary actions use solid fills with clear contrast. All colors
/// resolve dynamically from the current theme — never hardcoded.
///
/// ## Design principles
///
/// * **Buttons look like buttons** — solid backgrounds, clear contrast.
/// * **No invisible text** — foreground/background contrast is always ≥ 4.5:1.
/// * **Pressed state** — surface darkens/lightens slightly, no size change.
/// * **Disabled state** — reduced contrast but still readable.
/// * **Consolas** — monospace identity, 15px, weight 500.
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

    final Widget content = loading
        ? Semantics(
            label: '$label loading',
            liveRegion: true,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _spinnerColor(scheme),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: OneBitButtonTokens.iconGap),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: ['monospace'],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

    final Widget button = switch (variant) {
      OneBitButtonVariant.primary => _buildPrimary(scheme, content),
      OneBitButtonVariant.secondary => _buildSecondary(scheme, content),
      OneBitButtonVariant.tonal => _buildTonal(scheme, content),
      OneBitButtonVariant.text => _buildText(scheme, content),
      OneBitButtonVariant.destructive => _buildDestructive(scheme, content),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height),
      child: button,
    );
  }

  Color _spinnerColor(ColorScheme scheme) => switch (variant) {
    OneBitButtonVariant.text || OneBitButtonVariant.secondary => scheme.primary,
    _ => scheme.onPrimary,
  };

  // ─── Primary: solid background, clear contrast ────────────────────────

  Widget _buildPrimary(ColorScheme scheme, Widget content) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitButtonTokens.horizontalPadding,
          vertical: OneBitButtonTokens.verticalPadding,
        ),
      ),
      onPressed: _enabled ? onPressed : null,
      child: content,
    );
  }

  // ─── Secondary: surface + subtle border ───────────────────────────────

  Widget _buildSecondary(ColorScheme scheme, Widget content) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(
          color: _enabled
              ? scheme.outline
              : scheme.onSurface.withValues(alpha: 0.12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitButtonTokens.horizontalPadding,
          vertical: OneBitButtonTokens.verticalPadding,
        ),
      ),
      onPressed: _enabled ? onPressed : null,
      child: content,
    );
  }

  // ─── Tonal: container fill, medium-low emphasis ───────────────────────

  Widget _buildTonal(ColorScheme scheme, Widget content) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        foregroundColor: scheme.onSecondaryContainer,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitButtonTokens.horizontalPadding,
          vertical: OneBitButtonTokens.verticalPadding,
        ),
      ),
      onPressed: _enabled ? onPressed : null,
      child: content,
    );
  }

  // ─── Text: no surface, inline emphasis ────────────────────────────────

  Widget _buildText(ColorScheme scheme, Widget content) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitButtonTokens.horizontalPadding,
          vertical: OneBitButtonTokens.verticalPadding,
        ),
      ),
      onPressed: _enabled ? onPressed : null,
      child: content,
    );
  }

  // ─── Destructive: error fill for dangerous actions ────────────────────

  Widget _buildDestructive(ColorScheme scheme, Widget content) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneBitButtonTokens.cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitButtonTokens.horizontalPadding,
          vertical: OneBitButtonTokens.verticalPadding,
        ),
      ),
      onPressed: _enabled ? onPressed : null,
      child: content,
    );
  }
}

/// Outlined secondary button — composition over [OneBitButtonVariant.secondary].
///
/// Tighter call-site semantics for navigation and confirmation actions.
class OneBitOutlinedButton extends StatelessWidget {
  const OneBitOutlinedButton({
    required this.label,
    required this.onPressed,
    this.size = OneBitButtonSize.medium,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final OneBitButtonSize size;
  final IconData? icon;
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
