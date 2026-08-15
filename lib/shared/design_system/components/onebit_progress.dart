import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Direction of a [OneBitTransferIndicator] or `OneBitTransferCard`.
enum OneBitTransferDirection {
  /// Data leaving the device.
  upload,

  /// Data arriving at the device.
  download;

  /// Direction glyph.
  IconData get icon => switch (this) {
    OneBitTransferDirection.upload => OneBitIcons.upload,
    OneBitTransferDirection.download => OneBitIcons.download,
  };

  /// Default (English) label for accessibility; callers localize.
  String get defaultLabel => switch (this) {
    OneBitTransferDirection.upload => 'Uploading',
    OneBitTransferDirection.download => 'Downloading',
  };
}

/// Tokenized determinate/indeterminate progress bar.
///
/// [value] is a 0..1 fraction; `null` renders an indeterminate bar. The bar
/// announces its percentage and label to screen readers and is a
/// [Semantics] live region so updates are announced.
class OneBitLinearProgress extends StatelessWidget {
  const OneBitLinearProgress({
    this.value,
    this.semanticsLabel,
    this.height = 4,
    super.key,
  });

  /// Determinate fraction in 0..1; `null` for indeterminate.
  final double? value;

  /// Screen reader label; defaults to a percentage announcement.
  final String? semanticsLabel;

  /// Bar thickness in dp.
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = value == null ? null : (value! * 100).round();

    return Semantics(
      container: true,
      label: semanticsLabel,
      value: value == null ? null : '$percent percent',
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OneBitRadius.pill),
        child: SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            color: scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

/// Transfer progress strip: direction, determinate bar, byte counters and an
/// optional cancel action.
///
/// Presentation-only — counters are preformatted strings. Semantics combine
/// the direction label, percentage and byte counters for TalkBack.
class OneBitTransferIndicator extends StatelessWidget {
  const OneBitTransferIndicator({
    required this.direction,
    this.progress,
    this.transferred,
    this.total,
    this.rate,
    this.onCancel,
    this.semanticsLabel,
    super.key,
  });

  /// Transfer direction ("Uploading"/"Downloading" default).
  final OneBitTransferDirection direction;

  /// Determinate 0..1 fraction; `null` for indeterminate.
  final double? progress;

  /// Preformatted transferred bytes (e.g. "12.4 MB").
  final String? transferred;

  /// Preformatted total size (e.g. "20 MB").
  final String? total;

  /// Preformatted throughput (e.g. "1.2 MB/s").
  final String? rate;

  /// Cancels the transfer; `null` hides the action.
  final VoidCallback? onCancel;

  /// Screen reader label; defaults to
  /// "`<direction> <transferred>` of `<total>`".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = progress == null ? null : (progress! * 100).round();

    final directionLabel =
        semanticsLabel ??
        '${direction.defaultLabel}'
            '${transferred == null ? '' : ' $transferred'}'
            '${total == null ? '' : ' of $total'}';

    return Semantics(
      container: true,
      label: directionLabel,
      value: percent == null ? null : '$percent percent',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                direction.icon,
                size: OneBitIconSize.s,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OneBitSpacing.s),
              Expanded(
                child: Text(
                  direction.defaultLabel,
                  style: textTheme.labelMedium,
                ),
              ),
              if (onCancel != null)
                OneBitIconButton(
                  icon: OneBitIcons.close,
                  size: OneBitIconSize.s,
                  onPressed: onCancel,
                  tooltip: 'Cancel',
                ),
            ],
          ),
          const SizedBox(height: OneBitSpacing.s),
          OneBitLinearProgress(value: progress, height: 4),
          const SizedBox(height: OneBitSpacing.xs),
          Row(
            children: [
              if (transferred != null)
                Text(
                  '$transferred${total == null ? '' : ' / $total'}',
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (rate != null)
                Text(
                  rate!,
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
