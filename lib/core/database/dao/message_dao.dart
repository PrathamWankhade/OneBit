import 'package:drift/drift.dart';

import '../database.dart';
import '../models/page.dart';
import '../query/message_query.dart';
import '../query/page_request.dart';
import '../tables/enums.dart';
import '../tables/message_tables.dart';

part 'message_dao.g.dart';

/// Typed persistence for messages, attachments, voice notes and receipts.
@DriftAccessor(
  tables: [Messages, Attachments, VoiceNotes, DeliveryReceipts, ReadReceipts],
)
final class MessageDao extends DatabaseAccessor<OneBitDatabase>
    with _$MessageDaoMixin {
  MessageDao(super.db);

  @override
  $MessagesTable get messages => db.messages;

  @override
  $AttachmentsTable get attachments => db.attachments;

  @override
  $VoiceNotesTable get voiceNotes => db.voiceNotes;

  @override
  $DeliveryReceiptsTable get deliveryReceipts => db.deliveryReceipts;

  @override
  $ReadReceiptsTable get readReceipts => db.readReceipts;

  // ---- Messages --------------------------------------------------------------

  Future<MessageRow?> getMessage(String messageId) => (select(
    messages,
  )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();

  /// Timeline page for a channel, newest-first by default.
  Future<Page<MessageRow>> pageChannelMessages(
    String channelId, {
    PageRequest request = const PageRequest(),
    DateTime? before,
  }) async {
    final query = select(messages)
      ..where((t) {
        var condition = t.channelId.equals(channelId) & t.deleted.equals(false);
        if (before != null) {
          condition =
              condition &
              t.timestamp.isSmallerThanValue(before.millisecondsSinceEpoch);
        }
        return condition;
      });
    return _fetchPage(query, request);
  }

  /// Messages matching [MessageQuery], newest-first.
  Future<Page<MessageRow>> queryMessages(
    MessageQuery queryModel, {
    PageRequest request = const PageRequest(),
  }) async {
    final query = select(messages);

    final channelId = queryModel.channelId;
    if (channelId != null) {
      query.where((t) => t.channelId.equals(channelId));
    }

    final sender = queryModel.sender;
    if (sender != null) {
      query.where((t) => t.sender.equals(sender));
    }

    final text = queryModel.text;
    if (text != null && text.trim().isNotEmpty) {
      final pattern = '%${_escapeLike(text.trim())}%';
      query.where(
        (t) =>
            t.sender.like(pattern, escapeChar: '\\') |
            t.messageId.like(pattern, escapeChar: '\\'),
      );
    }

    final status = queryModel.status;
    if (status != null) {
      query.where((t) => t.status.equalsValue(status));
    }

    final messageType = queryModel.messageType;
    if (messageType != null) {
      query.where((t) => t.messageType.equalsValue(messageType));
    }

    final before = queryModel.before;
    if (before != null) {
      query.where(
        (t) => t.timestamp.isSmallerThanValue(before.millisecondsSinceEpoch),
      );
    }

    final after = queryModel.after;
    if (after != null) {
      query.where(
        (t) => t.timestamp.isBiggerThanValue(after.millisecondsSinceEpoch),
      );
    }

    if (!queryModel.includeDeleted) {
      query.where((t) => t.deleted.equals(false));
    }

    return _fetchPage(query, request);
  }

  Future<Page<MessageRow>> _fetchPage(
    SimpleSelectStatement<$MessagesTable, MessageRow> query,
    PageRequest request,
  ) async {
    final offset = request.offset;
    final limit = request.limit.clamp(1, PageRequest.maxLimit);
    query
      ..orderBy([
        (t) => request.order == PageOrder.descending
            ? OrderingTerm.desc(t.timestamp)
            : OrderingTerm.asc(t.timestamp),
        // Tie-break for identical timestamps (stable pagination).
        (t) => request.order == PageOrder.descending
            ? OrderingTerm.desc(t.messageId)
            : OrderingTerm.asc(t.messageId),
      ])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    final hasMore = rows.length == limit;
    return Page(items: rows, offset: offset, limit: limit, hasMore: hasMore);
  }

  Stream<List<MessageRow>> watchChannelMessages(
    String channelId, {
    int limit = 100,
  }) =>
      (select(messages)
            ..where(
              (t) => t.channelId.equals(channelId) & t.deleted.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.timestamp),
              (t) => OrderingTerm.desc(t.messageId),
            ])
            ..limit(limit))
          .watch();

  Future<int> insertMessage(MessageRow row) =>
      into(messages).insert(row, mode: InsertMode.insertOrIgnore);

  Future<void> insertAllMessages(List<MessageRow> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(messages, rows);
  });

  Future<int> updateMessage(MessageRow row) =>
      into(messages).insertOnConflictUpdate(row);

  Future<int> setMessageStatus(String messageId, MessageStatus status) =>
      (update(messages)..where((t) => t.messageId.equals(messageId))).write(
        MessagesCompanion(status: Value(status)),
      );

  Future<int> markDeleted(String messageId, {bool deleted = true}) =>
      (update(messages)..where((t) => t.messageId.equals(messageId))).write(
        MessagesCompanion(deleted: Value(deleted)),
      );

  Future<int> markEdited(String messageId, {bool edited = true}) =>
      (update(messages)..where((t) => t.messageId.equals(messageId))).write(
        MessagesCompanion(edited: Value(edited)),
      );

  /// Soft-deleted messages older than [olderThan], bounded by [limit].
  ///
  /// Deletes them and returns the removed rows.
  Future<List<MessageRow>> purgeDeleted(
    DateTime olderThan, {
    int limit = 500,
  }) async {
    final found =
        await (select(messages)
              ..where(
                (t) =>
                    t.deleted.equals(true) &
                    t.timestamp.isSmallerThanValue(
                      olderThan.millisecondsSinceEpoch,
                    ),
              )
              ..limit(limit))
            .get();
    if (found.isNotEmpty) {
      await (delete(
        messages,
      )..where((t) => t.messageId.isIn(found.map((m) => m.messageId)))).go();
    }
    return found;
  }

  Future<int> countMessages({String? channelId}) async {
    final query = selectOnly(messages)..addColumns([countAll()]);
    if (channelId != null) {
      query.where(messages.channelId.equals(channelId));
    }
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  // ---- Attachments --------------------------------------------------------------

  Future<AttachmentRow?> getAttachment(String attachmentId) => (select(
    attachments,
  )..where((t) => t.attachmentId.equals(attachmentId))).getSingleOrNull();

  Future<List<AttachmentRow>> listAttachments(String messageId) =>
      (select(attachments)
            ..where((t) => t.messageId.equals(messageId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insertAttachment(AttachmentRow row) =>
      into(attachments).insert(row, mode: InsertMode.insertOrIgnore);

  Future<int> deleteAttachment(String attachmentId) => (delete(
    attachments,
  )..where((t) => t.attachmentId.equals(attachmentId))).go();

  // ---- Voice notes ----------------------------------------------------------------

  Future<VoiceNoteRow?> getVoiceNote(String voiceNoteId) => (select(
    voiceNotes,
  )..where((t) => t.voiceNoteId.equals(voiceNoteId))).getSingleOrNull();

  Future<int> insertVoiceNote(VoiceNoteRow row) =>
      into(voiceNotes).insert(row, mode: InsertMode.insertOrIgnore);

  // ---- Receipts ---------------------------------------------------------------------

  Future<int> insertDeliveryReceipt(DeliveryReceiptRow row) =>
      into(deliveryReceipts).insert(row, mode: InsertMode.insertOrIgnore);

  Future<int> insertReadReceipt(ReadReceiptRow row) =>
      into(readReceipts).insert(row, mode: InsertMode.insertOrIgnore);

  Future<List<DeliveryReceiptRow>> deliveryReceiptsFor(String messageId) =>
      (select(deliveryReceipts)
            ..where((t) => t.messageId.equals(messageId))
            ..orderBy([(t) => OrderingTerm.asc(t.deliveredAt)]))
          .get();

  Future<List<ReadReceiptRow>> readReceiptsFor(String messageId) =>
      (select(readReceipts)
            ..where((t) => t.messageId.equals(messageId))
            ..orderBy([(t) => OrderingTerm.asc(t.readAt)]))
          .get();

  /// Escapes `\`, `%` and `_` so user input is matched literally in LIKE.
  static String _escapeLike(String input) => input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
