/// A learned hop-by-hop route: to reach [destination], send via [nextHop].
///
/// Immutable; the route table replaces values instead of mutating them.
/// [cost] is the optimizer's composite score (lower is better); [quality]
/// and [reliability] feed it and drive adaptive switching.
final class MeshRoute {
  const MeshRoute({
    required this.destination,
    required this.nextHop,
    required this.hopCount,
    required this.cost,
    required this.quality,
    required this.reliability,
    required this.createdAt,
    required this.lastUsed,
    this.preferred = false,
    this.expiresAt,
  });

  /// Node the route reaches.
  final String destination;

  /// Immediate relay to forward to.
  final String nextHop;

  /// Hops to [destination] via [nextHop].
  final int hopCount;

  /// Composite cost; lower is better.
  final double cost;

  /// Link quality (0..1) of the first hop.
  final double quality;

  /// Historical success rate (0..1) of [nextHop].
  final double reliability;

  /// True when this route is the current primary for [destination].
  final bool preferred;

  /// When the route was learned.
  final DateTime createdAt;

  /// When the route was last used or refreshed.
  final DateTime lastUsed;

  /// Optional absolute expiry; `null` means the table TTL applies.
  final DateTime? expiresAt;

  MeshRoute copyWith({
    double? cost,
    double? quality,
    double? reliability,
    bool? preferred,
    DateTime? lastUsed,
    DateTime? expiresAt,
  }) {
    return MeshRoute(
      destination: destination,
      nextHop: nextHop,
      hopCount: hopCount,
      cost: cost ?? this.cost,
      quality: quality ?? this.quality,
      reliability: reliability ?? this.reliability,
      preferred: preferred ?? this.preferred,
      createdAt: createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Identity of the route within a destination (its next hop).
  bool sameNextHop(MeshRoute other) =>
      other.destination == destination && other.nextHop == nextHop;

  @override
  String toString() =>
      'MeshRoute($destination via $nextHop, '
      'hops $hopCount, cost ${cost.toStringAsFixed(2)})';
}
