import 'package:drift/drift.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/thumbnail/thumbnail.dart';
import 'package:onebit/features/media/thumbnail/thumbnail_repository.dart';

/// Drift-backed [ThumbnailRepository] over [MediaDao].
final class SqliteThumbnailRepository implements ThumbnailRepository {
  SqliteThumbnailRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  @override
  Future<Result<Thumbnail>> save(Thumbnail thumbnail) =>
      ResultGuards.guard(logger, 'thumbnail.save', () async {
        await dao.insertThumbnail(_toRow(thumbnail));
        return thumbnail;
      });

  @override
  Future<Result<Thumbnail?>> forAttachment(String attachmentId) =>
      ResultGuards.guard(logger, 'thumbnail.forAttachment', () async {
        final row = await dao.thumbnailForAttachment(attachmentId);
        return row == null ? null : _fromRow(row);
      });

  @override
  Future<Result<void>> delete(String thumbnailId) =>
      ResultGuards.guard(logger, 'thumbnail.delete', () async {
        await dao.deleteThumbnail(thumbnailId);
      });

  @override
  Future<Result<void>> purgeBefore(DateTime cutoff, {int limit = 500}) =>
      ResultGuards.guard(logger, 'thumbnail.purgeBefore', () async {
        await dao.purgeThumbnailsBefore(cutoff, limit: limit);
      });

  @override
  Stream<Result<Thumbnail?>> watch(String attachmentId) =>
      ResultGuards.guardWatch(
        logger,
        'thumbnail.watch',
        dao
            .watchThumbnailForAttachment(attachmentId)
            .map((row) => row == null ? null : _fromRow(row)),
      );

  static Thumbnail _fromRow(MediaThumbnailRow row) => Thumbnail(
    thumbnailId: row.thumbnailId,
    attachmentId: row.attachmentId,
    kind: ThumbnailKind.values.byName(row.kind.name),
    width: row.width,
    height: row.height,
    localPath: row.localPath,
    sizeBytes: row.sizeBytes,
    generatedAt: row.generatedAt,
  );

  static MediaThumbnailsCompanion _toRow(Thumbnail thumbnail) =>
      MediaThumbnailsCompanion.insert(
        thumbnailId: thumbnail.thumbnailId,
        attachmentId: thumbnail.attachmentId,
        kind: core.ThumbnailKind.values.byName(thumbnail.kind.name),
        width: thumbnail.width,
        height: thumbnail.height,
        localPath: Value(thumbnail.localPath),
        sizeBytes: Value(thumbnail.sizeBytes),
        generatedAt: thumbnail.generatedAt,
      );
}
