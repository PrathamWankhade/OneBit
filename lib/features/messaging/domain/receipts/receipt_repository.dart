import 'package:onebit/core/result/result.dart';

import '../delivery/delivery_receipt.dart';
import '../messages/message_ordering.dart';
import 'read_receipt.dart';

/// Contract for delivery + read receipt persistence.
///
/// Implementations: drift-backed and in-memory fakes for tests. Both
/// receipt kinds are idempotent at store time (unique keys), so duplicate
/// wire envelopes never double-record.
abstract interface class ReceiptRepository {
  // ---- Delivery receipts ----------------------------------------------------

  /// Stores a delivery receipt, dropping duplicates by
  /// (messageId, node) idempotency. Returns the stored row — `state` is
  /// `duplicate` when the (messageId, node) pair was already recorded.
  Future<Result<DeliveryReceipt>> saveDelivery(DeliveryReceipt receipt);

  /// Advances the persisted lifecycle state of a receipt envelope.
  Future<Result<void>> setDeliveryState(
    String receiptId, {
    required DeliveryReceiptState state,
  });

  Future<Result<DeliveryReceipt?>> deliveryFor(String messageId, String node);

  Future<Result<List<DeliveryReceipt>>> deliveriesFor(String messageId);

  // ---- Read receipts --------------------------------------------------------

  /// Stores a read receipt, dropping duplicates by
  /// (messageId, node, device) idempotency.
  Future<Result<void>> saveRead(ReadReceipt receipt);

  Future<Result<List<ReadReceipt>>> readFor(String messageId);

  /// Streams the read receipts of one message (drives per-message UI state).
  Stream<Result<List<ReadReceipt>>> watchReadFor(String messageId);

  /// The latest read receipt for (messageId, node), if any.
  Future<Result<ReadReceipt?>> latestReadFor(String messageId, String node);

  /// Latest read receipt per node for the given channel (the read cursor).
  Future<Result<List<ReadReceipt>>> readCursorForChannel(String channelId);

  /// Applies a peer's read cursor: records one read receipt per outbound
  /// message read through [through] and advances those messages to `read`
  /// (forward-only). Returns the number of messages marked read.
  Future<Result<int>> applyReadCursor({
    required String channelId,
    required String readerNode,
    required MessageOrderKey through,
    DateTime? readAt,
    String? device,
    int version = 1,
  });
}
