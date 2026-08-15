import 'package:onebit/core/result/result.dart';

import 'message.dart';
import 'message_ordering.dart';
import 'message_status.dart';

/// Contract for the channel timeline store.
///
/// Implementations: drift-backed (SqliteMessageRepository) and in-memory
/// fakes for tests. Every call returns a `Result` — nothing throws across
/// this boundary.
abstract interface class MessageRepository {
  /// Streams the latest [limit] messages of [channelId], newest-last, and
  /// re-emits whenever the channel changes.
  Stream<Result<List<Message>>> watchChannel(
    String channelId, {
    int limit = 100,
  });

  /// Pages messages older than [cursor] (ascending order). Pass
  /// `cursor: null` for the newest page.
  Future<Result<MessagePage>> pageChannel(
    String channelId, {
    TimelineCursor? cursor,
    int limit = 50,
  });

  Future<Result<Message?>> getMessage(String messageId);

  /// Stores a message, applying the ordering fields. Inbound duplicates are
  /// dropped (idempotent by messageId).
  Future<Result<Message>> insert(Message message);

  /// Full-row update (edits, status transitions).
  Future<Result<Message>> update(Message message);

  /// Forward-only status transition. Returns the updated message.
  Future<Result<Message?>> setStatus(String messageId, MessageStatus status);

  /// Soft-deletes the message (tombstone). The body is erased.
  Future<Result<void>> delete(String messageId);

  Future<Result<void>> star(String messageId, {required bool starred});

  /// Marks all messages older than [through] (by timeline order) as read,
  /// returning the number updated.
  Future<Result<int>> markReadThrough(
    String channelId,
    MessageOrderKey through,
  );

  Future<Result<int>> countMessages({String? channelId});

  /// Hard-deletes soft-deleted tombstones older than [olderThan].
  Future<Result<List<Message>>> purgeDeleted(
    DateTime olderThan, {
    int limit = 500,
  });

  /// Live outbound messages whose envelope was never stored (crash before
  /// `dtn.store`): `created`/`queued`, or `waiting` without a packet id.
  /// The engine re-stores these on startup.
  Future<Result<List<Message>>> outboxPending(
    String localNodeId, {
    int limit = 500,
  });

  /// Outbound messages currently in flight (`waiting`/`routing`/`relayed`
  /// with a packet id) that still need DTN progress probing.
  Future<Result<List<Message>>> liveOutbound(
    String localNodeId, {
    int limit = 200,
  });

  /// Marks live outbound messages whose TTL has passed as `expired`
  /// (forward-only). Returns the expired rows.
  Future<Result<List<Message>>> expireOverdue(DateTime now, {int limit = 500});
}
