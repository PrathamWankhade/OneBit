import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';

/// Maps messaging priorities onto the DTN priority ladder.
///
/// This is the only place the two domains' priority vocabularies meet; the
/// messaging domain never imports the DTN domain directly.
abstract final class DtnPriorityMapper {
  const DtnPriorityMapper._();

  static DtnPriority toDtn(MessagePriority priority) => switch (priority) {
    MessagePriority.urgent => DtnPriority.critical,
    MessagePriority.high => DtnPriority.high,
    MessagePriority.normal => DtnPriority.normal,
    MessagePriority.low => DtnPriority.low,
  };
}

/// Builders for app-level envelopes handed to the DTN store.
abstract final class MessengerEnvelopeDefaults {
  const MessengerEnvelopeDefaults._();

  /// TTL of a message envelope.
  static const int messageTtlSeconds = 24 * 3600;

  /// TTL of a receipt envelope.
  static const int receiptTtlSeconds = 6 * 3600;

  /// TTL of a typing envelope.
  static const int typingTtlSeconds = 30;

  /// Envelope id for an outbound app-level packet: unique at this node
  /// without coordination with the DTN layer.
  static String packetId(String localNodeId, DateTime now) =>
      'm:$localNodeId:${now.microsecondsSinceEpoch.toRadixString(36)}';

  static DtnPacket messagePacket({
    required String packetId,
    required String source,
    required String destination,
    required List<int> payload,
    required MessagePriority priority,
    required DateTime now,
    int ttlSeconds = messageTtlSeconds,
  }) => DtnPacket(
    packetId: packetId,
    source: source,
    destination: destination,
    payload: payload,
    priority: DtnPriorityMapper.toDtn(priority),
    direction: DtnDirection.outbound,
    ttlSeconds: ttlSeconds,
    createdAt: now,
    expiresAt: now.add(Duration(seconds: ttlSeconds)),
  );

  static DtnPacket receiptPacket({
    required String packetId,
    required String source,
    required String destination,
    required List<int> payload,
    required DateTime now,
  }) => DtnPacket(
    packetId: packetId,
    source: source,
    destination: destination,
    payload: payload,
    priority: DtnPriority.low,
    direction: DtnDirection.outbound,
    ttlSeconds: receiptTtlSeconds,
    createdAt: now,
    expiresAt: now.add(const Duration(seconds: receiptTtlSeconds)),
  );
}
