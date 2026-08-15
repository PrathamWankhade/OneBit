import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/attachment_picker.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/presentation/voice_recorder_sheet.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/use_cases/load_draft.dart';
import 'package:onebit/features/messaging/presentation/compose_message_screen/widgets/compose_widgets.dart';
import 'package:onebit/features/messaging/presentation/message_actions_controller.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart'
    show OneBitMessageInput;
import 'package:onebit/shared/design_system/components/onebit_offline_banner.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Production message composer with full feature support.
///
/// Supports:
/// - Text entry with draft persistence
/// - Attachment action (files, images, documents)
/// - Voice action (record/attach voice notes)
/// - Reply state (shows quoted message)
/// - Edit state (shows original message)
/// - Send state (loading indicator)
/// - Disabled state
/// - Offline state
class ComposeMessageScreen extends ConsumerStatefulWidget {
  const ComposeMessageScreen({
    required this.channelId,
    this.replyToMessageId,
    this.editMessageId,
    super.key,
  });

  /// Channel identifier from the route.
  final String channelId;

  /// Optional message being replied to.
  final String? replyToMessageId;

  /// Optional message being edited.
  final String? editMessageId;

  @override
  ConsumerState<ComposeMessageScreen> createState() =>
      _ComposeMessageScreenState();
}

final class _ComposeMessageScreenState
    extends ConsumerState<ComposeMessageScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeComposer();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeComposer() async {
    final controller = ref.read(composeMessageControllerProvider.notifier);
    final channelId = widget.channelId;

    if (widget.editMessageId != null) {
      final message = await _loadMessage(widget.editMessageId!);
      if (message != null && mounted) {
        _textController.text = message.body;
        await controller.initEdit(
          channelId,
          widget.editMessageId!,
          message.body,
        );
      }
    } else if (widget.replyToMessageId != null) {
      final message = await _loadMessage(widget.replyToMessageId!);
      if (message != null && mounted) {
        await controller.initReply(
          channelId,
          widget.replyToMessageId!,
          message.body,
        );
      }
    } else {
      await controller.initNewMessage(channelId);
      final draft = await ref
          .read(loadDraftProvider)
          .call(LoadDraftParams(channelId));
      if (draft.isOk &&
          draft.value != null &&
          draft.value!.body.isNotEmpty &&
          mounted) {
        _textController.text = draft.value!.body;
      }
    }

    // Sync offline state
    final meshState = ref.read(meshStateProvider).value?.value;
    final offline = meshState != null && meshState != MeshEngineState.running;
    if (mounted) {
      controller.setOffline(offline);
    }
  }

  Future<Message?> _loadMessage(String messageId) async {
    final result = await ref
        .read(messageRepositoryProvider)
        .getMessage(messageId);
    return result.value;
  }

  void _onTextChanged(String text) {
    ref.read(composeMessageControllerProvider.notifier).updateDraft(text);
  }

  Future<void> _onSend(String _) async {
    final l10n = context.l10n;
    final success = await ref
        .read(composeMessageControllerProvider.notifier)
        .send();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.composeMessageSent : l10n.composeSendFailed,
        ),
      ),
    );
    if (success && context.canPop()) {
      context.pop();
    }
  }

  void _onCancelMode() {
    ref.read(composeMessageControllerProvider.notifier).cancelMode();
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _showAttachments() async {
    final l10n = context.l10n;
    final pick = await ref.read(attachmentPickerProvider).pick(context);
    if (pick == null || !mounted) return;
    final result = await ref
        .read(mediaEngineProvider)
        .attachFile(
          source: MediaSource(
            fileName: pick.fileName,
            sourcePath: pick.sourcePath,
            declaredCategory: pick.declaredCategory,
            declaredMimeType: pick.declaredMimeType,
          ),
        );
    if (!mounted) return;
    final attachment = result.value;
    if (attachment == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.composeAttachmentError)));
      return;
    }
    ref
        .read(composeMessageControllerProvider.notifier)
        .addAttachment(attachment);
  }

  Future<void> _showVoiceRecorder() async {
    final note = await showVoiceRecorderSheet(context);
    if (note != null && mounted) {
      ref.read(composeMessageControllerProvider.notifier).setVoiceNote(note);
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => EmojiSheet(
        onSelected: (emoji) {
          final controller = ref.read(
            composeMessageControllerProvider.notifier,
          );
          final index = _textController.selection.isValid
              ? _textController.selection.baseOffset
              : _textController.text.length;
          final text = _textController.text;
          final updated = text.replaceRange(
            index.clamp(0, text.length),
            index.clamp(0, text.length),
            emoji,
          );
          _textController.text = updated;
          _textController.selection = TextSelection.collapsed(
            offset: index.clamp(0, text.length) + emoji.length,
          );
          controller.updateDraft(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(composeMessageControllerProvider);
    final controller = ref.read(composeMessageControllerProvider.notifier);

    // Sync text controller with view draft
    if (_textController.text != view.draft) {
      _textController.text = view.draft;
      _textController.selection = TextSelection.collapsed(
        offset: view.draft.length,
      );
    }

    final isReply = view.isReply;
    final isEdit = view.isEdit;
    final canSend =
        view.hasContent && view.enabled && !view.sending && !view.offline;

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? l10n.composeEditTitle
              : (isReply ? l10n.composeReplyTitle : l10n.composeMessageTitle),
        ),
        leading: view.mode != ComposeMode.newMessage
            ? IconButton(
                icon: const Icon(OneBitIcons.close),
                tooltip: l10n.commonCancel,
                onPressed: _onCancelMode,
              )
            : null,
        actions: [
          if (view.mode != ComposeMode.newMessage)
            TextButton(
              onPressed: _onCancelMode,
              child: Text(l10n.commonCancel),
            ),
          if (canSend)
            OneBitIconButton(
              icon: OneBitIcons.send,
              onPressed: () => _onSend(view.draft),
              tooltip: l10n.commonSend,
              size: OneBitIconSize.m,
            )
          else if (view.sending)
            const Padding(
              padding: EdgeInsets.all(OneBitSpacing.m),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            OneBitIconButton(
              icon: OneBitIcons.send,
              onPressed: null,
              tooltip: l10n.commonSend,
              size: OneBitIconSize.m,
            ),
        ],
      ),
      body: Column(
        children: [
          if (view.offline)
            OneBitOfflineBanner(
              title: l10n.channelsOfflineTitle,
              message: l10n.channelsOfflineMessage,
            ),
          if (isReply && view.replyPreview != null)
            ReplyBanner(preview: view.replyPreview!, onDismiss: _onCancelMode),
          if (isEdit) EditBanner(onDismiss: _onCancelMode),
          if (view.attachments.isNotEmpty)
            AttachmentsBar(
              attachments: view.attachments,
              onRemove: controller.removeAttachment,
            ),
          if (view.voiceNote != null)
            VoiceNoteBar(
              durationMs: view.voiceNote!.durationMs,
              onRemove: () => controller.setVoiceNote(null),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(OneBitSpacing.m),
              child: OneBitMessageInput(
                controller: _textController,
                onSend: _onSend,
                onChanged: _onTextChanged,
                hintText: view.offline
                    ? l10n.composeOfflineHint
                    : l10n.composeHint,
                enabled: view.enabled && !view.offline,
                sending: view.sending,
                sendTooltip: l10n.commonSend,
              ),
            ),
          ),
          ComposerActions(
            onAttach: _showAttachments,
            onVoice: _showVoiceRecorder,
            onEmoji: _showEmojiPicker,
            enabled: view.enabled && !view.offline && !view.sending,
          ),
        ],
      ),
    );
  }
}
