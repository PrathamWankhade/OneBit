import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import '../relay/relay_decision.dart';

/// Counter hub behind [MeshStatistics].
///
/// Tracks cumulative counters plus two rolling windows (relayed packets and
/// churn) so the monitor can show rates without unbounded history.
final class MeshStatisticsTracker {
  MeshStatisticsTracker({
    required this._now,
    this.rateWindow = const Duration(minutes: 1),
  });

  final DateTime Function() _now;
  final Duration rateWindow;

  final DateTime _startedAt = DateTime.now();

  int _seen = 0;
  int _forwarded = 0;
  int _deliveredUp = 0;
  final Map<RelayDropReason, int> _drops = {};
  int _neighborJoins = 0;
  int _neighborLeaves = 0;
  int _routeSwitches = 0;
  int _discoveriesIssued = 0;
  int _discoveriesLearned = 0;
  int _topologyChanges = 0;

  int _duplicateHits = 0;
  int _duplicateEvictions = 0;
  int _duplicateSize = 0;
  int _duplicateCapacity = 0;

  final List<DateTime> _forwardTimes = [];
  final List<DateTime> _churnTimes = [];

  void recordPacketSeen() {
    _seen++;
  }

  void recordForward() {
    _forwarded++;
    _forwardTimes.add(_now());
  }

  void recordDeliverUp() {
    _deliveredUp++;
  }

  void recordDrop(RelayDropReason reason) {
    _drops[reason] = (_drops[reason] ?? 0) + 1;
  }

  void recordNeighborJoin() {
    _neighborJoins++;
    _churnTimes.add(_now());
  }

  void recordNeighborLeave() {
    _neighborLeaves++;
    _churnTimes.add(_now());
  }

  void recordRouteSwitch() {
    _routeSwitches++;
  }

  void recordDiscoveryIssued() {
    _discoveriesIssued++;
  }

  void recordDiscoveryLearned() {
    _discoveriesLearned++;
  }

  void recordTopologyChange() {
    _topologyChanges++;
  }

  /// Mirrors the duplicate-detector cache health into the snapshot.
  void syncDuplicateCache({
    required int hits,
    required int evictions,
    required int size,
    required int capacity,
  }) {
    _duplicateHits = hits;
    _duplicateEvictions = evictions;
    _duplicateSize = size;
    _duplicateCapacity = capacity;
  }

  /// Forwards within the trailing window.
  int packetsPerMinute() => _countWithin(_forwardTimes);

  /// Join+leave events within the trailing window.
  int churnPerMinute() => _countWithin(_churnTimes);

  int _countWithin(List<DateTime> times) {
    final cutoff = _now().subtract(rateWindow);
    times.removeWhere((at) => at.isBefore(cutoff));
    return times.length;
  }

  MeshStatistics snapshot() {
    return MeshStatistics(
      startedAt: _startedAt,
      packetsSeen: _seen,
      packetsForwarded: _forwarded,
      packetsDeliveredUp: _deliveredUp,
      dropsByReason: Map.of(_drops),
      duplicatesDropped: _drops[RelayDropReason.duplicate] ?? 0,
      neighborJoins: _neighborJoins,
      neighborLeaves: _neighborLeaves,
      routeSwitches: _routeSwitches,
      routeDiscoveriesIssued: _discoveriesIssued,
      routeDiscoveriesLearned: _discoveriesLearned,
      topologyChanges: _topologyChanges,
      duplicateCacheHits: _duplicateHits,
      duplicateCacheEvictions: _duplicateEvictions,
      duplicateCacheSize: _duplicateSize,
      duplicateCacheCapacity: _duplicateCapacity,
      packetsPerMinute: packetsPerMinute(),
    );
  }
}
