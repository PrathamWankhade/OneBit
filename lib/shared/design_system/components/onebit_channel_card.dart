import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Channel summary card.
///
/// Presentation-only: unread counts, pin/mute flags and delivery state arrive
/// as plain data. Messaging logic never touches this widget.
class OneBitChannelCard extends StatelessWidget {
  const OneBitChannelCard({
    required this.name,
    this.unreadCount,
    this.pinned = false,
    this.muted = false,
    this.draft = false,
    this.draftLabel,
    this.lastMessage,
    this.timestamp,
    this.delivery,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// Channel display name.
  final String name;

  /// Unread count; `null` or zero hides the badge.
  final int? unreadCount;

  /// Renders the pin glyph when true.
  final bool pinned;

  /// Renders the mute glyph when true.
  final bool muted;

  /// Renders a draft chip when true.
  final bool draft;

  /// Label of the draft chip; callers localize.
  final String? draftLabel;

  /// Preview of the last message; `null` hides the line.
  final String? lastMessage;

  /// Preformatted timestamp (e.g. "14:32"); `null` hides it.
  final String? timestamp;

  /// Delivery status chip of the last message; `null` hides it.
  final OneBitStatusPreset? delivery;

  /// Tap action; `null` renders the card non-interactive.
  final VoidCallback? onTap;

  /// Long-press action; `null` disables it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return OneBitCard(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: 'Channel $name',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pinned) ...[
                Icon(
                  OneBitIcons.pin,
                  size: OneBitIconSize.s,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.xs),
              ],
              if (muted) ...[
                Icon(
                  OneBitIcons.mute,
                  size: OneBitIconSize.s,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.xs),
              ],
              Expanded(
                child: Text(
                  name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unreadCount != null && unreadCount! > 0) ...[
                const SizedBox(width: OneBitSpacing.s),
                OneBitBadge(count: unreadCount),
              ],
            ],
          ),
          if (lastMessage != null) ...[
            const SizedBox(height: OneBitSpacing.xs),
            Text(
              lastMessage!,
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: OneBitSpacing.s),
          Row(
            children: [
              if (draft) ...[
                OneBitStatusChip(
                  label: draftLabel ?? 'Draft',
                  tone: OneBitStatusTone.info,
                ),
                const SizedBox(width: OneBitSpacing.s),
              ],
              if (delivery != null)
                OneBitStatusChip.preset(delivery!)
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (timestamp != null)
                Text(
                  timestamp!,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
