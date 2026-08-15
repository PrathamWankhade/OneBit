import 'package:onebit/features/mesh/domain/mesh_route.dart';

/// The route quality model and adaptive-selection logic.
///
/// Cost combines hop count, first-hop link quality, reliability history and
/// freshness. Adaptive switching prefers a new route when it beats the
/// current primary by more than [epsilon] on cost, or ties on cost while
/// carrying better quality (stability bias — avoids hop-flapping).
final class RouteOptimizer {
  RouteOptimizer({this.epsilon = 0.15});

  /// Tolerance below which two costs are considered equal.
  final double epsilon;

  /// Maps a smoothed RSSI (dBm) into link quality in `0..1`.
  static double linkQualityFromRssi(double rssiDb) {
    return ((rssiDb + 90) / 40).clamp(0.0, 1.0);
  }

  /// Computes the composite cost for a route candidate.
  ///
  /// - [hopCount] counts relays to the destination
  /// - [quality] is the first hop's link quality (0..1)
  /// - [reliability] is the next hop's success history (0..1)
  /// - [unusedSince] drives the freshness penalty
  double cost({
    required int hopCount,
    required double quality,
    required double reliability,
    Duration unusedSince = Duration.zero,
  }) {
    var value = hopCount.toDouble();
    value += (1 - quality) * 2.0;
    value += (1 - reliability) * 1.5;
    final minutes = unusedSince.inMinutes;
    if (minutes < 1) {
      return value;
    }
    if (minutes < 5) {
      return value + 0.5;
    }
    return value + 1.5;
  }

  /// Builds a [MeshRoute] candidate with this optimizer's cost.
  MeshRoute candidate({
    required String destination,
    required String nextHop,
    required int hopCount,
    required double quality,
    required double reliability,
    required DateTime now,
    DateTime? lastUsed,
  }) {
    final cost = this.cost(
      hopCount: hopCount,
      quality: quality,
      reliability: reliability,
    );
    return MeshRoute(
      destination: destination,
      nextHop: nextHop,
      hopCount: hopCount,
      cost: cost,
      quality: quality,
      reliability: reliability,
      createdAt: now,
      lastUsed: lastUsed ?? now,
    );
  }

  /// Whether [candidate] should replace [current] (never replacing a
  /// `null`).
  bool isBetter({required MeshRoute candidate, required MeshRoute? current}) {
    if (current == null) return true;
    final delta = candidate.cost - current.cost;
    if (delta < -epsilon) return true;
    if (delta <= epsilon && candidate.quality > current.quality) return true;
    return false;
  }
}
