import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/message_mapper.dart';
import 'package:onebit/features/messaging/domain/delivery/delivery_receipt.dart';
import 'package:onebit/features/messaging/domain/messages/message_ordering.dart';
import 'package:onebit/features/messaging/domain/receipts/read_receipt.dart';
import 'package:onebit/features/messaging/domain/receipts/receipt_repository.dart';

/// Drift-backed [ReceiptRepository] (delivery + read acknowledgements).
final class SqliteReceiptRepository implements ReceiptRepository {
  SqliteReceiptRepository({required this._db, required this.logger});

  final OneBitDatabase _db;
  final AppLogger logger;
  static const _tag = LogTags.messaging;

  $DeliveryReceiptsTable get _deliveries => _db.deliveryReceipts;
  $ReadReceiptsTable get _reads => _db.readReceipts;

  @override
  Future<Result<DeliveryReceipt>> saveDelivery(DeliveryReceipt receipt) =>
      ResultGuards.guard(logger, '$_tag.saveDelivery', () async {
        final existing = await (_db.select(
          _deliveries,
        )..where((t) => t.messageId.equals(receipt.messageId))).get();
        final already = existing.any((row) => row.node == receipt.node);
        await _db
            .into(_deliveries)
            .insert(
              DeliveryReceiptsCompanion.insert(
                receiptId: receipt.receiptId,
                messageId: receipt.messageId,
                node: receipt.node,
                deliveredAt: receipt.deliveredAt,
                state: Value(MessageMapper.toCoreReceiptState(receipt.state)),
                metadata: Value(receipt.metadata),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        final row = await (_db.select(
          _deliveries,
        )..where((t) => t.receiptId.equals(receipt.receiptId))).getSingle();
        return MessageMapper.deliveryToDomain(row).copyWith(
          state: already
              ? DeliveryReceiptState.duplicate
              : MessageMapper.deliveryToDomain(row).state,
        );
      });

  @override
  Future<Result<void>> setDeliveryState(
    String receiptId, {
    required DeliveryReceiptState state,
  }) => ResultGuards.guard(logger, '$_tag.setDeliveryState', () async {
    await (_db.update(
      _deliveries,
    )..where((t) => t.receiptId.equals(receiptId))).write(
      DeliveryReceiptsCompanion(
        state: Value(MessageMapper.toCoreReceiptState(state)),
      ),
    );
  });

  @override
  Future<Result<DeliveryReceipt?>> deliveryFor(String messageId, String node) =>
      ResultGuards.guard(logger, '$_tag.deliveryFor', () async {
        final row =
            await (_db.select(_deliveries)..where(
                  (t) => t.messageId.equals(messageId) & t.node.equals(node),
                ))
                .getSingleOrNull();
        return row == null ? null : MessageMapper.deliveryToDomain(row);
      });

  @override
  Future<Result<List<DeliveryReceipt>>> deliveriesFor(String messageId) =>
      ResultGuards.guard(logger, '$_tag.deliveriesFor', () async {
        final rows =
            await (_db.select(_deliveries)
                  ..where((t) => t.messageId.equals(messageId))
                  ..orderBy([(t) => OrderingTerm.desc(t.deliveredAt)]))
                .get();
        return rows.map(MessageMapper.deliveryToDomain).toList();
      });

  @override
  Future<Result<void>> saveRead(ReadReceipt receipt) =>
      ResultGuards.guard(logger, '$_tag.saveRead', () async {
        await _db
            .into(_reads)
            .insert(
              ReadReceiptsCompanion.insert(
                receiptId: receipt.receiptId,
                messageId: receipt.messageId,
                node: receipt.node,
                readAt: receipt.readAt,
                device: Value(receipt.device),
                version: Value(receipt.version),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      });

  @override
  Future<Result<List<ReadReceipt>>> readFor(String messageId) =>
      ResultGuards.guard(logger, '$_tag.readFor', () async {
        final rows =
            await (_db.select(_reads)
                  ..where((t) => t.messageId.equals(messageId))
                  ..orderBy([(t) => OrderingTerm.asc(t.readAt)]))
                .get();
        return rows.map(_toRead).toList();
      });

  @override
  Future<Result<List<ReadReceipt>>> readCursorForChannel(String channelId) =>
      ResultGuards.guard(logger, '$_tag.readCursorForChannel', () async {
        // Newest read receipt per node within this channel. A join through
        // drift's composable API emitted an unqualified `channel_id`, so this
        // stays explicit SQL (same style as applyReadCursor).
        final rows = await _db
            .customSelect(
              '''
SELECT r.receipt_id, r.message_id, r.node, r.read_at, r.device, r.version
FROM read_receipts r
JOIN messages m ON m.message_id = r.message_id
WHERE m.channel_id = ? AND m.deleted = 0
ORDER BY r.read_at DESC, r.receipt_id DESC
''',
              variables: [Variable.withString(channelId)],
            )
            .get();
        final byNode = <String, ReadReceipt>{};
        for (final row in rows) {
          final receipt = ReadReceiptRow(
            receiptId: row.read<String>('receipt_id'),
            messageId: row.read<String>('message_id'),
            node: row.read<String>('node'),
            readAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('read_at'),
            ),
            device: row.read<String?>('device'),
            version: row.read<int>('version'),
          );
          byNode.putIfAbsent(receipt.node, () => _toRead(receipt));
        }
        return byNode.values.toList();
      });

  @override
  Stream<Result<List<ReadReceipt>>> watchReadFor(String messageId) {
    final query = (_db.select(_reads)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([(t) => OrderingTerm.asc(t.readAt)]));
    return ResultGuards.guardWatch(
      logger,
      '$_tag.watchReadFor($messageId)',
      query.watch().map((rows) => rows.map(_toRead).toList()),
    );
  }

  @override
  Future<Result<int>> applyReadCursor({
    required String channelId,
    required String readerNode,
    required MessageOrderKey through,
    DateTime? readAt,
    String? device,
    int version = 1,
  }) => ResultGuards.guard(logger, '$_tag.applyReadCursor', () async {
    final at = readAt ?? DateTime.now();
    final throughMs = through.timestamp.millisecondsSinceEpoch;
    final receiptIdPrefix = 'read:$readerNode';

    // Insert one read receipt row per outbound message older than the
    // cursor (idempotent by the derived receipt id). Only messages this node
    // sent count as "read by the peer".
    await _db.customStatement(
      '''
INSERT OR IGNORE INTO read_receipts
  (receipt_id, message_id, node, read_at, device, version)
SELECT ? || ':' || m.message_id, m.message_id, ?, ?, ?, ?
FROM messages m
WHERE m.channel_id = ?
  AND m.sender = ?
  AND m.deleted = 0
  AND m.read_at IS NULL
  AND (m.timestamp < ? OR
       (m.timestamp = ? AND (m.sequence < ? OR
         (m.sequence = ? AND m.message_id <= ?))))
''',
      [
        receiptIdPrefix,
        readerNode,
        at.millisecondsSinceEpoch,
        device,
        version,
        channelId,
        readerNode,
        throughMs,
        throughMs,
        through.sequence,
        through.sequence,
        through.messageId,
      ],
    );

    // Mirror of the local markReadThrough: every inbound message from that
    // peer read through the cursor becomes read, whatever its prior status.
    final updated = await _db.customUpdate(
      '''
UPDATE messages
SET status = 'read'
WHERE channel_id = ?
  AND sender = ?
  AND deleted = 0
  AND (timestamp < ? OR
       (timestamp = ? AND (sequence < ? OR
         (sequence = ? AND message_id <= ?))))
''',
      variables: [
        Variable(channelId),
        Variable(readerNode),
        Variable(throughMs),
        Variable(throughMs),
        Variable(through.sequence),
        Variable(through.sequence),
        Variable(through.messageId),
      ],
    );
    return updated;
  });

  @override
  Future<Result<ReadReceipt?>> latestReadFor(String messageId, String node) =>
      ResultGuards.guard(logger, '$_tag.latestReadFor', () async {
        final rows =
            await (_db.select(_reads)
                  ..where(
                    (t) => t.messageId.equals(messageId) & t.node.equals(node),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.readAt)])
                  ..limit(1))
                .get();
        return rows.isEmpty ? null : _toRead(rows.single);
      });

  ReadReceipt _toRead(ReadReceiptRow row) => ReadReceipt(
    receiptId: row.receiptId,
    messageId: row.messageId,
    node: row.node,
    device: row.device,
    version: row.version,
    readAt: row.readAt,
  );
}
