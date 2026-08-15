import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/channels/presentation/channel_details/widgets/channel_actions.dart';
import 'package:onebit/features/channels/presentation/channel_details/widgets/channel_message_list.dart';
import 'package:onebit/features/channels/presentation/channel_details_controller.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Channel details: identity, pinned messages, paginated timeline and the
/// conversation composer (text, replies, edits, forwarding, selection).
///
/// Attachments and voice notes are authored in the compose surface; the
/// conversation renders any attachment chips a message carries.
class ChannelDetailsScreen extends ConsumerStatefulWidget {
  const ChannelDetailsScreen({
    required this.channelId,
    this.messageId,
    super.key,
  });

  /// Channel identifier from the route (see [AppRoutePaths.channel]).
  final String channelId;

  /// Optional message anchor (see [AppRoutePaths.message]).
  final String? messageId;

  @override
  ConsumerState<ChannelDetailsScreen> createState() =>
      _ChannelDetailsScreenState();
}

final class _ChannelDetailsScreenState
    extends ConsumerState<ChannelDetailsScreen> {
  bool _markReadScheduled = false;
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  Message? _replyTarget;
  Message? _editTarget;
  bool _sending = false;
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(channelDetailsViewProvider(widget.channelId)).value;

    _scheduleMarkRead(view);

    final body = Column(
      children: [
        Expanded(
          child: ChannelMessageList(
            channelId: widget.channelId,
            view: view,
            selected: _selected,
            selectionMode: _selectionMode,
            onToggleSelected: _toggleSelected,
            onLongPressMessage: _showMessageActions,
          ),
        ),
        if (view?.channel != null) _composerBar(),
      ],
    );

    return OneBitScaffold(
      appBar: _selectionMode
          ? AppBar(
              title: Text(l10n.selectionDelete),
              actions: [
                OneBitIconButton(
                  icon: OneBitIcons.selectAll,
                  tooltip: l10n.selectionSelectAll,
                  onPressed: () => _toggleSelectAll(view),
                ),
                OneBitIconButton(
                  icon: OneBitIcons.copy,
                  tooltip: l10n.selectionCopy,
                  onPressed: _selected.isEmpty ? null : _copySelection,
                ),
                OneBitIconButton(
                  icon: OneBitIcons.delete,
                  tooltip: l10n.selectionDelete,
                  onPressed: _selected.isEmpty ? null : _deleteSelection,
                ),
                OneBitIconButton(
                  icon: OneBitIcons.close,
                  tooltip: l10n.commonCancel,
                  onPressed: _exitSelection,
                ),
              ],
            )
          : AppBar(
              title: Text(
                view?.channel?.title ?? widget.channelId,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                OneBitIconButton(
                  icon: OneBitIcons.search,
                  tooltip: l10n.channelsSearch,
                  onPressed: () => context.go(AppRoutePaths.search),
                ),
                OneBitIconButton(
                  icon: OneBitIcons.moreVert,
                  tooltip: l10n.channelActionsTitle,
                  onPressed: () => _showActions(view),
                ),
              ],
            ),
      body: widget.messageId == null
          ? body
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OneBitSpacing.m,
                    OneBitSpacing.m,
                    OneBitSpacing.m,
                    0,
                  ),
                  child: OneBitTechnicalCard(
                    title: l10n.messageIdLabel,
                    content: widget.messageId!,
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Composer
  // ---------------------------------------------------------------------

  Widget _composerBar() {
    final l10n = context.l10n;
    final engine = ref.watch(messagingEngineProvider);
    final localNodeId = ref.watch(localNodeIdProvider);

    final replyBody = _replyTarget != null
        ? l10n.channelReplyTo(
            _replyTarget!.sender == localNodeId
                ? l10n.commonYou
                : _replyTarget!.sender,
          )
        : null;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTarget != null || _editTarget != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OneBitSpacing.m,
                OneBitSpacing.xs,
                OneBitSpacing.m,
                0,
              ),
              child: OneBitCard(
                child: Row(
                  children: [
                    Icon(
                      _editTarget != null
                          ? OneBitIcons.edit
                          : OneBitIcons.reply,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: OneBitSpacing.s),
                    Expanded(
                      child: Text(
                        _editTarget != null
                            ? '${l10n.messageEdit}: ${_editTarget!.body}'
                            : replyBody!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OneBitTypography.technicalStyle(
                          fontSize: OneBitTypography.caption,
                        ),
                      ),
                    ),
                    OneBitIconButton(
                      icon: OneBitIcons.close,
                      size: OneBitIconSize.s,
                      tooltip: l10n.commonCancel,
                      onPressed: () {
                        setState(() {
                          _replyTarget = null;
                          _editTarget = null;
                          _composer.clear();
                        });
                        _composerFocus.requestFocus();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ValueListenableBuilder<Set<String>>(
            valueListenable: engine.typing.typingKeys,
            builder: (context, keys, _) {
              final remoteTyping = keys
                  .where(
                    (key) =>
                        key.startsWith('${widget.channelId}::') &&
                        !key.endsWith('::$localNodeId'),
                  )
                  .isNotEmpty;
              if (!remoteTyping) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  OneBitSpacing.m,
                  OneBitSpacing.xs,
                  OneBitSpacing.m,
                  0,
                ),
                child: Row(
                  children: [
                    const Icon(
                      OneBitIcons.chat,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: OneBitSpacing.xs),
                    Text(
                      l10n.channelTyping,
                      style: OneBitTypography.technicalStyle(
                        fontSize: OneBitTypography.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OneBitSpacing.m,
              OneBitSpacing.s,
              OneBitSpacing.m,
              OneBitSpacing.m,
            ),
            child: Row(
              children: [
                OneBitIconButton(
                  icon: OneBitIcons.attachFile,
                  tooltip: l10n.composeAttach,
                  onPressed: () =>
                      context.go(AppRoutePaths.composeOf(widget.channelId)),
                ),
                const SizedBox(width: OneBitSpacing.xs),
                Expanded(
                  child: OneBitMessageInput(
                    controller: _composer,
                    hintText: l10n.conversationComposerHint,
                    sending: _sending,
                    sendTooltip: l10n.commonSend,
                    onChanged: (value) {
                      unawaited(
                        engine.typingBeacon(
                          widget.channelId,
                          started: value.isNotEmpty,
                        ),
                      );
                    },
                    onSend: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String body) async {
    final l10n = context.l10n;
    setState(() => _sending = true);
    final engine = ref.read(messagingEngineProvider);
    final Result<Message> result;
    if (_editTarget != null) {
      result = await engine.edit(_editTarget!.messageId, body);
    } else if (_replyTarget != null) {
      result = await engine.reply(
        widget.channelId,
        body,
        _replyTarget!.messageId,
      );
    } else {
      result = await engine.sendText(widget.channelId, body);
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.isOk) {
        _composer.clear();
        _replyTarget = null;
        _editTarget = null;
        unawaited(engine.typingBeacon(widget.channelId, started: false));
      }
    });
    if (result.isErr) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _editTarget != null ? l10n.editFailed : l10n.sendFailed,
            ),
          ),
        );
    }
  }

  // ---------------------------------------------------------------------
  // Message actions
  // ---------------------------------------------------------------------

  Future<void> _showMessageActions(Message message) async {
    final localNodeId = ref.read(localNodeIdProvider);
    final isOutbound = message.sender == localNodeId;
    final canEdit =
        isOutbound &&
        (message.status == MessageStatus.created ||
            message.status == MessageStatus.queued ||
            message.status == MessageStatus.waiting ||
            message.status == MessageStatus.routing);
    final canRetry =
        isOutbound &&
        (message.status == MessageStatus.failed ||
            message.status == MessageStatus.expired);

    final action = await showMessageActionSheet(
      context,
      isOutbound: isOutbound,
      canEdit: canEdit,
      canRetry: canRetry,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case MessageAction.reply:
        setState(() {
          _replyTarget = message;
          _editTarget = null;
        });
        _composerFocus.requestFocus();
      case MessageAction.forward:
        await forwardMessage(context, ref, message, widget.channelId);
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.body));
        if (mounted) {
          final l10n = context.l10n;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.messageCopied)));
        }
      case MessageAction.edit:
        if (mounted) {
          setState(() {
            _editTarget = message;
            _replyTarget = null;
            _composer.text = message.body;
            _composer.selection = TextSelection.collapsed(
              offset: message.body.length,
            );
          });
          _composerFocus.requestFocus();
        }
      case MessageAction.retry:
        await ref.read(messagingEngineProvider).retry(message.messageId);
      case MessageAction.select:
        if (mounted) {
          setState(() {
            _selectionMode = true;
            _selected.add(message.messageId);
          });
        }
      case MessageAction.delete:
        await confirmDeleteMessage(context, ref, message.messageId);
    }
  }

  // ---------------------------------------------------------------------
  // Selection mode
  // ---------------------------------------------------------------------

  void _toggleSelected(Message message) {
    setState(() {
      if (!_selected.remove(message.messageId)) {
        _selected.add(message.messageId);
      }
    });
  }

  void _toggleSelectAll(ChannelDetailsView? view) {
    setState(() {
      if (_selected.length == view?.timeline.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(view?.timeline.map((m) => m.messageId) ?? const []);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  Future<void> _copySelection() async {
    final timeline =
        ref
            .read(channelDetailsViewProvider(widget.channelId))
            .value
            ?.timeline ??
        const <Message>[];
    final text = timeline
        .where((m) => _selected.contains(m.messageId))
        .map((m) => m.body)
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    _exitSelection();
  }

  Future<void> _deleteSelection() async {
    final l10n = context.l10n;
    final confirmed = await OneBitDialogs.destructive(
      context,
      title: l10n.selectionDelete,
      message: '${l10n.selectionDelete} (${_selected.length})',
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;
    for (final messageId in _selected.toList()) {
      await ref.read(messagingEngineProvider).delete(messageId);
    }
    _exitSelection();
  }

  // ---------------------------------------------------------------------
  // Channel actions
  // ---------------------------------------------------------------------

  void _scheduleMarkRead(ChannelDetailsView? view) {
    if (_markReadScheduled ||
        view == null ||
        !view.loaded ||
        view.channel == null) {
      return;
    }
    _markReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(channelDetailsViewProvider(widget.channelId).notifier)
              .markRead(),
        );
      }
    });
  }

  Future<void> _showActions(ChannelDetailsView? view) async {
    final l10n = context.l10n;
    final channel = view?.channel;
    if (channel == null) return;

    final action = await showChannelActionSheet(context);
    if (action == null || !mounted) return;

    final controller = ref.read(
      channelDetailsViewProvider(widget.channelId).notifier,
    );
    switch (action) {
      case ChannelAction.markRead:
        await controller.markRead();
      case ChannelAction.togglePinned:
        await controller.setPinned(pinned: !channel.summary.pinned);
      case ChannelAction.toggleMuted:
        await controller.setMuted(muted: !channel.summary.muted);
      case ChannelAction.archive:
        if (await controller.archive() && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.channelsArchived)));
          context.pop();
        }
      case ChannelAction.info:
        if (mounted) await showChannelInfo(context, channel);
    }
  }
}
