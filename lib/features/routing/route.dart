/// I8.5/I8.8 — A route entry in the routing table.
///
/// A route maps a destination to a next hop and a metric.
/// Routes are peer/identity scoped — never use BLE addresses as destination.
///
/// Example:
/// ```text
/// Destination: Peer C
/// Next Hop:    Peer B
/// Metric:      2 (hop count)
/// ```
///
/// Key principles:
/// - Routes are cryptographically identity-aware
/// - Route information from the network is untrusted
/// - Routes have validity and expiration
/// - Multiple routes to the same destination are supported
library;

/// The source of a route entry.
///
/// Routes can be learned from different sources, which affects
/// how they are validated and expired.
enum RouteSource {
  /// Route to a directly connected neighbor (always metric 1).
  direct,

  /// Route learned from a neighbor's routing advertisement.
  advertised,

  /// Route manually configured (for testing or static routing).
  static,
}

/// The validity state of a route.
///
/// Routes transition through states based on topology changes.
enum RouteState {
  /// Route is valid and can be used for next-hop selection.
  active,

  /// Route's next hop is unreachable; route may recover.
  stale,

  /// Route is confirmed invalid and should be removed.
  invalid,
}

/// A single route entry in the routing table.
///
/// Represents: "To reach [destinationPeerId], go via [nextHopPeerId]
/// with metric [metric]."
class Route {
  const Route({
    required this.destinationPeerId,
    required this.nextHopPeerId,
    required this.metric,
    required this.state,
    required this.source,
    required this.createdAt,
    required this.lastValidatedAt,
    this.originPeerId,
    this.sequenceNumber,
    this.expiresAt,
  });

  /// The destination this route reaches (cryptographic identity).
  final String destinationPeerId;

  /// The next hop to forward toward the destination.
  /// Must be a direct neighbor (in the neighbor table).
  final String nextHopPeerId;

  /// Routing metric (currently hop count).
  /// Lower is better. Direct neighbors have metric 1.
  final int metric;

  /// Current validity state of this route.
  final RouteState state;

  /// How this route was learned.
  final RouteSource source;

  /// When this route was first created.
  final DateTime createdAt;

  /// When this route was last confirmed valid.
  final DateTime lastValidatedAt;

  /// The peer that advertised this route (for advertised routes).
  /// Null for direct routes.
  final String? originPeerId;

  /// Sequence number from the advertising peer, if available.
  /// Used for freshness comparison when multiple advertisements exist.
  final int? sequenceNumber;

  /// Absolute expiration time for this route, if set.
  ///
  /// When non-null, the route is considered expired after this time
  /// regardless of validation status. Used by I8.8 route expiration.
  final DateTime? expiresAt;

  /// Whether this route can be used for traffic.
  bool get isActive => state == RouteState.active;

  /// Whether this route is stale (next hop unreachable).
  bool get isStale => state == RouteState.stale;

  /// Whether this route is confirmed invalid.
  bool get isInvalid => state == RouteState.invalid;

  /// Whether this is a direct route (metric 1, direct source).
  bool get isDirect => source == RouteSource.direct && metric == 1;

  /// Create a copy with updated fields.
  Route copyWith({
    int? metric,
    RouteState? state,
    DateTime? lastValidatedAt,
    int? sequenceNumber,
    DateTime? expiresAt,
  }) {
    return Route(
      destinationPeerId: destinationPeerId,
      nextHopPeerId: nextHopPeerId,
      metric: metric ?? this.metric,
      state: state ?? this.state,
      source: source,
      createdAt: createdAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      originPeerId: originPeerId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Route &&
          runtimeType == other.runtimeType &&
          destinationPeerId == other.destinationPeerId &&
          nextHopPeerId == other.nextHopPeerId &&
          metric == other.metric;

  @override
  int get hashCode => Object.hash(destinationPeerId, nextHopPeerId, metric);

  @override
  String toString() {
    final dest = destinationPeerId.length >= 8
        ? destinationPeerId.substring(0, 8)
        : destinationPeerId;
    final next = nextHopPeerId.length >= 8
        ? nextHopPeerId.substring(0, 8)
        : nextHopPeerId;
    return 'Route(dest=$dest..., '
        'next=$next..., '
        'metric=$metric, '
        'state=${state.name}'
        '${expiresAt != null ? ', expires=$expiresAt' : ''})';
  }
}
