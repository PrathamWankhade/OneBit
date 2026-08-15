import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/reaction_mapper.dart';
import 'package:onebit/features/messaging/domain/messages/message_reaction.dart';
import 'package:onebit/features/messaging/domain/reactions/reaction_repository.dart';

/// Drift-backed [ReactionRepository].
final class SqliteReactionRepository implements ReactionRepository {
  SqliteReactionRepository({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;
  static const _tag = LogTags.messaging;

  @override
  Future<Result<void>> upsert(MessageReaction reaction) => ResultGuards.guard(
    logger,
    '$_tag.upsert(${reaction.messageId})',
    () async {
      await _db
          .into(_db.messageReactions)
          .insert(
            ReactionMapper.toRow(reaction),
            mode: InsertMode.insertOrReplace,
          );
    },
  );

  @override
  Future<Result<void>> remove(String messageId, String node, String reaction) =>
      ResultGuards.guard(
        logger,
        '$_tag.remove($messageId, $node, $reaction)',
        () async {
          await (_db.delete(_db.messageReactions)..where(
                (t) =>
                    t.messageId.equals(messageId) &
                    t.node.equals(node) &
                    t.reaction.equals(reaction),
              ))
              .go();
        },
      );

  @override
  Future<Result<void>> removeAllByNode(String messageId, String node) =>
      ResultGuards.guard(
        logger,
        '$_tag.removeAllByNode($messageId, $node)',
        () async {
          await (_db.delete(_db.messageReactions)..where(
                (t) => t.messageId.equals(messageId) & t.node.equals(node),
              ))
              .go();
        },
      );

  @override
  Stream<Result<List<MessageReaction>>> watch(String messageId) =>
      ResultGuards.guardWatch(
        logger,
        '$_tag.watch($messageId)',
        (_db.select(_db.messageReactions)
              ..where((t) => t.messageId.equals(messageId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .watch()
            .map((rows) => rows.map(ReactionMapper.toDomain).toList()),
      );

  @override
  Future<Result<Map<String, int>>> counts(String messageId) =>
      ResultGuards.guard(logger, '$_tag.counts($messageId)', () async {
        final rows =
            await (_db.selectOnly(_db.messageReactions)
                  ..addColumns([_db.messageReactions.reaction, countAll()])
                  ..where(_db.messageReactions.messageId.equals(messageId))
                  ..groupBy([_db.messageReactions.reaction]))
                .get();
        return {
          for (final row in rows)
            row.read(_db.messageReactions.reaction) ?? '':
                row.read(countAll()) ?? 0,
        };
      });

  @override
  Future<Result<bool>> hasReacted(
    String messageId,
    String node,
    String reaction,
  ) => ResultGuards.guard(
    logger,
    '$_tag.hasReacted($messageId, $node, $reaction)',
    () async {
      final row =
          await (_db.select(_db.messageReactions)
                ..where(
                  (t) =>
                      t.messageId.equals(messageId) &
                      t.node.equals(node) &
                      t.reaction.equals(reaction),
                )
                ..limit(1))
              .getSingleOrNull();
      return row != null;
    },
  );
}
