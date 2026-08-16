import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/channels/presentation/channels_controller.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_bottom_sheets.dart';
import 'package:onebit/shared/design_system/components/onebit_channel_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_banner.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_state.dart';
import 'package:onebit/shared/design_system/components/onebit_page_header.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/responsive/onebit_responsive.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Channels tab: the live conversation list.
///
/// Renders exclusively from [channelsViewProvider]; every action (archive,
/// pin, mute, mark read) delegates to the controller. Rows compose
/// [OneBitChannelCard] from the summary plus per-channel draft and last
/// message streams.
class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  bool _showArchived = false;
  String? _selectedChannelId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(channelsViewProvider);

    final headerActions = [
      OneBitIconButton(
        icon: OneBitIcons.archive,
        tooltip: _showArchived
            ? l10n.channelsHideArchived
            : l10n.channelsShowArchived,
        onPressed: () => setState(() => _showArchived = !_showArchived),
      ),
      OneBitIconButton(
        icon: OneBitIcons.search,
        tooltip: l10n.channelsSearch,
        onPressed: () => context.go(AppRoutePaths.search),
      ),
      OneBitIconButton(
        icon: OneBitIcons.shellSettings,
        tooltip: l10n.settingsTitle,
        onPressed: () => context.push(AppRoutePaths.settings),
      ),
    ];

    return OneBitScaffold(
      body: _showArchived
          ? _archivedBody(context, ref, view, headerActions)
          : _activeBody(context, ref, view, headerActions),
    );
  }

  Widget _activeBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ChannelsView> view,
    List<Widget> headerActions,
  ) {
    final l10n = context.l10n;
    if (view.hasError) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: view.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.invalidate(channelsViewProvider),
      );
    }
    final value = view.value;
    if (value == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (value.error != null && value.summaries.isEmpty) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: value.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.read(channelsViewProvider.notifier).retry(),
      );
    }
    if (value.offline && value.isEmpty) {
      return OneBitOfflineState(
        title: l10n.channelsOfflineTitle,
        message: l10n.channelsOfflineMessage,
      );
    }
    if (value.isEmpty) {
      return OneBitEmptyState(
        icon: OneBitIcons.shellChannels,
        title: l10n.channelsEmpty,
        message: l10n.channelsEmptyMessage,
      );
    }
    return Column(
      children: [
        OneBitPageHeader.status(
          title: _showArchived ? l10n.channelsArchivedTitle : l10n.channelsTitle,
          status: '${value.summaries.length}',
          actions: headerActions,
        ),
        if (value.offline)
          OneBitOfflineBanner(
            title: l10n.channelsOfflineTitle,
            message: l10n.channelsOfflineMessage,
          ),
        Expanded(
          child: context.isTablet
              ? _TabletChannelList(
                  summaries: value.summaries,
                  selectedId: _selectedChannelId,
                  onSelect: (id) => setState(() => _selectedChannelId = id),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    OneBitSpacing.m,
                    OneBitSpacing.m,
                    OneBitSpacing.m,
                    OneBitScrollClearance.bottom(context),
                  ),
                  itemCount: value.summaries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OneBitSpacing.s),
                  itemBuilder: (context, index) => _ChannelRow(
                    summary: value.summaries[index],
                    archivedView: false,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _archivedBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ChannelsView> view,
    List<Widget> headerActions,
  ) {
    final l10n = context.l10n;
    final archivedAsync = ref.watch(archivedConversationSummariesProvider);

    if (archivedAsync.hasError) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: archivedAsync.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.invalidate(archivedConversationSummariesProvider),
      );
    }
    final result = archivedAsync.value;
    if (result == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (result.isErr) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: result.failure.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.invalidate(archivedConversationSummariesProvider),
      );
    }
    final summaries = result.value!.where((s) => s.archived).toList();
    if (summaries.isEmpty) {
      return Column(
        children: [
          OneBitPageHeader.minimal(
            title: l10n.channelsArchivedTitle,
            actions: headerActions,
          ),
          Expanded(
            child: OneBitEmptyState(
              icon: OneBitIcons.archive,
              title: l10n.channelsArchivedEmpty,
              message: l10n.channelsArchivedEmptyMessage,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        OneBitPageHeader.minimal(
          title: l10n.channelsArchivedTitle,
          actions: headerActions,
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              OneBitSpacing.m,
              OneBitSpacing.m,
              OneBitSpacing.m,
              OneBitScrollClearance.bottom(context),
            ),
            itemCount: summaries.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: OneBitSpacing.s),
            itemBuilder: (context, index) =>
                _ChannelRow(summary: summaries[index], archivedView: true),
          ),
        ),
      ],
    );
  }
}

