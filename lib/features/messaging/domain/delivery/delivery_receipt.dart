import 'package:flutter/foundation.dart';

/// Lifecycle of a delivery receipt as it moves toward the sender.
enum DeliveryReceiptState {
  /// The receipt is being constructed.
  queued,

  /// Ready and persisted.
  sent,

  /// Travelling through relay nodes.
  relayed,

  /// Applied by the sender node.
  delivered,

  /// The message this receipt refers to was read.
  read,

  /// The receipt could not be delivered.
  failed,

  /// A duplicate receipt for the same (messageId, node) was dropped.
  duplicate;

  String get wireName => name;
}

/// A delivery acknowledgement: node [node] confirms it received [messageId].
@immutable
final class DeliveryReceipt {
  const DeliveryReceipt({
    required this.receiptId,
    required this.messageId,
    required this.node,
    required this.deliveredAt,
    this.state = DeliveryReceiptState.sent,
    this.metadata,
  });

  /// Stable id: `delivery:<messageId>:<node>` (idempotency key).
  final String receiptId;

  final String messageId;

  /// The node that received the message.
  final String node;

  final DateTime deliveredAt;

  final DeliveryReceiptState state;

  /// Opaque developer metadata (JSON string).
  final String? metadata;

  DeliveryReceipt copyWith({DeliveryReceiptState? state, String? metadata}) =>
      DeliveryReceipt(
        receiptId: receiptId,
        messageId: messageId,
        node: node,
        deliveredAt: deliveredAt,
        state: state ?? this.state,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      other is DeliveryReceipt && other.receiptId == receiptId;

  @override
  int get hashCode => receiptId.hashCode;
}
