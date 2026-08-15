/// A single RSSI sample for charting.
final class RssiPoint {
  const RssiPoint({required this.rssiDb, required this.at});

  final int rssiDb;
  final DateTime at;
}

/// Bounded per-node RSSI series, kept purely for the developer RSSI chart.
///
/// The engine's adaptives and routing read smoothed values from the
/// neighbor table instead; this is raw history with a hard cap per node.
final class MeshRssiHistory {
  MeshRssiHistory({this._perNodeCapacity = 120});

  final int _perNodeCapacity;
  final Map<String, List<RssiPoint>> _series = {};

  /// Records [rssiDb] observed at [at] for [nodeId].
  void record(String nodeId, int rssiDb, DateTime at) {
    final list = _series.putIfAbsent(nodeId, () => []);
    list.add(RssiPoint(rssiDb: rssiDb, at: at));
    if (list.length > _perNodeCapacity) {
      list.removeRange(0, list.length - _perNodeCapacity);
    }
  }

  /// Samples for [nodeId], oldest first.
  List<RssiPoint> forNode(String nodeId) =>
      List.unmodifiable(_series[nodeId] ?? const []);

  /// Mean RSSI for [nodeId], or `null` when no samples.
  double? average(String nodeId) {
    final samples = _series[nodeId];
    if (samples == null || samples.isEmpty) return null;
    var sum = 0;
    for (final point in samples) {
      sum += point.rssiDb;
    }
    return sum / samples.length;
  }

  /// Nodes currently keeping history.
  int get trackedNodes => _series.length;

  /// Drops node series whose most recent sample predates [staleBefore].
  void prune(DateTime staleBefore) {
    _series.removeWhere((_, samples) {
      if (samples.isEmpty) return true;
      return samples.last.at.isBefore(staleBefore);
    });
  }
}
