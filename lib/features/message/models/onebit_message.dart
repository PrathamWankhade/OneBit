/// I9.1 — Core message domain model.
///
/// Represents a OneBit application message with immutable identity
/// and mutable delivery state. The message knows who sent it and
/// who it is ultimately for; I8 determines where it should go next.
///
/// ## Identity Invariants
///
/// - [id] is immutable and unique
/// - [sourcePeerId] never changes (original sender preserved)
/// - [destinationPeerId] never changes (failed route ≠ changed destination)
/// - [state] transitions produce new instances (immutability preserved)
///
/// ## Separation from Routing
///
/// A message does not permanently contain a route. The delivery
/// service resolves the current next hop at transmission time.
/// If the route changes, the same message can use the new route.
library;

import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';

/// A OneBit application message.
///
/// Immutable identity fields ([id], [sourcePeerId], [destinationPeerId])
/// never change. The [state] transitions via [copyWith] to produce
/// new instances while preserving identity.
class OneBitMessage {
  /// Create a new message in [MessageState.created] state.
  const OneBitMessage({
    required this.id,
    required this.sourcePeerId,
    required this.destinationPeerId,
    this.state = MessageState.created,
    required this.createdAt,
    this.expiresAt,
    this.payloadSizeBytes,
  });

  /// Unique logical identifier — immutable.
  final MessageId id;

  /// The original sender's PeerId — immutable.
  ///
  /// When a relay node forwards this message, [sourcePeerId]
  /// remains the original sender, not the relay.
  final String sourcePeerId;

  /// The intended recipient's PeerId — immutable.
  ///
  /// A failed route does not change the destination.
  /// The delivery service re-resolves the route if needed.
  final String destinationPeerId;

  /// Current delivery lifecycle state.
  final MessageState state;

  /// When this message was created (UTC).
  final DateTime createdAt;

  /// Absolute expiration time, if set.
  ///
  /// Message expiration is independent from route expiration.
  /// A route can expire while the message remains valid, and
  /// vice versa.
  final DateTime? expiresAt;

  /// Size of the application payload in bytes, if known.
  ///
  /// Used for size validation against transport limits.
  final int? payloadSizeBytes;

  /// Whether this message targets the local node.
  bool isLocalTo(String localPeerId) =>
      destinationPeerId == localPeerId;

  /// Whether this message has expired.
  bool isExpired({DateTime? now}) {
    if (expiresAt == null) return false;
    return (now ?? DateTime.now()).isAfter(expiresAt!);
  }

  /// Whether the message is in a terminal state.
  bool get isTerminal =>
      state == MessageState.delivered ||
      state == MessageState.failed ||
      state == MessageState.expired ||
      state == MessageState.rejected;

  /// Whether the message can still be processed.
  bool get isActive => !isTerminal;

  /// Create a copy with updated fields.
  ///
  /// Identity fields ([id], [sourcePeerId], [destinationPeerId])
  /// cannot be changed — they are always passed through.
  OneBitMessage copyWith({
    MessageState? state,
    DateTime? expiresAt,
    int? payloadSizeBytes,
  }) {
    return OneBitMessage(
      id: id,
      sourcePeerId: sourcePeerId,
      destinationPeerId: destinationPeerId,
      state: state ?? this.state,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      payloadSizeBytes: payloadSizeBytes ?? this.payloadSizeBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneBitMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    final src = sourcePeerId.length >= 8
        ? sourcePeerId.substring(0, 8)
        : sourcePeerId;
    final dst = destinationPeerId.length >= 8
        ? destinationPeerId.substring(0, 8)
        : destinationPeerId;
    return 'OneBitMessage(id=${id.value.substring(0, 8)}..., '
        'src=$src..., dst=$dst..., '
        'state=${state.name})';
  }
}
