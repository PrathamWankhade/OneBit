import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Terminal-style panel with a mono background and hairline border.
///
/// [OneBitPanel] renders a dark, code-block-like surface for technical
/// content: console output, diagnostic data, log viewers, and packet
/// inspection. The panel uses [OneBitThemeExtension.monoBackground] for
/// its fill and a subtle border for separation.
///
/// For non-technical grouped content, prefer [OneBitCard].
class OneBitPanel extends StatelessWidget {
  const OneBitPanel({
    required this.child,
    this.padding,
    this.borderRadius,
    this.outlined = true,
    this.title,
    super.key,
  });

  /// Panel body.
  final Widget child;

  /// Internal padding; defaults to [OneBitSpacing.m].
  final EdgeInsetsGeometry? padding;

  /// Corner radius; defaults to [OneBitCardTokens.cornerRadius].
  final double? borderRadius;

  /// Whether to render a visible border (default true).
  final bool outlined;

  /// Optional title rendered above the content in muted label style.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final radius = borderRadius ?? OneBitCardTokens.cornerRadius;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.monoBackground,
        borderRadius: BorderRadius.circular(radius),
        border: outlined ? Border.all(color: colors.border, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OneBitSpacing.m,
                OneBitSpacing.s,
                OneBitSpacing.m,
                0,
              ),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: OneBitTypography.medium,
                ),
              ),
            ),
          Padding(
            padding: padding ?? const EdgeInsets.all(OneBitSpacing.m),
            child: child,
          ),
        ],
      ),
    );
  }
}
