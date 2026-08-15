import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';
import 'package:onebit/features/messaging/domain/notifications/notification_repository.dart';

/// Drift-backed [NotificationRepository] over the durable `Notifications` log.
final class SqliteNotificationRepository implements NotificationRepository {
  SqliteNotificationRepository({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;
  static const _tag = LogTags.messaging;

  $NotificationsTable get _notifications => _db.notifications;

  @override
  Future<Result<NotificationEvent>> push(NotificationEvent event) =>
      ResultGuards.guard(logger, '$_tag.push(${event.kind.name})', () async {
        final row = await _db
            .into(_notifications)
            .insertReturning(
              NotificationsCompanion.insert(
                kind: event.kind.name,
                level: event.level.name,
                channelId: Value(event.channelId),
                messageId: Value(event.messageId),
                node: Value(event.node),
                title: Value(event.title),
                body: Value(event.body),
                payloadJson: Value(
                  event.payload.isEmpty ? null : jsonEncode(event.payload),
                ),
                createdAt: event.createdAt ?? DateTime.now(),
              ),
            );
        return _toEvent(row);
      });

  @override
  Stream<Result<NotificationEvent>> watch() {
    final query = (_db.select(_notifications)
      ..orderBy([(t) => OrderingTerm.desc(t.notificationId)])
      ..limit(100));
    return ResultGuards.guardWatch(
      logger,
      '$_tag.watch',
      query.watch().map((rows) => rows.map(_toEvent).toList()),
    ).expand(
      (result) => switch (result) {
        Ok(value: final events) => (events ?? const <NotificationEvent>[]).map(
          Ok<NotificationEvent>.new,
        ),
        Err(failure: final failure) => [
          Err<NotificationEvent>(failure ?? const UnexpectedFailure()),
        ],
      },
    );
  }

  @override
  Future<Result<SearchPage<NotificationEvent>>> page({
    int offset = 0,
    int limit = 50,
  }) => ResultGuards.guard(logger, '$_tag.page', () async {
    final rows =
        await (_db.select(_notifications)
              ..orderBy([(t) => OrderingTerm.desc(t.notificationId)])
              ..limit(limit, offset: offset))
            .get();
    return SearchPage<NotificationEvent>(
      items: rows.map(_toEvent).toList(),
      offset: offset,
      limit: limit,
      hasMore: rows.length == limit,
    );
  });

  @override
  Future<Result<void>> clearAll() =>
      ResultGuards.guard(logger, '$_tag.clearAll', () async {
        await _db.delete(_notifications).go();
      });

  NotificationEvent _toEvent(NotificationRow row) => NotificationEvent(
    kind:
        NotificationKind.values.where((k) => k.name == row.kind).firstOrNull ??
        NotificationKind.system,
    level:
        NotificationLevel.values
            .where((l) => l.name == row.level)
            .firstOrNull ??
        NotificationLevel.info,
    channelId: row.channelId,
    messageId: row.messageId,
    node: row.node,
    title: row.title,
    body: row.body,
    payload: row.payloadJson == null
        ? const {}
        : (jsonDecode(row.payloadJson!) as Map).cast<String, Object?>(),
    createdAt: row.createdAt,
  );
}
