import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/channels/presentation/channels_controller.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_bottom_sheets.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

enum MessageAction { reply, forward, copy, edit, retry, select, delete }

enum ChannelAction { markRead, togglePinned, toggleMuted, archive, info }

/// Shows the message action sheet and returns the selected action.
Future<MessageAction?> showMessageActionSheet(
  BuildContext context, {
  required bool isOutbound,
  required bool canEdit,
  required bool canRetry,
}) {
  final l10n = context.l10n;
  return showOneBitActionSheet<MessageAction>(
    context,
    title: l10n.channelActionsTitle,
    actions: [
      OneBitSheetAction(
        label: l10n.messageReply,
        value: MessageAction.reply,
        icon: OneBitIcons.reply,
      ),
      OneBitSheetAction(
        label: l10n.messageForward,
        value: MessageAction.forward,
        icon: OneBitIcons.forward,
      ),
      OneBitSheetAction(
        label: l10n.messageCopy,
        value: MessageAction.copy,
        icon: OneBitIcons.copy,
      ),
      if (canEdit)
        OneBitSheetAction(
          label: l10n.messageEdit,
          value: MessageAction.edit,
          icon: OneBitIcons.edit,
        ),
      if (canRetry)
        OneBitSheetAction(
          label: l10n.messageRetry,
          value: MessageAction.retry,
          icon: OneBitIcons.retry,
        ),
      OneBitSheetAction(
        label: l10n.messageSelect,
        value: MessageAction.select,
        icon: OneBitIcons.selectAll,
      ),
      if (isOutbound)
        OneBitSheetAction(
          label: l10n.messageDelete,
          value: MessageAction.delete,
          icon: OneBitIcons.delete,
          destructive: true,
        ),
    ],
  );
}

/// Shows the channel action sheet and returns the selected action.
Future<ChannelAction?> showChannelActionSheet(BuildContext context) {
  final l10n = context.l10n;
  return showOneBitActionSheet<ChannelAction>(
    context,
    title: l10n.channelActionsTitle,
    actions: [
      OneBitSheetAction(
        label: l10n.channelsMarkRead,
        value: ChannelAction.markRead,
        icon: OneBitIcons.markRead,
      ),
      OneBitSheetAction(
        label: l10n.channelsArchive,
        value: ChannelAction.archive,
        icon: OneBitIcons.archive,
      ),
      OneBitSheetAction(
        label: l10n.channelInfoTitle,
        value: ChannelAction.info,
        icon: OneBitIcons.info,
      ),
    ],
  );
}

/// Shows the channel info sheet.
Future<void> showChannelInfo(BuildContext context, Channel channel) async {
  final l10n = context.l10n;
  final createdAt = channel.createdAt;
  await showOneBitSheetContent(
    context,
    title: l10n.channelInfoTitle,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OneBitListItem(
          title: channel.title,
          leading: OneBitIcons.shellChannels,
        ),
        if (channel.peer != null)
          OneBitListItem(
            title: channel.peer!,
            subtitle: l10n.channelPeerLabel,
            leading: OneBitIcons.node,
          ),
        if (createdAt != null)
          OneBitListItem(
            title: '${createdAt.year}-${createdAt.month}-${createdAt.day}',
            subtitle: l10n.channelCreatedLabel,
            leading: OneBitIcons.schedule,
          ),
        const SizedBox(height: OneBitSpacing.s),
        OneBitTechnicalCard(
          title: l10n.channelIdLabel,
          content: channel.channelId,
        ),
      ],
    ),
  );
}

/// Forwards a message to another channel.
Future<void> forwardMessage(
  BuildContext context,
  WidgetRef ref,
  Message message,
  String currentChannelId,
) async {
  final l10n = context.l10n;
  final summaries = ref.read(channelsViewProvider).value?.summaries ?? const [];
  final options = summaries
      .where((summary) => summary.channelId != currentChannelId)
      .map(
        (summary) => OneBitSheetAction<String>(
          label: summary.title,
          value: summary.channelId,
          icon: OneBitIcons.shellChannels,
        ),
      )
      .toList();
  if (options.isEmpty) return;

  final target = await showOneBitSelectionSheet<String>(
    context,
    title: l10n.forwardToTitle,
    options: options,
  );
  if (target == null || !context.mounted) return;

  final result = await ref
      .read(messagingEngineProvider)
      .forward(message.messageId, target);
  if (result.isErr && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.forwardFailed)));
  }
}

/// Confirms and deletes a message.
Future<void> confirmDeleteMessage(
  BuildContext context,
  WidgetRef ref,
  String messageId,
) async {
  final l10n = context.l10n;
  final confirmed = await OneBitDialogs.destructive(
    context,
    title: l10n.messageDelete,
    confirmLabel: l10n.commonDelete,
  );
  if (!confirmed || !context.mounted) return;
  final result = await ref.read(messagingEngineProvider).delete(messageId);
  if (result.isErr && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.commonError)));
  }
}
