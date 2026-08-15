import 'package:onebit/core/database/dao/message_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/models/page.dart';
import 'package:onebit/core/database/query/message_query.dart';
import 'package:onebit/core/database/query/page_request.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for messages, attachments, voice notes and receipts.
///
/// Timelines are streamed straight from SQLite (no caching); writes run
/// through the DAO with `insertOrIgnore` dedup semantics.
final class MessageRepository {
  MessageRepository({required this._dao, required this._logger});

  final MessageDao _dao;
  final AppLogger _logger;

  static const _tag = 'message.dao';

  Future<Result<MessageRow?>> getMessage(String messageId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getMessage',
        () => _dao.getMessage(messageId),
      );

  Future<Result<Page<MessageRow>>> pageChannelMessages(
    String channelId, {
    PageRequest request = const PageRequest(),
    DateTime? before,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pageChannelMessages',
    () => _dao.pageChannelMessages(channelId, request: request, before: before),
  );

  Future<Result<Page<MessageRow>>> queryMessages(
    MessageQuery query, {
    PageRequest request = const PageRequest(),
  }) => ResultGuards.guard(
    _logger,
    '$_tag.queryMessages',
    () => _dao.queryMessages(query, request: request),
  );

  Stream<Result<List<MessageRow>>> watchChannelMessages(
    String channelId, {
    int limit = 100,
  }) => ResultGuards.guardWatch(
    _logger,
    '$_tag.watchChannelMessages',
    _dao.watchChannelMessages(channelId, limit: limit),
  );

  /// Inserts a message, ignoring duplicates (idempotent re-delivery).
  Future<Result<int>> insertMessage(MessageRow row) => ResultGuards.guard(
    _logger,
    '$_tag.insertMessage',
    () => _dao.insertMessage(row),
  );

  /// Bulk upsert of inbound messages (sync/backup restore path).
  Future<Result<void>> insertAllMessages(List<MessageRow> rows) =>
      ResultGuards.guard(
        _logger,
        '$_tag.insertAllMessages',
        () => _dao.insertAllMessages(rows),
      );

  Future<Result<int>> updateMessage(MessageRow row) => ResultGuards.guard(
    _logger,
    '$_tag.updateMessage',
    () => _dao.updateMessage(row),
  );

  Future<Result<int>> setMessageStatus(
    String messageId,
    MessageStatus status,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.setMessageStatus',
    () => _dao.setMessageStatus(messageId, status),
  );

  Future<Result<int>> markDeleted(String messageId, {bool deleted = true}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.markDeleted',
        () => _dao.markDeleted(messageId, deleted: deleted),
      );

  Future<Result<int>> markEdited(String messageId, {bool edited = true}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.markEdited',
        () => _dao.markEdited(messageId, edited: edited),
      );

  /// Hard-deletes soft-deleted messages older than [olderThan].
  Future<Result<List<MessageRow>>> purgeDeleted(
    DateTime olderThan, {
    int limit = 500,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.purgeDeleted',
    () => _dao.purgeDeleted(olderThan, limit: limit),
  );

  Future<Result<int>> countMessages({String? channelId}) => ResultGuards.guard(
    _logger,
    '$_tag.countMessages',
    () => _dao.countMessages(channelId: channelId),
  );

  // ---- Attachments --------------------------------------------------------------

  Future<Result<AttachmentRow?>> getAttachment(String attachmentId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getAttachment',
        () => _dao.getAttachment(attachmentId),
      );

  Future<Result<List<AttachmentRow>>> listAttachments(String messageId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.listAttachments',
        () => _dao.listAttachments(messageId),
      );

  Future<Result<int>> insertAttachment(AttachmentRow row) => ResultGuards.guard(
    _logger,
    '$_tag.insertAttachment',
    () => _dao.insertAttachment(row),
  );

  Future<Result<int>> deleteAttachment(String attachmentId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.deleteAttachment',
        () => _dao.deleteAttachment(attachmentId),
      );

  // ---- Voice notes ----------------------------------------------------------------

  Future<Result<VoiceNoteRow?>> getVoiceNote(String voiceNoteId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getVoiceNote',
        () => _dao.getVoiceNote(voiceNoteId),
      );

  Future<Result<int>> insertVoiceNote(VoiceNoteRow row) => ResultGuards.guard(
    _logger,
    '$_tag.insertVoiceNote',
    () => _dao.insertVoiceNote(row),
  );

  // ---- Receipts ---------------------------------------------------------------------

  Future<Result<int>> insertDeliveryReceipt(DeliveryReceiptRow row) =>
      ResultGuards.guard(
        _logger,
        '$_tag.insertDeliveryReceipt',
        () => _dao.insertDeliveryReceipt(row),
      );

  Future<Result<int>> insertReadReceipt(ReadReceiptRow row) =>
      ResultGuards.guard(
        _logger,
        '$_tag.insertReadReceipt',
        () => _dao.insertReadReceipt(row),
      );

  Future<Result<List<DeliveryReceiptRow>>> deliveryReceiptsFor(
    String messageId,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.deliveryReceiptsFor',
    () => _dao.deliveryReceiptsFor(messageId),
  );

  Future<Result<List<ReadReceiptRow>>> readReceiptsFor(String messageId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.readReceiptsFor',
        () => _dao.readReceiptsFor(messageId),
      );
}
