import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Tokenized surface container.
///
/// [OneBitCard] is the standard container for grouped content: the theme's
/// card surface with a hairline border. `compact` shrinks padding and radius
/// for dense information rows (e.g. node status).
class OneBitCard extends StatelessWidget {
  const OneBitCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.compact = false,
    this.outlined = false,
    this.padding,
    this.semanticLabel,
    super.key,
  });

  /// Body of the card.
  final Widget child;

  /// Tapping the card (makes it a "button" surface with ripple).
  final VoidCallback? onTap;

  /// Long-press action.
  final VoidCallback? onLongPress;

  /// Use compact padding/radius (info cards, status rows).
  final bool compact;

  /// Render a stronger outlined surface instead of the tinted one.
  final bool outlined;

  /// Optional explicit padding; overrides token defaults.
  final EdgeInsetsGeometry? padding;

  /// Semantic label for screen readers when the card is tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    final decoration = BoxDecoration(
      color: outlined ? scheme.surfaceContainerHighest : colors.primarySurface,
      borderRadius: BorderRadius.circular(
        compact
            ? OneBitCardTokens.cornerRadiusCompact
            : OneBitCardTokens.cornerRadius,
      ),
      border: Border.all(color: scheme.outlineVariant, width: 1),
    );

    final effectivePadding =
        padding ??
        (compact
            ? OneBitCardTokens.contentPaddingCompact
            : OneBitCardTokens.contentPadding);

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      enabled: onTap != null || onLongPress != null,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              compact
                  ? OneBitCardTokens.cornerRadiusCompact
                  : OneBitCardTokens.cornerRadius,
            ),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(padding: effectivePadding, child: child),
          ),
        ),
      ),
    );
  }
}
