import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// Why a relay dropped a packet (counted by the statistics tracker).
enum RelayDropReason {
  /// TTL hit zero before delivery.
  ttlExpired,

  /// The packet was already seen (duplicate detection).
  duplicate,

  /// Re-entering the node's own path (loop prevention).
  loop,

  /// No route and no neighbor can carry it.
  noRoute,

  /// The packet is one we originated (echo should not re-enter).
  ownPacket,

  /// The relay queue was full.
  queueFull,

  /// The engine is not running.
  inactive,
}

/// The outcome of a relay pipeline pass.
sealed class RelayDecision {
  const RelayDecision();
}

/// Deliver to the local node (higher layers own the payload).
final class DeliverUp extends RelayDecision {
  const DeliverUp(this.packet);

  final MeshPacket packet;
}

/// Forward a copy toward the destination.
final class ForwardPacket extends RelayDecision {
  const ForwardPacket({required this.nextHop, required this.packet});

  final String nextHop;
  final MeshPacket packet;
}

/// Drop with a reason.
final class DropPacket extends RelayDecision {
  const DropPacket(this.packet, this.reason);

  final MeshPacket packet;
  final RelayDropReason reason;
}
