/// I9.2 — Transport-oriented message envelope.
///
/// The canonical representation of a OneBit application message as it
/// moves between nodes. Separates delivery metadata from application
/// payload. The envelope describes how a message is identified and
/// delivered; the payload contains application-level data that the
/// routing layer never inspects.
///
/// ## Wire Format (via MessageEnvelopeCodec)
///
/// ```text
/// [version: 1B]
/// [messageId: 16B]
/// [sourcePeerId: 32B]
/// [destinationPeerId: 32B]
/// [payloadLength: 4B]
/// [payload: NB]
/// ```
///
/// Total header overhead: 85 bytes.
///
/// ## Immutability
///
/// Identity fields ([messageId], [sourcePeerId], [destinationPeerId])
/// are immutable after creation. The envelope never becomes the route.
/// A relay does not become the source.
library;

import 'dart:typed_data';

import 'package:onebit/features/message/models/message_id.dart';

/// Protocol version for message envelopes.
const int messageProtocolVersion = 1;

/// Maximum payload size in bytes.
const int maxMessagePayloadSize = 4096;

/// Canonical PeerId size in hex characters.
const int peerIdHexLength = 64;

/// Canonical PeerId size in raw bytes.
const int peerIdByteSize = 32;

/// A transport-oriented envelope wrapping a message payload.
///
/// Contains only the fields required for delivery routing and
/// identification. Does not include application semantics, routing
/// metrics, BLE identifiers, or session information.
class MessageEnvelope {
  const MessageEnvelope({
    required this.protocolVersion,
    required this.messageId,
    required this.sourcePeerId,
    required this.destinationPeerId,
    required this.payload,
  });

  /// Protocol version for forward/backward compatibility.
  final int protocolVersion;

  /// The message's unique logical identifier.
  final MessageId messageId;

  /// The original sender's PeerId (64-char hex string).
  final String sourcePeerId;

  /// The intended recipient's PeerId (64-char hex string).
  final String destinationPeerId;

  /// The application payload — opaque to the routing layer.
  final Uint8List payload;

  /// Whether this envelope has valid structure.
  bool get isValid {
    if (protocolVersion != messageProtocolVersion) return false;
    if (sourcePeerId.length != peerIdHexLength) return false;
    if (destinationPeerId.length != peerIdHexLength) return false;
    if (payload.length > maxMessagePayloadSize) return false;
    return true;
  }

  /// Total serialized size in bytes (header + payload).
  int get estimatedSize =>
      1 + // version
      messageIdByteSize + // messageId
      peerIdByteSize + // sourcePeerId
      peerIdByteSize + // destinationPeerId
      4 + // payloadLength
      payload.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEnvelope &&
          runtimeType == other.runtimeType &&
          protocolVersion == other.protocolVersion &&
          messageId == other.messageId &&
          sourcePeerId == other.sourcePeerId &&
          destinationPeerId == other.destinationPeerId;

  @override
  int get hashCode => Object.hash(
        protocolVersion,
        messageId,
        sourcePeerId,
        destinationPeerId,
      );

  @override
  String toString() {
    final src = sourcePeerId.length >= 8
        ? sourcePeerId.substring(0, 8)
        : sourcePeerId;
    final dst = destinationPeerId.length >= 8
        ? destinationPeerId.substring(0, 8)
        : destinationPeerId;
    return 'MessageEnvelope(v$protocolVersion, '
        'msg=${messageId.toHexString().substring(0, 8)}..., '
        'src=$src..., dst=$dst..., '
        'payload=${payload.length}B)';
  }
}
