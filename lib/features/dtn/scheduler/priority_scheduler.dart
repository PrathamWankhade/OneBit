import '../delivery/dtn_config.dart';
import '../delivery/store_forward_engine.dart';
import '../domain/dtn_envelope.dart';
import '../domain/dtn_priority.dart';

/// Selects the next transmit batch in strict priority order.
///
/// Ordering: priority rank (critical first), then enqueue time (oldest
/// first). The batch is bounded by [limit] and the [DtnDeliveryBudget];
/// envelopes parked by the engine are never eligible.
final class PriorityScheduler {
  const PriorityScheduler();

  /// Sort envelopes by priority then age (mutates and returns [list]).
  List<DtnPacket> order(List<DtnPacket> list) {
    list.sort(_order);
    return list;
  }

  /// Order the outgoing candidates of [engine] and return the batch the
  /// budget admits.
  List<DtnPacket> nextBatch(StoreForwardEngine engine, {int? limit}) {
    final budget = engine.config.budget;
    final ordered = engine.outgoingCandidates(
      limit: limit ?? engine.config.batchLimit,
    );
    final batch = <DtnPacket>[];
    var attempted = 0;
    for (final packet in ordered) {
      if (attempted >= (limit ?? engine.config.batchLimit)) {
        break;
      }
      if (!budget.allow(attempted + 1, packet.priority)) {
        break;
      }
      attempted++;
      batch.add(packet);
    }
    return batch;
  }

  /// Partition the outgoing candidates into per-priority buckets.
  ///
  /// Returns buckets in rank order (critical first); empty lists included.
  Map<DtnPriority, List<DtnPacket>> buckets(StoreForwardEngine engine) {
    final result = <DtnPriority, List<DtnPacket>>{
      for (final p in DtnPriority.values) p: <DtnPacket>[],
    };
    for (final packet in engine.outgoingCandidates(limit: null)) {
      result[packet.priority]!.add(packet);
    }
    for (final list in result.values) {
      list.sort((a, b) {
        final at = a.enqueuedAt ?? a.createdAt;
        final bt = b.enqueuedAt ?? b.createdAt;
        return at.compareTo(bt);
      });
    }
    return result;
  }

  /// Strict total order: priority rank, then enqueue/creation time.
  static int _order(DtnPacket a, DtnPacket b) {
    final byPriority = a.priority.rank.compareTo(b.priority.rank);
    if (byPriority != 0) {
      return byPriority;
    }
    final at = a.enqueuedAt ?? a.createdAt;
    final bt = b.enqueuedAt ?? b.createdAt;
    return at.compareTo(bt);
  }
}
