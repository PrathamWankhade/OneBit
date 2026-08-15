import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/draft_mapper.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';
import 'package:onebit/features/messaging/domain/drafts/draft_repository.dart';

/// Drift-backed [DraftRepository]; one draft row per channel.
final class SqliteDraftRepository implements DraftRepository {
  SqliteDraftRepository({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;
  static const _tag = LogTags.messaging;

  @override
  Future<Result<void>> save(Draft draft) =>
      ResultGuards.guard(logger, '$_tag.save(${draft.channelId})', () async {
        await _db
            .into(_db.messageDrafts)
            .insert(
              DraftMapper.toRow(draft.copyWith(updatedAt: DateTime.now())),
              mode: InsertMode.insertOrReplace,
            );
      });

  @override
  Future<Result<Draft?>> load(String channelId) =>
      ResultGuards.guard(logger, '$_tag.load($channelId)', () async {
        final row = await (_db.select(
          _db.messageDrafts,
        )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();
        return row == null ? null : DraftMapper.toDomain(row);
      });

  @override
  Future<Result<void>> delete(String channelId) =>
      ResultGuards.guard(logger, '$_tag.delete($channelId)', () async {
        await (_db.delete(
          _db.messageDrafts,
        )..where((t) => t.channelId.equals(channelId))).go();
      });

  @override
  Future<Result<List<Draft>>> listAll() =>
      ResultGuards.guard(logger, '$_tag.listAll', () async {
        final rows = await _db.select(_db.messageDrafts).get();
        return rows.map(DraftMapper.toDomain).toList();
      });

  @override
  Stream<Result<Draft?>> watch(String channelId) => ResultGuards.guardWatch(
    logger,
    '$_tag.watch($channelId)',
    (_db.select(_db.messageDrafts)..where((t) => t.channelId.equals(channelId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : DraftMapper.toDomain(row)),
  );
}
