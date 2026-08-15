import 'dart:async';

import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/message_mapper.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/domain/messages/message_reaction.dart';
import 'package:onebit/features/messaging/domain/messages/message_repository.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';

/// Drift-backed [MessageRepository] over the shared [OneBitDatabase].
///
/// Timeline paging is keyset-based over `(timestamp, sequence, messageId)`
/// so long channels page without scanning the whole table. Inbound inserts
/// are idempotent (`insertOrIgnore` by message id) and streams never throw.
final class SqliteMessageRepository implements MessageRepository {
  SqliteMessageRepository({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;

  static const _tag = LogTags.messaging;

  $MessagesTable get _messages => _db.messages;

  @override
  Stream<Result<List<Message>>> watchChannel(
    String channelId, {
    int limit = 150,
  }) {
    final query = _db.select(_messages)
      ..where((t) => t.channelId.equals(channelId) & t.deleted.equals(false))
      ..orderBy(_timelineDescending)
      ..limit(limit);

    return ResultGuards.guardWatch(
      logger,
      '$_tag.watchChannel($channelId)',
      query.watch().map(
        (rows) =>
            rows.reversed.map(MessageMapper.toDomain).toList(growable: false),
      ),
    );
  }

  /// The canonical timeline ordering (newest first).
  static List<OrderingTerm Function($MessagesTable)> get _timelineDescending =>
      [
        (t) => OrderingTerm.desc(t.timestamp),
        (t) => OrderingTerm.desc(t.sequence),
        (t) => OrderingTerm.desc(t.packetOrder),
        (t) => OrderingTerm.desc(t.messageId),
      ];

  @override
  Future<Result<MessagePage>> pageChannel(
    String channelId, {
    TimelineCursor? cursor,
    int limit = 50,
  }) => ResultGuards.guard(logger, '$_tag.pageChannel($channelId)', () async {
    final query = _db.select(_messages)
      ..where((t) => t.channelId.equals(channelId) & t.deleted.equals(false));
    if (cursor != null) {
      query.where((t) => _beforeKey(cursor.key));
    }
    query
      ..orderBy(_timelineDescending)
      ..limit(limit);
    final rows = await query.get();
    final items = rows.reversed.map(MessageMapper.toDomain).toList();
    return MessagePage(
      items: items,
      hasMore: rows.length == limit,
      cursor: rows.isEmpty ? cursor : TimelineCursor.after(items.first),
    );
  });

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
  Future<Result<Message?>> getMessage(String messageId) =>
      ResultGuards.guard(logger, '$_tag.getMessage($messageId)', () async {
        final row = await (_db.select(
          _messages,
        )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
        return row == null ? null : MessageMapper.toDomain(row);
      });

  @override
  Future<Result<Message>> insert(Message message) => ResultGuards.guard(
    logger,
    '$_tag.insert(${message.messageId})',
    () async {
      await _db
          .into(_messages)
          .insert(
            MessageMapper.toRow(message),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await (_db.select(
        _messages,
      )..where((t) => t.messageId.equals(message.messageId))).getSingle();
      return MessageMapper.toDomain(row);
    },
  );

  @override
  Future<Result<Message>> update(Message message) => ResultGuards.guard(
    logger,
    '$_tag.update(${message.messageId})',
    () async {
      await (_db.update(_messages)
            ..where((t) => t.messageId.equals(message.messageId)))
          .write(MessageMapper.toCompanion(message));
      final row = await (_db.select(
        _messages,
      )..where((t) => t.messageId.equals(message.messageId))).getSingle();
      return MessageMapper.toDomain(row);
    },
  );

  @override
  Future<Result<Message?>> setStatus(String messageId, MessageStatus status) =>
      ResultGuards.guard(logger, '$_tag.setStatus($messageId)', () async {
        final row = await (_db.select(
          _messages,
        )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
        if (row == null) return null;
        final current =
            MessageStatus.fromWireName(row.status.name) ?? MessageStatus.queued;
        if (status.rank < current.rank) {
          throw MessageTransitionFailure(
            from: current.name,
            to: status.name,
            message: 'status cannot regress',
          );
        }
        await (_db.update(
          _messages,
        )..where((t) => t.messageId.equals(messageId))).write(
          MessagesCompanion(status: Value(MessageMapper.toCoreStatus(status))),
        );
        final updated = await (_db.select(
          _messages,
        )..where((t) => t.messageId.equals(messageId))).getSingle();
        return MessageMapper.toDomain(updated);
      });

  @override
  Future<Result<void>> delete(String messageId) =>
      ResultGuards.guard(logger, '$_tag.delete($messageId)', () async {
        await (_db.update(
          _messages,
        )..where((t) => t.messageId.equals(messageId))).write(
          const MessagesCompanion(
            deleted: Value(true),
            bodyText: Value(null),
            status: Value(core.MessageStatus.deleted),
          ),
        );
      });

  @override
  Future<Result<void>> star(String messageId, {required bool starred}) =>
      ResultGuards.guard(logger, '$_tag.star($messageId)', () async {
        await (_db.update(_messages)
              ..where((t) => t.messageId.equals(messageId)))
            .write(MessagesCompanion(starred: Value(starred)));
      });

  @override
  Future<Result<int>> markReadThrough(
    String channelId,
    MessageOrderKey through,
  ) =>
      ResultGuards.guard(logger, '$_tag.markReadThrough($channelId)', () async {
        final now = DateTime.now();
        final boundary = through.timestamp.millisecondsSinceEpoch;
        final updated =
            await (_db.update(_messages)..where(
                  (t) =>
                      t.channelId.equals(channelId) &
                      t.deleted.equals(false) &
                      t.readAt.isNull() &
                      (t.timestamp.isSmallerThanValue(boundary) |
                          (t.timestamp.equals(boundary) &
                              (t.sequence.isSmallerThanValue(through.sequence) |
                                  (t.sequence.equals(through.sequence) &
                                      (t.messageId.isSmallerThanValue(
                                            through.messageId,
                                          ) |
                                          t.messageId.equals(
                                            through.messageId,
                                          )))))),
                ))
                .write(MessagesCompanion(readAt: Value(now)));
        return updated;
      });

  @override
  Future<Result<int>> countMessages({String? channelId}) =>
      ResultGuards.guard(logger, '$_tag.count', () async {
        final query = _db.selectOnly(_messages);
        query.addColumns([countAll()]);
        if (channelId != null) {
          query.where(_messages.channelId.equals(channelId));
        }
        final row = await query.getSingle();
        return row.read(countAll()) ?? 0;
      });

  @override
  Future<Result<List<Message>>> expireOverdue(
    DateTime now, {
    int limit = 500,
  }) => ResultGuards.guard(logger, '$_tag.expireOverdue', () async {
    final nowMs = now.millisecondsSinceEpoch;
    final candidates =
        await (_db.select(_messages)
              ..where(
                (t) =>
                    t.ttl.isNotNull() &
                    (t.status.equalsValue(core.MessageStatus.queued) |
                        t.status.equalsValue(core.MessageStatus.waiting) |
                        t.status.equalsValue(core.MessageStatus.routing) |
                        t.status.equalsValue(core.MessageStatus.relayed)),
              )
              ..limit(limit))
            .get();
    final rows = candidates
        .where(
          (r) =>
              r.ttl != null &&
              r.timestamp.millisecondsSinceEpoch + r.ttl! * 1000 < nowMs,
        )
        .toList();
    if (rows.isNotEmpty) {
      await (_db.update(
        _messages,
      )..where((t) => t.messageId.isIn(rows.map((r) => r.messageId)))).write(
        const MessagesCompanion(status: Value(core.MessageStatus.expired)),
      );
    }
    return rows.map(MessageMapper.toDomain).toList();
  });

  @override
  Future<Result<List<Message>>> outboxPending(
    String localNodeId, {
    int limit = 500,
  }) => ResultGuards.guard(logger, '$_tag.outboxPending', () async {
    final rows =
        await (_db.select(_messages)
              ..where(
                (t) =>
                    t.sender.equals(localNodeId) &
                    t.packetId.isNull() &
                    (t.status.equalsValue(core.MessageStatus.created) |
                        t.status.equalsValue(core.MessageStatus.queued) |
                        t.status.equalsValue(core.MessageStatus.waiting)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
              ..limit(limit))
            .get();
    return rows.map(MessageMapper.toDomain).toList();
  });

  @override
  Future<Result<List<Message>>> liveOutbound(
    String localNodeId, {
    int limit = 200,
  }) => ResultGuards.guard(logger, '$_tag.liveOutbound', () async {
    final rows =
        await (_db.select(_messages)
              ..where(
                (t) =>
                    t.sender.equals(localNodeId) &
                    t.packetId.isNotNull() &
                    (t.status.equalsValue(core.MessageStatus.waiting) |
                        t.status.equalsValue(core.MessageStatus.routing) |
                        t.status.equalsValue(core.MessageStatus.relayed)),
              )
              ..limit(limit))
            .get();
    return rows.map(MessageMapper.toDomain).toList();
  });

  @override
  Future<Result<List<Message>>> purgeDeleted(
    DateTime olderThan, {
    int limit = 500,
  }) => ResultGuards.guard(logger, '$_tag.purgeDeleted', () async {
    final rows =
        await (_db.select(_messages)
              ..where(
                (t) =>
                    t.deleted.equals(true) &
                    t.timestamp.isSmallerThanValue(
                      olderThan.millisecondsSinceEpoch,
                    ),
              )
              ..limit(limit))
            .get();
    if (rows.isNotEmpty) {
      await (_db.delete(
        _messages,
      )..where((t) => t.messageId.isIn(rows.map((r) => r.messageId)))).go();
    }
    return rows.map(MessageMapper.toDomain).toList();
  });

  // ---- local reactions (message-adjacent surface) ---------------------------

  Future<Result<void>> addReaction(MessageReaction reaction) =>
      ResultGuards.guard(logger, '$_tag.addReaction', () async {
        await _db
            .into(_db.messageReactions)
            .insert(
              MessageReactionsCompanion.insert(
                messageId: reaction.messageId,
                node: reaction.node,
                reaction: reaction.reaction,
                createdAt: reaction.createdAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      });

  Future<Result<void>> removeReaction(
    String messageId,
    String node,
    String reaction,
  ) => ResultGuards.guard(logger, '$_tag.removeReaction', () async {
    await (_db.delete(_db.messageReactions)..where(
          (t) =>
              t.messageId.equals(messageId) &
              t.node.equals(node) &
              t.reaction.equals(reaction),
        ))
        .go();
  });

  Future<Result<List<MessageReaction>>> reactionsFor(String messageId) =>
      ResultGuards.guard(logger, '$_tag.reactionsFor', () async {
        final rows = await (_db.select(
          _db.messageReactions,
        )..where((t) => t.messageId.equals(messageId))).get();
        return rows
            .map(
              (r) => MessageReaction(
                messageId: r.messageId,
                node: r.node,
                reaction: r.reaction,
                createdAt: r.createdAt,
              ),
            )
            .toList();
      });
}
