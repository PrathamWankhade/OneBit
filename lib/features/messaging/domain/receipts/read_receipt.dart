import 'package:flutter/foundation.dart';

/// A read acknowledgement recorded by the sender.
///
/// Reader identity is (node, device, version) so a future multi-device
/// phase can render per-device read state.
@immutable
final class ReadReceipt {
  const ReadReceipt({
    required this.receiptId,
    required this.messageId,
    required this.node,
    required this.readAt,
    this.device,
    this.version = 1,
  });

  /// Stable id: `read:<messageId>:<node>[:<device>]` (idempotency key).
  final String receiptId;

  final String messageId;

  /// The node whose user read the message.
  final String node;

  /// Optional device tag of the reader.
  final String? device;

  /// Reader software version.
  final int version;

  final DateTime readAt;

  @override
  bool operator ==(Object other) =>
      other is ReadReceipt && other.receiptId == receiptId;

  @override
  int get hashCode => receiptId.hashCode;
}
