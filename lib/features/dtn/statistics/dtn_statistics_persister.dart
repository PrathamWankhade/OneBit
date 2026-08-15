import '../../../core/database/dao/statistics_dao.dart';
import '../domain/dtn_statistics.dart';

/// Namespace for persisted DTN statistic keys.
abstract final class DtnStatisticKeys {
  DtnStatisticKeys._();

  static const stored = 'dtn.packets_stored';
  static const delivered = 'dtn.packets_delivered';
  static const expired = 'dtn.packets_expired';
  static const retried = 'dtn.retries';
  static const relayed = 'dtn.relayed';
  static const acknowledged = 'dtn.acknowledged';
  static const recovered = 'dtn.recovered';
  static const parked = 'dtn.parked';
  static const deduplicated = 'dtn.deduplicated';
  static const liveEnvelopes = 'dtn.live_envelopes';
  static const avgDeliveryLatency = 'dtn.avg_delivery_latency';
}

/// Persists DTN statistics snapshots into the shared Statistics table.
///
/// Idempotent by design: counters are absolute values (not deltas), so
/// re-applying an old snapshot never double counts. The engine keeps
/// emitting snapshots; this persister writes them each time.
final class DtnStatisticsPersister {
  const DtnStatisticsPersister(this._dao);

  final StatisticsDao _dao;

  /// Write [snapshot] as named statistic rows.
  Future<void> persist(DtnStatisticsSnapshot snapshot) async {
    await Future.wait([
      _dao.setGauge(DtnStatisticKeys.stored, snapshot.stored.toDouble()),
      _dao.setGauge(DtnStatisticKeys.delivered, snapshot.delivered.toDouble()),
      _dao.setGauge(DtnStatisticKeys.expired, snapshot.expired.toDouble()),
      _dao.setGauge(DtnStatisticKeys.retried, snapshot.retried.toDouble()),
      _dao.setGauge(DtnStatisticKeys.relayed, snapshot.relayed.toDouble()),
      _dao.setGauge(
        DtnStatisticKeys.acknowledged,
        snapshot.acknowledged.toDouble(),
      ),
      _dao.setGauge(DtnStatisticKeys.recovered, snapshot.recovered.toDouble()),
      _dao.setGauge(DtnStatisticKeys.parked, snapshot.parked.toDouble()),
      _dao.setGauge(
        DtnStatisticKeys.deduplicated,
        snapshot.deduplicated.toDouble(),
      ),
      _dao.setGauge(
        DtnStatisticKeys.liveEnvelopes,
        snapshot.liveEnvelopes.toDouble(),
      ),
      _dao.setGauge(
        DtnStatisticKeys.avgDeliveryLatency,
        snapshot.avgDeliveryLatency ?? 0,
      ),
    ]);
  }
}
