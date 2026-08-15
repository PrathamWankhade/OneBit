import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/voice/voice_recording.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';
import 'package:onebit/features/messaging/domain/use_cases/edit_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/load_draft.dart';
import 'package:onebit/features/messaging/domain/use_cases/reply_message.dart';
import 'package:onebit/features/messaging/domain/use_cases/save_draft.dart';
import 'package:onebit/features/messaging/domain/use_cases/send_message.dart';
import 'package:onebit/features/messaging/presentation/message_actions_controller.dart';

/// Composer mode.
enum ComposeMode {
  /// Creating a new message.
  newMessage,

  /// Replying to an existing message.
  reply,

  /// Editing an existing message.
  edit,
}

/// A staged attachment of the composer (mirrors the catalog row).
@immutable
final class ComposeAttachment {
  const ComposeAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.category,
    required this.sizeBytes,
  });

  final String attachmentId;
  final String fileName;
  final MediaCategory category;
  final int sizeBytes;

  static ComposeAttachment from(Attachment attachment) => ComposeAttachment(
    attachmentId: attachment.attachmentId,
    fileName: attachment.metadata.fileName,
    category: attachment.metadata.category,
    sizeBytes: attachment.metadata.sizeBytes,
  );
}

/// Presentation state of the message composer.
final class ComposeView {
  const ComposeView({
    this.mode = ComposeMode.newMessage,
    this.channelId = '',
    this.replyTo,
    this.replyPreview,
    this.editMessageId,
    this.draft = '',
    this.attachments = const [],
    this.voiceNote,
    this.sending = false,
    this.enabled = true,
    this.offline = false,
    this.error,
  });

  final ComposeMode mode;
  final String channelId;
  final String? replyTo;
  final String? replyPreview;
  final String? editMessageId;
  final String draft;
  final List<ComposeAttachment> attachments;
  final VoiceRecording? voiceNote;
  final bool sending;
  final bool enabled;
  final bool offline;
  final Object? error;

  ComposeView copyWith({
    ComposeMode? mode,
    String? channelId,
    String? replyTo,
    String? replyPreview,
    String? editMessageId,
    String? draft,
    List<ComposeAttachment>? attachments,
    VoiceRecording? voiceNote,
    bool clearVoiceNote = false,
    bool? sending,
    bool? enabled,
    bool? offline,
    Object? error,
    bool clearError = false,
  }) => ComposeView(
    mode: mode ?? this.mode,
    channelId: channelId ?? this.channelId,
    replyTo: replyTo ?? this.replyTo,
    replyPreview: replyPreview ?? this.replyPreview,
    editMessageId: editMessageId ?? this.editMessageId,
    draft: draft ?? this.draft,
    attachments: attachments ?? this.attachments,
    voiceNote: clearVoiceNote ? null : (voiceNote ?? this.voiceNote),
    sending: sending ?? this.sending,
    enabled: enabled ?? this.enabled,
    offline: offline ?? this.offline,
    error: clearError ? null : (error ?? this.error),
  );

  bool get hasContent =>
      draft.trim().isNotEmpty || attachments.isNotEmpty || voiceNote != null;

  bool get isReply => mode == ComposeMode.reply;
  bool get isEdit => mode == ComposeMode.edit;
}

/// Composer controller with draft persistence and send actions.
final composeMessageControllerProvider =
    NotifierProvider.autoDispose<ComposeMessageController, ComposeView>(
      ComposeMessageController.new,
    );

class ComposeMessageController extends Notifier<ComposeView> {
  static const Duration _draftDebounce = Duration(milliseconds: 500);
  Timer? _draftTimer;

  @override
  ComposeView build() {
    ref.onDispose(() {
      _draftTimer?.cancel();
    });
    return const ComposeView();
  }

  /// Initializes the composer for a new message in [channelId].
  Future<void> initNewMessage(String channelId) async {
    final draft = await ref
        .read(loadDraftProvider)
        .call(LoadDraftParams(channelId));
    state = state.copyWith(
      mode: ComposeMode.newMessage,
      channelId: channelId,
      draft: draft.value?.body ?? '',
      replyTo: null,
      replyPreview: null,
      editMessageId: null,
      attachments: const [],
      clearVoiceNote: true,
    );
  }

  /// Initializes the composer for a reply to [messageId] in [channelId].
  Future<void> initReply(
    String channelId,
    String messageId,
    String preview,
  ) async {
    final draft = await ref
        .read(loadDraftProvider)
        .call(LoadDraftParams('$channelId::reply::$messageId'));
    state = state.copyWith(
      mode: ComposeMode.reply,
      channelId: channelId,
      replyTo: messageId,
      replyPreview: preview,
      draft: draft.value?.body ?? '',
      editMessageId: null,
      attachments: const [],
      clearVoiceNote: true,
    );
  }

