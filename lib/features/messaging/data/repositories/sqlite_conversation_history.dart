import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/message_mapper.dart';
import 'package:onebit/features/messaging/domain/history/conversation_history.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';

/// Drift-backed [ConversationHistory] implementation.
///
/// Lazy timeline loading with keyset cursors: `loadNewest` fetches the
/// newest page, `loadOlder` pages backward strictly before a cursor and
/// `loadAround` jumps to a message (search result / pinned / reply target)
/// with a bounded window on both sides.
final class SqliteConversationHistory implements ConversationHistory {
  SqliteConversationHistory({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;
  static const _tag = LogTags.messaging;

  $MessagesTable get _messages => _db.messages;

  /// Canonical timeline ordering (newest first), identical to
  /// [SqliteMessageRepository]: timestamp → sequence → packetOrder →
  /// messageId.
  List<OrderingTerm Function($MessagesTable)> get _timelineDescending => [
    (t) => OrderingTerm.desc(t.timestamp),
    (t) => OrderingTerm.desc(t.sequence),
    (t) => OrderingTerm.desc(t.packetOrder),
    (t) => OrderingTerm.desc(t.messageId),
  ];

  /// The same key set, oldest first (jump-around windows).
  List<OrderingTerm Function($MessagesTable)> get _timelineAscending => [
    (t) => OrderingTerm.asc(t.timestamp),
    (t) => OrderingTerm.asc(t.sequence),
    (t) => OrderingTerm.asc(t.packetOrder),
    (t) => OrderingTerm.asc(t.messageId),
  ];

  /// Keyset filter: strictly before (timestamp, sequence, packetOrder,
  /// messageId) — the persisted ordering key of the timeline.
  Expression<bool> _beforeKey(MessageOrderKey key) {
    final ts = _messages.timestamp;
    final seq = _messages.sequence;
    final order = _messages.packetOrder;
    final id = _messages.messageId;
    final tsValue = key.timestamp.millisecondsSinceEpoch;
    return CustomExpression<bool>(
      '(${_column(ts)} < $tsValue OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} < ${key.sequence}) OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} = ${key.sequence} '
      'AND ${_column(order)} < ${key.packetOrder}) OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} = ${key.sequence} '
      'AND ${_column(order)} = ${key.packetOrder} '
      'AND ${_column(id)} < ${_sqlString(key.messageId)}))',
    );
  }

  String _column(GeneratedColumn<dynamic> column) =>
      '${_messages.actualTableName}.${column.name}';

  String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

  @override
  Future<Result<MessagePage>> loadNewest(String channelId, {int limit = 50}) =>
      ResultGuards.guard(logger, '$_tag.loadNewest($channelId)', () async {
        final rows =
            await (_db.select(_messages)
                  ..where(
                    (t) =>
                        t.channelId.equals(channelId) & t.deleted.equals(false),
                  )
                  ..orderBy(_timelineDescending)
                  ..limit(limit))
                .get();
        final items = rows.reversed.map(MessageMapper.toDomain).toList();
        return MessagePage(
          items: items,
          cursor: items.isEmpty ? null : TimelineCursor.after(items.first),
          hasMore: rows.length == limit,
        );
      });

  @override
  Future<Result<MessagePage>> loadOlder(
    String channelId, {
    required TimelineCursor cursor,
    int limit = 50,
  }) => ResultGuards.guard(logger, '$_tag.loadOlder($channelId)', () async {
    final query = _db.select(_messages)
      ..where((t) => t.channelId.equals(channelId) & t.deleted.equals(false))
      ..where((t) => _beforeKey(cursor.key));
    query
      ..orderBy(_timelineDescending)
      ..limit(limit);
    final rows = await query.get();
    final items = rows.reversed.map(MessageMapper.toDomain).toList();
    return MessagePage(
      items: items,
      cursor: items.isEmpty ? cursor : TimelineCursor.after(items.first),
      hasMore: rows.length == limit,
    );
  });

  @override
  Future<Result<MessagePage>> loadAround(
    String channelId, {
    required String anchorMessageId,
    int window = 25,
  }) async {
    try {
      final anchorRow =
          await (_db.select(_messages)
                ..where(
                  (t) =>
                      t.messageId.equals(anchorMessageId) &
                      t.channelId.equals(channelId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (anchorRow == null) {
        return Err(
          MessageNotFoundFailure(
            packetId: anchorMessageId,
            message: 'anchor message not found in $channelId',
          ),
        );
      }
      final anchor = MessageMapper.toDomain(anchorRow);
      final anchorKey = MessageOrderKey.of(anchor);
      final half = window ~/ 2;

      // Newer messages: the closest `half` messages after the anchor,
      // ascending.
      final newerRows =
          await (_db.select(_messages)
                ..where(
                  (t) =>
                      t.channelId.equals(channelId) &
                      t.deleted.equals(false) &
                      _afterKey(anchorKey),
                )
                ..orderBy(_timelineAscending)
                ..limit(half))
              .get();
      // Older messages: the closest `half` messages before the anchor,
      // newest first, then reversed for timeline order.
      final olderRows =
          await (_db.select(_messages)
                ..where(
                  (t) =>
                      t.channelId.equals(channelId) &
                      t.deleted.equals(false) &
                      _beforeKey(anchorKey),
                )
                ..orderBy(_timelineDescending)
                ..limit(half))
              .get();

      final older = olderRows.reversed.map(MessageMapper.toDomain).toList();
      final newer = newerRows.map(MessageMapper.toDomain).toList();
      final windowItems = [...older, anchor, ...newer];

      return Ok(
        MessagePage(
          items: windowItems,
          cursor: windowItems.isEmpty
              ? null
              : TimelineCursor.after(windowItems.first),
          hasMore: windowItems.length >= window,
        ),
      );
    } catch (error, stackTrace) {
      final failure = ResultGuards.toStorageFailure(
        '$_tag.loadAround($channelId)',
        error,
        stackTrace,
      );
      logger.error(
        '$_tag.loadAround($channelId) failed',
        tag: _tag,
        error: failure,
      );
      return Err(failure);
    }
  }

  /// Keyset filter: strictly after (timestamp, sequence, packetOrder,
  /// messageId).
  Expression<bool> _afterKey(MessageOrderKey key) {
    final ts = _messages.timestamp;
    final seq = _messages.sequence;
    final order = _messages.packetOrder;
    final id = _messages.messageId;
    final tsValue = key.timestamp.millisecondsSinceEpoch;
    return CustomExpression<bool>(
      '(${_column(ts)} > $tsValue OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} > ${key.sequence}) OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} = ${key.sequence} '
      'AND ${_column(order)} > ${key.packetOrder}) OR '
      '(${_column(ts)} = $tsValue AND ${_column(seq)} = ${key.sequence} '
      'AND ${_column(order)} = ${key.packetOrder} '
      'AND ${_column(id)} > ${_sqlString(key.messageId)}))',
    );
  }

  @override
  Future<Result<int>> count(String channelId) => ResultGuards.guard(
    logger,
    '$_tag.count($channelId)',
    () async {
      final query = _db.selectOnly(_messages);
      query.addColumns([countAll()]);
      query.where(
        _messages.channelId.equals(channelId) & _messages.deleted.equals(false),
      );
      final row = await query.getSingle();
      return row.read(countAll()) ?? 0;
    },
  );

  @override
  Future<Result<Message?>> newest(String channelId) =>
      ResultGuards.guard(logger, '$_tag.newest($channelId)', () async {
        final row =
            await (_db.select(_messages)
                  ..where(
                    (t) =>
                        t.channelId.equals(channelId) & t.deleted.equals(false),
                  )
                  ..orderBy(_timelineDescending)
                  ..limit(1))
                .getSingleOrNull();
        return row == null ? null : MessageMapper.toDomain(row);
      });
}
