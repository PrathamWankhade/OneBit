import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// One message row of a channel timeline.
///
/// Presentation-only: body, alignment and every footer string arrive from
/// the caller; no message state is read or derived here. Outbound bubbles
/// align right, inbound left.
class OneBitMessageBubble extends StatelessWidget {
  const OneBitMessageBubble({
    required this.body,
    required this.isOutbound,
    this.senderName,
    this.timeText,
    this.status,
    this.statusLabel,
    this.readLabel,
    this.pinned = false,
    super.key,
  });

  /// Message body.
  final String body;

  /// Renders the bubble on the right (outbound) or left (inbound).
  final bool isOutbound;

  /// Optional sender label (group channels).
  final String? senderName;

  /// Preformatted time text (e.g. "14:32"); `null` hides it.
  final String? timeText;

  /// Status chip of the message; `null` hides it.
  final OneBitStatusPreset? status;

  /// Overrides the status chip's label (localized).
  final String? statusLabel;

  /// Preformatted read-receipt text (e.g. "Read 14:32"); `null` hides it.
  final String? readLabel;

  /// Renders the pin glyph when true.
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bubbleColor = isOutbound
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: OneBitSpacing.m,
        vertical: OneBitSpacing.s,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderName != null && !isOutbound) ...[
            Text(
              senderName!,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontFamily: OneBitTypography.technicalFamily,
                fontFamilyFallback: OneBitTypography.technicalFallback,
              ),
            ),
            const SizedBox(height: OneBitSpacing.xs),
          ],
          SelectableText(body, style: textTheme.bodyLarge),
          const SizedBox(height: OneBitSpacing.xs),
          Row(
            children: [
              if (pinned) ...[
                Icon(OneBitIcons.pin, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: OneBitSpacing.xs),
              ],
              if (status != null)
                OneBitStatusChip.preset(status!, label: statusLabel),
              const Spacer(),
              if (readLabel != null && isOutbound)
                Text(
                  readLabel!,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: OneBitTypography.medium,
                  ),
                ),
              if (readLabel != null && timeText != null && isOutbound)
                const SizedBox(width: OneBitSpacing.s),
              if (timeText != null)
                Text(
                  timeText!,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}
