import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/channel_tables.dart';

part 'channel_dao.g.dart';

/// Typed persistence for channels and typing indicators.
///
/// DAO layer only — exceptions bubble up and repositories map them to
/// `Result<T>` failures.
@DriftAccessor(tables: [Channels, TypingEvents])
final class ChannelDao extends DatabaseAccessor<OneBitDatabase>
    with _$ChannelDaoMixin {
  ChannelDao(super.db);

  @override
  $ChannelsTable get channels => db.channels;

  @override
  $TypingEventsTable get typingEvents => db.typingEvents;

  // ---- Channels --------------------------------------------------------------

  Future<ChannelRow?> getChannel(String channelId) => (select(
    channels,
  )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();

  Future<List<ChannelRow>> listChannels({bool includeArchived = false}) {
    final query = select(channels)
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    return query.get();
  }

  Stream<List<ChannelRow>> watchChannels({bool includeArchived = false}) {
    final query = select(channels)
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    return query.watch();
  }

  Future<int> upsertChannel(ChannelRow row) =>
      into(channels).insertOnConflictUpdate(row);

  Future<int> deleteChannel(String channelId) =>
      (delete(channels)..where((t) => t.channelId.equals(channelId))).go();

  Future<int> setUnreadCount(String channelId, int count) =>
      (update(channels)..where((t) => t.channelId.equals(channelId))).write(
        ChannelsCompanion(
          unreadCount: Value(count),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> setArchived(String channelId, bool archived) =>
      (update(channels)..where((t) => t.channelId.equals(channelId))).write(
        ChannelsCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> setPinned(String channelId, bool pinned) =>
      (update(channels)..where((t) => t.channelId.equals(channelId))).write(
        ChannelsCompanion(
          pinned: Value(pinned),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> setMuted(
    String channelId, {
    required bool muted,
    DateTime? until,
  }) => (update(channels)..where((t) => t.channelId.equals(channelId))).write(
    ChannelsCompanion(
      muted: Value(muted),
      mutedUntil: Value(until),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Advances the channel tail after a message write.
  ///
  /// Uses a parameterized statement so the unread delta is applied atomically
  /// (never read-modify-write races) without string-interpolating user data.
  Future<int> touchChannel(
    String channelId, {
    required String lastMessageId,
    required DateTime lastMessageAt,
    required int unreadDelta,
  }) => customUpdate(
    '''
UPDATE channels
SET last_message_id = ?, last_message_at = ?, unread_count = unread_count + ?, updated_at = ?
WHERE channel_id = ?''',
    variables: [
      Variable(lastMessageId),
      Variable(lastMessageAt.millisecondsSinceEpoch),
      Variable(unreadDelta),
      Variable(lastMessageAt.millisecondsSinceEpoch),
      Variable(channelId),
    ],
    updateKind: UpdateKind.update,
  );

  // ---- Typing events ----------------------------------------------------------

  Future<int> insertTypingEvent(TypingEventsCompanion event) =>
      into(typingEvents).insert(event);

  Future<int> endTypingEvents(String channelId, String node) =>
      (update(typingEvents)
            ..where((t) => t.channelId.equals(channelId) & t.node.equals(node)))
          .write(TypingEventsCompanion(endedAt: Value(DateTime.now())));

  Future<List<TypingEventRow>> activeTyping({int limit = 50}) =>
      (select(typingEvents)
            ..where((t) => t.endedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();
}
