import 'package:flutter/foundation.dart';

/// Machine metadata of a message that does not belong in the timeline row:
/// idempotency keys, DTN envelope wiring and retry bookkeeping.
@immutable
final class MessageMetadata {
  const MessageMetadata({
    this.clientId,
    this.packetId,
    this.attemptCount = 0,
    this.lastError,
    this.payloadJson,
    this.verifiedAt,
  });

  /// Client-side idempotency key (stable across retries).
  final String? clientId;

  /// The DTN envelope that carries (outbound) or carried (inbound) the message.
  final String? packetId;

  /// Number of retry attempts performed so far.
  final int attemptCount;

  /// Human-readable reason of the latest failed attempt.
  final String? lastError;

  /// Rendering of the original wire payload (developer diagnostics).
  final String? payloadJson;

  /// When the receipt chain verified this message.
  final DateTime? verifiedAt;

  MessageMetadata copyWith({
    String? clientId,
    String? packetId,
    int? attemptCount,
    String? lastError,
    String? payloadJson,
    DateTime? verifiedAt,
  }) => MessageMetadata(
    clientId: clientId ?? this.clientId,
    packetId: packetId ?? this.packetId,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError ?? this.lastError,
    payloadJson: payloadJson ?? this.payloadJson,
    verifiedAt: verifiedAt ?? this.verifiedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is MessageMetadata && other.clientId == clientId;

  @override
  int get hashCode => clientId.hashCode;
}
