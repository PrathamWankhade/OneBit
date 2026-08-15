import 'package:drift/drift.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/preview/media_preview.dart';
import 'package:onebit/features/media/preview/preview_repository.dart';

/// Drift-backed [PreviewRepository] over [MediaDao] and the probed JSON.
final class SqlitePreviewRepository implements PreviewRepository {
  SqlitePreviewRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  @override
  Future<Result<MediaPreview>> save(MediaPreview preview) =>
      ResultGuards.guard(logger, 'preview.save', () async {
        await dao.insertPreview(_toRow(preview));
        return preview;
      });

  @override
  Future<Result<MediaPreview?>> forAttachment(String attachmentId) =>
      ResultGuards.guard(logger, 'preview.forAttachment', () async {
        final row = await dao.previewForAttachment(attachmentId);
        return row == null ? null : _fromRow(row);
      });

  @override
  Future<Result<void>> delete(String previewId) =>
      ResultGuards.guard(logger, 'preview.delete', () async {
        final row = await dao.previewRow(previewId);
        if (row == null) return;
        await dao.deletePreview(row.previewId);
      });

  static MediaPreview _fromRow(MediaPreviewRow row) => MediaPreview(
    previewId: row.previewId,
    attachmentId: row.attachmentId,
    kind: PreviewKind.values.byName(row.kind.name),
    metadataJson: row.metadataJson ?? '{}',
    thumbnailId: row.thumbnailId,
    createdAt: row.createdAt,
  );

  static MediaPreviewsCompanion _toRow(MediaPreview preview) =>
      MediaPreviewsCompanion.insert(
        previewId: preview.previewId,
        attachmentId: preview.attachmentId,
        kind: core.PreviewKind.values.byName(preview.kind.name),
        metadataJson: Value(preview.metadataJson),
        thumbnailId: Value(preview.thumbnailId),
        createdAt: preview.createdAt,
      );
}