  /// Initializes the composer for editing [messageId].
  Future<void> initEdit(
    String channelId,
    String messageId,
    String currentBody,
  ) async {
    state = state.copyWith(
      mode: ComposeMode.edit,
      channelId: channelId,
      editMessageId: messageId,
      draft: currentBody,
      replyTo: null,
      replyPreview: null,
      attachments: const [],
      clearVoiceNote: true,
    );
  }

  /// Updates the draft text (debounced persistence).
  void updateDraft(String text) {
    state = state.copyWith(draft: text, clearError: true);
    _scheduleDraftSave();
  }

  /// Stages an attachment produced by the media engine.
  void addAttachment(Attachment attachment) {
    state = state.copyWith(
      attachments: [...state.attachments, ComposeAttachment.from(attachment)],
      clearError: true,
    );
  }

  /// Removes a staged attachment by catalog id.
  void removeAttachment(String attachmentId) {
    state = state.copyWith(
      attachments: state.attachments
          .where((a) => a.attachmentId != attachmentId)
          .toList(),
    );
  }

  /// Sets the recorded voice note.
  void setVoiceNote(VoiceRecording? note) {
    state = state.copyWith(
      voiceNote: note,
      clearVoiceNote: note == null,
      clearError: true,
    );
  }

  /// Sets the enabled state.
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  /// Sets the offline state.
  void setOffline(bool offline) {
    state = state.copyWith(offline: offline);
  }

  /// Sends the composed message. Returns true on success.
  Future<bool> send() async {
    if (!state.hasContent || state.sending || !state.enabled || state.offline) {
      return false;
    }

    state = state.copyWith(sending: true, clearError: true);

    try {
      switch (state.mode) {
        case ComposeMode.newMessage:
          final clientId = _clientId();
          await ref
              .read(sendMessageProvider)
              .call(
                SendMessageParams(
                  channelId: state.channelId,
                  body: state.draft,
                  type: state.attachments.isNotEmpty || state.voiceNote != null
                      ? MessageType.media
                      : MessageType.text,
                  clientId: clientId,
                ),
              );
          await _linkStagedAttachments(clientId);
        case ComposeMode.reply:
          await ref
              .read(replyMessageProvider)
              .call(
                ReplyMessageParams(
                  channelId: state.channelId,
                  body: state.draft,
                  replyTo: state.replyTo!,
                ),
              );
        case ComposeMode.edit:
          await ref
              .read(editMessageProvider)
              .call(
                EditMessageParams(
                  messageId: state.editMessageId!,
                  body: state.draft,
                ),
              );
      }

      // Clear draft on successful send
      await _clearDraft();
      _reset();
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: e);
      return false;
    }
  }

  /// Cancels the current compose mode (reply/edit) and resets to new message.
  void cancelMode() {
    if (state.mode != ComposeMode.newMessage) {
      _clearDraft();
      _reset();
    }
  }

  /// Clears all content and resets to new message mode.
  void clear() {
    _clearDraft();
    _reset();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(_draftDebounce, () async {
      final key = _draftKey();
      if (key != null && state.draft.trim().isNotEmpty) {
        await ref
            .read(saveDraftProvider)
            .call(SaveDraftParams(channelId: key, body: state.draft));
      }
    });
  }

  String? _draftKey() {
    switch (state.mode) {
      case ComposeMode.newMessage:
        return state.channelId;
      case ComposeMode.reply:
        return '${state.channelId}::reply::${state.replyTo}';
      case ComposeMode.edit:
        return null; // Don't persist edit drafts
    }
  }

  Future<void> _clearDraft() async {
    final key = _draftKey();
    if (key != null) {
      await ref
          .read(saveDraftProvider)
          .call(SaveDraftParams(channelId: key, body: ''));
    }
  }

  Future<void> _linkStagedAttachments(String messageId) async {
    if (state.attachments.isEmpty && state.voiceNote == null) return;
    final engine = ref.read(mediaEngineProvider);
    final repository = ref.read(sqliteAttachmentRepositoryProvider);
    final note = state.voiceNote;
    if (note != null && note.localPath != null) {
      await engine.attachFile(
        source: MediaSource(
          fileName: note.fileName,
          sourcePath: note.localPath,
          declaredMimeType: note.mimeType,
          declaredCategory: MediaCategory.voice,
        ),
        messageId: messageId,
      );
    }
    for (final staged in state.attachments) {
      final found = (await repository.get(staged.attachmentId)).value;
      if (found == null) continue;
      await repository.save(found.copyWith(messageId: messageId));
    }
  }

  void _reset() {
    _draftTimer?.cancel();
    state = const ComposeView();
  }

  String _clientId() => 'compose-${DateTime.now().microsecondsSinceEpoch}';
}
