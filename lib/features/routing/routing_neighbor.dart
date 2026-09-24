/// I8.2 — A directly reachable peer that can serve as a next hop.
///
/// A routing neighbor is a peer that:
/// - Is currently connected via BLE (I7 connection layer)
/// - Is authenticated (cryptographic proof of key possession)
/// - Is trusted (user explicitly granted trust)
///
/// The neighbor table represents the local node's direct neighborhood.
/// This is the foundation for route computation.
///
/// Key principle: Routing must NOT create connections.
/// This model consumes I7 connection/peer availability.
library;

import 'package:onebit/features/routing/routing_node.dart';
class RoutingNeighbor {
  const RoutingNeighbor({
    required this.peerId,
    required this.status,
    required this.lastSeenAt,
    this.displayName,
    this.rssi,
    this.hopCount = 1,
    this.bleDeviceId,
  });

  /// Cryptographic identity of the neighbor.
  final String peerId;

  /// The neighbor's eligibility status for routing.
  final NeighborStatus status;

  /// When this neighbor was last confirmed reachable.
  final DateTime lastSeenAt;

  /// Human-readable name, if known.
  final String? displayName;

  /// Signal strength, if available from BLE layer.
  final int? rssi;

  /// Hop count to reach this neighbor (always 1 for direct neighbors).
  final int hopCount;

  /// BLE device ID (MAC address) for the current connection.
  /// This is a runtime detail, not used as routing identity.
  final String? bleDeviceId;

  /// Whether this neighbor is currently eligible for routing.
  bool get isEligible => status == NeighborStatus.active;

  /// Whether this neighbor was previously active but is now lost.
  bool get isLost => status == NeighborStatus.lost;

  RoutingNeighbor copyWith({
    NeighborStatus? status,
    DateTime? lastSeenAt,
    String? displayName,
    int? rssi,
    int? hopCount,
    String? bleDeviceId,
  }) {
    return RoutingNeighbor(
      peerId: peerId,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      displayName: displayName ?? this.displayName,
      rssi: rssi ?? this.rssi,
      hopCount: hopCount ?? this.hopCount,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingNeighbor &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(peerId, status);

  @override
  String toString() =>
      'RoutingNeighbor(${peerId.substring(0, 8)}..., '
      'status=${status.name}, '
      'hopCount=$hopCount)';
}
