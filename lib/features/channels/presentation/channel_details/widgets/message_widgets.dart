import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/channels/presentation/channels_controller.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/shared/design_system/components/onebit_message_bubble.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/formatting/onebit_formatters.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Attachments of one timeline message (for the bubble chips row).
final channelMessageAttachmentsProvider = FutureProvider.autoDispose
    .family<Result<List<Attachment>>, String>(
      (ref, messageId) =>
          ref.watch(mediaEngineProvider).listByMessage(messageId),
    );

/// Single message row inside the channel timeline.
final class MessageRow extends ConsumerWidget {
  const MessageRow({
    required this.message,
    required this.isOutbound,
    required this.localNodeId,
    required this.replyPreview,
    required this.pinned,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final Message message;
  final bool isOutbound;
  final String localNodeId;
  final Message? replyPreview;
  final bool pinned;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final attachments = ref.watch(
      channelMessageAttachmentsProvider(message.messageId),
    );
    final attachmentList = attachments.value?.value ?? const <Attachment>[];

    final chips = [
      for (final attachment in attachmentList)
        AttachmentChip(attachment: attachment),
    ];

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: OneBitSpacing.xs),
        padding: selected
            ? const EdgeInsets.all(OneBitSpacing.xs)
            : EdgeInsets.zero,
        decoration: selected
            ? BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OneBitMessageBubble(
              body: message.body,
              isOutbound: isOutbound,
              senderName: isOutbound
                  ? null
                  : message.sender == localNodeId
                  ? l10n.commonYou
                  : message.sender,
              timeText: clockLabel(message.timestamp),
              status: isOutbound
                  ? deliveryPresetFor(message, localNodeId)
                  : null,
              readLabel: isOutbound && message.readAt != null
                  ? '${l10n.channelReadLabel} ${clockLabel(message.readAt!)}'
                  : null,
              pinned: pinned,
              statusLabel: switch (message.status) {
                MessageStatus.delivered => l10n.commonDelivered,
                MessageStatus.verified => l10n.commonVerified,
                MessageStatus.read => l10n.commonRead,
                _ => null,
              },
            ),
            if (replyPreview != null)
              Padding(
                padding: const EdgeInsets.only(top: OneBitSpacing.xs),
                child: ReplyPreview(
                  isOutbound: isOutbound,
                  senderName: replyPreview!.sender == localNodeId
                      ? l10n.commonYou
                      : replyPreview!.sender,
                  body: replyPreview!.body,
                ),
              ),
            if (message.forwarded || message.edited)
              Padding(
                padding: const EdgeInsets.only(top: OneBitSpacing.xs),
                child: Text(
                  [
                    if (message.forwarded) l10n.messageForwardedLabel,
                    if (message.edited) l10n.messageEditedLabel,
                  ].join(' · '),
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: OneBitSpacing.xs),
                child: Wrap(
                  spacing: OneBitSpacing.xs,
                  runSpacing: OneBitSpacing.xs,
                  children: chips,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Inline reply preview shown under a message bubble.
final class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    required this.isOutbound,
    required this.senderName,
    required this.body,
    super.key,
  });

  final bool isOutbound;
  final String senderName;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.65,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OneBitSpacing.s,
          vertical: OneBitSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: scheme.primary,
                weight: OneBitTypography.semibold,
              ),
            ),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small chip showing an attachment name and size.
final class AttachmentChip extends StatelessWidget {
  const AttachmentChip({required this.attachment, super.key});

  final Attachment attachment;

  IconData get _icon => switch (attachment.metadata.category) {
    MediaCategory.image => OneBitIcons.image,
    MediaCategory.video => OneBitIcons.video,
    MediaCategory.audio => OneBitIcons.audio,
    MediaCategory.voice => OneBitIcons.voiceNote,
    MediaCategory.document => OneBitIcons.document,
    MediaCategory.archive => OneBitIcons.archiveFile,
    MediaCategory.binary => OneBitIcons.binaryFile,
    MediaCategory.custom => OneBitIcons.file,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OneBitSpacing.s,
        vertical: OneBitSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(OneBitRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: OneBitSpacing.xs),
          Text(
            attachment.metadata.fileName,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: OneBitSpacing.xs),
          Text(
            OneBitFormatters.bytes(attachment.metadata.sizeBytes),
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
