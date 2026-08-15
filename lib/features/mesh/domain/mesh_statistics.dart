import '../relay/relay_decision.dart';

/// An immutable statistics snapshot of the local mesh engine.
final class MeshStatistics {
  const MeshStatistics({
    required this.startedAt,
    required this.packetsSeen,
    required this.packetsForwarded,
    required this.packetsDeliveredUp,
    required this.dropsByReason,
    required this.duplicatesDropped,
    required this.neighborJoins,
    required this.neighborLeaves,
    required this.routeSwitches,
    required this.routeDiscoveriesIssued,
    required this.routeDiscoveriesLearned,
    required this.topologyChanges,
    required this.duplicateCacheHits,
    required this.duplicateCacheEvictions,
    required this.duplicateCacheSize,
    required this.duplicateCacheCapacity,
    required this.packetsPerMinute,
  });

  final DateTime startedAt;
  final int packetsSeen;
  final int packetsForwarded;
  final int packetsDeliveredUp;

  /// Drop counts keyed by [RelayDropReason].
  final Map<RelayDropReason, int> dropsByReason;

  final int duplicatesDropped;
  final int neighborJoins;
  final int neighborLeaves;
  final int routeSwitches;
  final int routeDiscoveriesIssued;
  final int routeDiscoveriesLearned;
  final int topologyChanges;
  final int duplicateCacheHits;
  final int duplicateCacheEvictions;
  final int duplicateCacheSize;
  final int duplicateCacheCapacity;

  /// Relays performed in the trailing minute (rolling window).
  final int packetsPerMinute;

  /// Total drops of every reason.
  int get totalDrops =>
      dropsByReason.values.fold(0, (sum, value) => sum + value);

  /// Share of *forwarded + delivered* traffic that failed (0..1); `null`
  /// when nothing has flowed yet.
  double? get packetSuccessRate {
    final handled = packetsForwarded + packetsDeliveredUp;
    if (handled == 0 && totalDrops == 0) return null;
    if (handled == 0) return 0.0;
    return (handled / (handled + totalDrops)).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'MeshStatistics(seen $packetsSeen, '
      'forwarded $packetsForwarded, deliveredUp $packetsDeliveredUp, '
      'drops $totalDrops)';
}
