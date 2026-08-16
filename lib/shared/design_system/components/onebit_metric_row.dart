import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// A label/value metric row used across health panels, stats panels,
/// settings info rows, and about screens.
///
/// Renders a [Row] with an [Expanded] label on the left and a value on the
/// right. Supports compact (default) and dense spacing, plus technical or
/// numeric value styling.
final class OneBitMetricRow extends StatelessWidget {
  const OneBitMetricRow({
    required this.label,
    required this.value,
    this.valueStyle = OneBitMetricValueStyle.numeric,
    this.dense = false,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String label;
  final String value;

  /// Styling preset for the value text.
  final OneBitMetricValueStyle valueStyle;

  /// When true, uses tighter vertical padding (2dp vs 4dp).
  final bool dense;

  /// How to handle value overflow.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? 2 : OneBitSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: overflow,
              textAlign: TextAlign.end,
              style: valueStyle._resolve(context, scheme),
            ),
          ),
        ],
      ),
    );
  }
}

/// Styling presets for [OneBitMetricRow] values.
enum OneBitMetricValueStyle {
  /// Monospace numeric style — used for signal strength, packet counts, etc.
  numeric,

  /// Technical monospace style at caption size — used for IDs, MAC addresses.
  technical,

  /// Standard body text — used for human-readable values.
  body,
}

extension on OneBitMetricValueStyle {
  TextStyle? _resolve(BuildContext context, ColorScheme scheme) {
    return switch (this) {
      OneBitMetricValueStyle.numeric =>
        OneBitTypography.oneBitNumeric(color: scheme.onSurface),
      OneBitMetricValueStyle.technical =>
        OneBitTypography.technicalStyle(
          fontSize: OneBitTypography.caption,
          color: scheme.onSurface,
        ),
      OneBitMetricValueStyle.body =>
        context.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
    };
  }
}
