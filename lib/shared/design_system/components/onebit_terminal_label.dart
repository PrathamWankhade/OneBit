import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Compact terminal-style label for inline technical values.
///
/// Renders a small, monospace-styled text with muted coloring — ideal for
/// node IDs, packet hashes, timestamps, and other machine-readable tokens
/// that appear inline with other content.
///
/// For full status lines with bracketed prefixes, see [OneBitTerminalLine].
class OneBitTerminalLabel extends StatelessWidget {
  const OneBitTerminalLabel({
    required this.text,
    this.color,
    this.background,
    this.padding,
    this.semanticsLabel,
    super.key,
  });

  /// The label text.
  final String text;

  /// Foreground color; defaults to [OneBitThemeExtension.textMuted].
  final Color? color;

  /// Optional background fill; renders as a rounded rectangle behind the text.
  final Color? background;

  /// Padding when [background] is provided; defaults to compact horizontal padding.
  final EdgeInsetsGeometry? padding;

  /// Optional semantic label for accessibility.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final effectiveColor = color ?? colors.textMuted;

    final textWidget = Text(
      text,
      style: OneBitTypography.technicalStyle(
        fontSize: OneBitTypography.caption,
        color: effectiveColor,
      ),
    );

    if (background == null) {
      return Semantics(label: semanticsLabel ?? text, child: textWidget);
    }

    return Semantics(
      label: semanticsLabel ?? text,
      child: Container(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: OneBitSpacing.s,
              vertical: OneBitSpacing.xs,
            ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OneBitRadius.xs),
        ),
        child: textWidget,
      ),
    );
  }
}
