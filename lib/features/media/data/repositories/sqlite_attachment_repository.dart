import 'package:drift/drift.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/attachments/attachment_repository.dart';
import 'package:onebit/features/media/data/mappers/attachment_mapper.dart';

/// Drift-backed [AttachmentRepository] over [MediaDao].
final class SqliteAttachmentRepository implements AttachmentRepository {
  SqliteAttachmentRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  @override
  Future<Result<Attachment>> save(Attachment attachment) =>
      ResultGuards.guard(logger, 'attachment.save', () async {
        final row = AttachmentMapper.toRow(attachment);
        final exists = await dao.attachmentRow(attachment.attachmentId) != null;
        if (exists) {
          await dao.updateAttachment(row);
        } else {
          await dao.insertAttachment(row);
        }
        return attachment;
      });

  Future<Result<bool>> existsBySha256(String sha256) => ResultGuards.guard(
    logger,
    'attachment.existsBySha256',
    () async => (await dao.attachmentBySha256(sha256)) != null,
  );

  @override
  Future<Result<Attachment?>> get(String attachmentId) =>
      ResultGuards.guard(logger, 'attachment.get', () async {
        final row = await dao.attachmentRow(attachmentId);
        return row == null ? null : AttachmentMapper.fromRow(row);
      });

  @override
  Future<Result<List<Attachment>>> listByMessage(String messageId) =>
      ResultGuards.guard(logger, 'attachment.listByMessage', () async {
        final rows = await dao.attachmentsForMessage(messageId);
        return rows.map(AttachmentMapper.fromRow).toList();
      });

  @override
  Future<Result<List<Attachment>>> listByCategory(MediaCategory category) =>
      ResultGuards.guard(logger, 'attachment.listByCategory', () async {
        final rows = await dao.attachmentsByCategory(
          AttachmentMapper.coreCategory(category),
        );
        return rows.map(AttachmentMapper.fromRow).toList();
      });

  @override
  Future<Result<void>> delete(String attachmentId) => ResultGuards.guard(
    logger,
    'attachment.delete',
    () async => dao.deleteAttachment(attachmentId),
  );

  @override
  Future<Result<void>> updateStatus(
    String attachmentId,
    AttachmentStatus status,
  ) => ResultGuards.guard(logger, 'attachment.updateStatus', () async {
    final row = await dao.attachmentRow(attachmentId);
    if (row == null) return;
    await dao.updateAttachment(
      row
          .toCompanion(true)
          .copyWith(
            status: Value(AttachmentMapper.coreStatus(status)),
            updatedAt: Value(DateTime.now()),
          ),
    );
  });

  @override
  Future<Result<List<Attachment>>> purgeBefore(
    DateTime cutoff, {
    int limit = 500,
  }) => ResultGuards.guard(logger, 'attachment.purgeBefore', () async {
    final rows = await dao.purgeAttachmentsBefore(cutoff, limit: limit);
    return rows.map(AttachmentMapper.fromRow).toList();
  });

  @override
  Stream<Result<List<Attachment>>> watchByMessage(String messageId) =>
      ResultGuards.guardWatch(
        logger,
        'attachment.watchByMessage',
        dao
            .watchAttachmentsForMessage(messageId)
            .map((rows) => rows.map(AttachmentMapper.fromRow).toList()),
      );
}
