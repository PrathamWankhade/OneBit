import 'package:onebit/core/result/result.dart';

import 'channel.dart';
import 'channel_settings.dart';
import 'channel_type.dart';
import 'conversation_summary.dart';
import 'pinned_message.dart';

/// Kinds of typing diagnostics rows (persisted for developer tooling).
enum TypingDiagnosticsKind { started, stopped, timeout, idle }

/// Parameters for opening/creating a channel.
final class CreateChannelParams {
  const CreateChannelParams({
    required this.type,
    this.title,
    this.peer,
    this.autoDeleteAfter,
  });

  final ChannelType type;

  /// Optional display title; private channels default to the peer's name.
  final String? title;

  /// The other participant (private channels only).
  final String? peer;

  /// Optional local retention.
  final Duration? autoDeleteAfter;
}

/// Contract for channel lifecycle and the conversation list.
///
/// Implementations: drift-backed and in-memory fakes for tests.
abstract interface class ChannelRepository {
  /// Streams the conversation list (optionally including archived).
  Stream<Result<List<ConversationSummary>>> watchSummaries({
    bool includeArchived = false,
  });

  Future<Result<List<ConversationSummary>>> listSummaries({
    bool includeArchived = false,
  });

  Future<Result<Channel?>> getChannel(String channelId);

  /// Creates a channel if absent, or returns the existing one (idempotent
  /// for the same (type, peer) pair).
  Future<Result<Channel>> create(CreateChannelParams params);

  Future<Result<Channel>> rename(String channelId, String title);

  /// Soft-hides the channel from the active list.
  Future<Result<void>> archive(String channelId, {bool archived = true});

  /// Hard-deletes the channel and everything in it (cascade).
  Future<Result<void>> deleteChannel(String channelId);

  Future<Result<void>> setMuted(String channelId, {DateTime? until});

  Future<Result<void>> unmute(String channelId);

  Future<Result<void>> setPinned(String channelId, {required bool pinned});

  Future<Result<void>> setNotificationPreference(
    String channelId,
    ChannelNotificationPreference preference,
  );

  /// Resets the unread counter to zero.
  Future<Result<void>> markRead(String channelId);

  /// Applies the side effects of a new (unseen) inbound message: bumps the
  /// unread counter and freshens the conversation-list metadata.
  Future<Result<void>> bumpActivity(
    String channelId, {
    int unreadDelta = 0,
    String? lastMessageId,
    DateTime? lastMessageAt,
  });

  /// Allocates the next per-channel sequence counter.
  Future<Result<int>> nextSequence(String channelId);

  // ---- Pinned messages ------------------------------------------------------

  Future<Result<void>> pinMessage(String channelId, String messageId);

  Future<Result<void>> unpinMessage(String channelId, String messageId);

  Future<Result<List<PinnedMessage>>> pinnedMessages(String channelId);

  /// Records a typing lifecycle row for developer diagnostics. Never throws
  /// into the caller — failures are logged and swallowed by the impl.
  Future<Result<void>> recordTypingEvent({
    required String channelId,
    required String node,
    required TypingDiagnosticsKind kind,
    required DateTime startedAt,
    DateTime? endedAt,
  });
}
