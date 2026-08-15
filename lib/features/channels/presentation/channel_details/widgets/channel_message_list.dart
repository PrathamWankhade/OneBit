import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/channels/presentation/channel_details_controller.dart';
import 'package:onebit/features/channels/presentation/channel_details/widgets/message_widgets.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_banner.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Body of the channel details screen: pinned messages, timeline, and load
/// older button.
final class ChannelMessageList extends ConsumerWidget {
  const ChannelMessageList({
    required this.channelId,
    required this.view,
    required this.selected,
    required this.selectionMode,
    required this.onToggleSelected,
    required this.onLongPressMessage,
    super.key,
  });

  final String channelId;
  final ChannelDetailsView? view;
  final Set<String> selected;
  final bool selectionMode;
  final void Function(Message) onToggleSelected;
  final void Function(Message) onLongPressMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (view == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (view!.error != null && view!.timeline.isEmpty) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: view!.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () =>
            ref.read(channelDetailsViewProvider(channelId).notifier).retry(),
      );
    }
    if (!view!.loaded) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (view!.channel == null) {
      return OneBitErrorState(
        message: l10n.channelNotFound,
        retryLabel: l10n.commonRetry,
        onRetry: () =>
            ref.read(channelDetailsViewProvider(channelId).notifier).retry(),
      );
    }

    final timeline = view!.timeline;
    if (timeline.isEmpty) {
      return OneBitEmptyState(
        icon: OneBitIcons.shellChannels,
        title: l10n.channelNoMessages,
      );
    }

    final pinnedIds = view!.pinned.map((m) => m.messageId).toSet();
    final localNodeId = ref.watch(localNodeIdProvider);
    final byId = {for (final m in timeline) m.messageId: m};
    final loadOlderCount = view!.hasMore ? 1 : 0;

    return Column(
      children: [
        if (view!.offline)
          OneBitOfflineBanner(
            title: l10n.channelsOfflineTitle,
            message: l10n.channelsOfflineMessage,
          ),
        if (view!.pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OneBitSpacing.m),
            child: OneBitSectionHeader(title: l10n.channelPinnedSection),
          ),
          for (final pinned in view!.pinned)
            OneBitListItem(
              leading: OneBitIcons.pin,
              title: pinned.body,
              onTap: () {},
            ),
        ],
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(OneBitSpacing.m),
            itemCount: timeline.length + loadOlderCount,
            itemBuilder: (context, index) {
              if (view!.hasMore && index == 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: OneBitSpacing.s,
                    ),
                    child: OneBitOutlinedButton(
                      label: l10n.channelLoadOlder,
                      icon: OneBitIcons.download,
                      loading: view!.loadingOlder,
                      onPressed: view!.loadingOlder
                          ? null
                          : () => unawaited(
                              ref
                                  .read(
                                    channelDetailsViewProvider(
                                      channelId,
                                    ).notifier,
                                  )
                                  .loadOlder(),
                            ),
                    ),
                  ),
                );
              }
              final messageIndex =
                  timeline.length - 1 - (index - loadOlderCount);
              final message = timeline[messageIndex];
              return MessageRow(
                message: message,
                isOutbound: message.sender == localNodeId,
                localNodeId: localNodeId,
                replyPreview: byId[message.replyTo],
                pinned: pinnedIds.contains(message.messageId),
                selected: selected.contains(message.messageId),
                selectionMode: selectionMode,
                onTap: selectionMode ? () => onToggleSelected(message) : null,
                onLongPress: () => onLongPressMessage(message),
              );
            },
          ),
        ),
      ],
    );
  }
}
