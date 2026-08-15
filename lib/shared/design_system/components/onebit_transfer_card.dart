import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_progress.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Media transfer summary card.
///
/// Presentation-only: bytes are preformatted strings and [progress] is a
/// plain 0..1 value (or `null` for indeterminate). The card never touches
/// transfer logic.
class OneBitTransferCard extends StatelessWidget {
  const OneBitTransferCard({
    required this.title,
    required this.direction,
    this.progress,
    this.transferred,
    this.total,
    this.rate,
    this.status,
    this.onTap,
    super.key,
  });

  /// What is being transferred (file name, message bundle, …).
  final String title;

  /// Transfer direction label ("Uploading"/"Downloading" default).
  final OneBitTransferDirection direction;

  /// Determinate progress in 0..1; `null` renders an indeterminate bar.
  final double? progress;

  /// Preformatted transferred bytes (e.g. "12.4 MB").
  final String? transferred;

  /// Preformatted total size (e.g. "20 MB").
  final String? total;

  /// Preformatted throughput (e.g. "1.2 MB/s").
  final String? rate;

  /// Transfer status chip; `null` hides it.
  final OneBitStatusPreset? status;

  /// Tap action; `null` renders the card non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return OneBitCard(
      onTap: onTap,
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
                  title,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: OneBitSpacing.s),
                OneBitStatusChip.preset(status!),
              ],
            ],
          ),
          const SizedBox(height: OneBitSpacing.m),
          OneBitLinearProgress(value: progress),
          const SizedBox(height: OneBitSpacing.s),
          Row(
            children: [
              if (transferred != null)
                Text(
                  transferred!,
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (transferred != null && total != null)
                Text(
                  ' / $total',
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