/// One conversation row: summary + draft + last message, wired to actions.
final class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({
    required this.summary,
    required this.archivedView,
    this.selected = false,
    this.onTapOverride,
  });

  final ConversationSummary summary;
  final bool archivedView;
  final bool selected;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localNodeId = ref.watch(localNodeIdProvider);
    final draftAsync = ref.watch(channelDraftProvider(summary.channelId));
    final lastMessageAsync = ref.watch(
      channelLastMessageProvider(summary.channelId),
    );

    final draft = draftAsync.value?.value;
    final hasDraft = draft != null && !draft.isEmpty;
    final lastMessage = lastMessageAsync.value?.value?.firstOrNull;

    final timestamp = hasDraft
        ? (draft.updatedAt ?? draft.createdAt)
        : summary.lastMessageAt;

    return Dismissible(
      key: ValueKey('channel-${summary.channelId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: archivedView
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: OneBitSpacing.xl),
        child: Icon(
          archivedView ? OneBitIcons.unarchive : OneBitIcons.archive,
          color: archivedView
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        if (archivedView) {
          unawaited(_restoreWithUndo(context, ref));
        } else {
          unawaited(_archiveWithUndo(context, ref));
        }
      },
      child: OneBitChannelCard(
        name: summary.title,
        unreadCount: summary.unreadCount,
        pinned: summary.pinned,
        muted: summary.muted,
        draft: hasDraft,
        draftLabel: l10n.channelsDraft,
        lastMessage: hasDraft ? draft.body : lastMessage?.body,
        delivery: deliveryPresetFor(lastMessage, localNodeId),
        timestamp: timestamp == null ? null : clockLabel(timestamp),
        onTap:
            onTapOverride ??
            () {
              unawaited(
                ref
                    .read(channelsViewProvider.notifier)
                    .markRead(summary.channelId),
              );
              context.go(AppRoutePaths.channelOf(summary.channelId));
            },
        onLongPress: () => _showActions(context, ref),
      ),
    );
  }

  Future<void> _archiveWithUndo(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(channelsViewProvider.notifier)
        .archive(summary.channelId);
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.channelsArchived),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => unawaited(
              ref
                  .read(channelsViewProvider.notifier)
                  .restore(summary.channelId),
            ),
          ),
        ),
      );
  }

  Future<void> _restoreWithUndo(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(channelsViewProvider.notifier)
        .restore(summary.channelId);
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.channelsRestored),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => unawaited(
              ref
                  .read(channelsViewProvider.notifier)
                  .archive(summary.channelId),
            ),
          ),
        ),
      );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final action = await showOneBitActionSheet<_ChannelAction>(
      context,
      title: l10n.channelActionsTitle,
      actions: [
        OneBitSheetAction(
          label: summary.pinned ? l10n.channelsUnpin : l10n.channelsPin,
          value: _ChannelAction.togglePinned,
          icon: OneBitIcons.pin,
        ),
        OneBitSheetAction(
          label: summary.muted ? l10n.channelsUnmute : l10n.channelsMute,
          value: _ChannelAction.toggleMuted,
          icon: OneBitIcons.mute,
        ),
        OneBitSheetAction(
          label: l10n.channelsMarkRead,
          value: _ChannelAction.markRead,
          icon: OneBitIcons.markRead,
        ),
        if (!archivedView)
          OneBitSheetAction(
            label: l10n.channelsArchive,
            value: _ChannelAction.archive,
            icon: OneBitIcons.archive,
          ),
        if (archivedView)
          OneBitSheetAction(
            label: l10n.channelsArchive,
            value: _ChannelAction.restore,
            icon: OneBitIcons.unarchive,
          ),
      ],
    );
    if (action == null || !context.mounted) return;

    final controller = ref.read(channelsViewProvider.notifier);
    switch (action) {
      case _ChannelAction.togglePinned:
        await controller.setPinned(summary.channelId, pinned: !summary.pinned);
      case _ChannelAction.toggleMuted:
        await controller.setMuted(summary.channelId, muted: !summary.muted);
      case _ChannelAction.markRead:
        await controller.markRead(summary.channelId);
      case _ChannelAction.archive:
        await _archiveWithUndo(context, ref);
      case _ChannelAction.restore:
        await _restoreWithUndo(context, ref);
    }
  }
}

enum _ChannelAction { togglePinned, toggleMuted, markRead, archive, restore }

/// Tablet-optimized channel list with master-detail layout.
class _TabletChannelList extends StatelessWidget {
  const _TabletChannelList({
    required this.summaries,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ConversationSummary> summaries;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                OneBitSpacing.m,
                OneBitSpacing.m,
                OneBitSpacing.m,
                OneBitScrollClearance.bottom(context),
              ),
              itemCount: summaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: OneBitSpacing.s),
              itemBuilder: (context, index) {
                final summary = summaries[index];
                final isSelected = summary.channelId == selectedId;
                return _ChannelRow(
                  summary: summary,
                  archivedView: false,
                  selected: isSelected,
                  onTapOverride: () => onSelect(summary.channelId),
                );
              },
            ),
          ),
        ),
        Container(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(
          child: selectedId != null
              ? Center(
                  child: Text(
                    context.l10n.channelsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                )
              : OneBitEmptyState(
                  icon: OneBitIcons.shellChannels,
                  title: context.l10n.channelsEmpty,
                  message: context.l10n.channelsEmptyMessage,
                ),
        ),
      ],
    );
  }
}
