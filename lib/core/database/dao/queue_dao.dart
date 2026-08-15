import 'package:drift/drift.dart';

import '../database.dart';
import '../models/queue_snapshot.dart';
import '../tables/enums.dart';
import '../tables/queue_tables.dart';

part 'queue_dao.g.dart';

/// Typed persistence for the outbound processing queues.
@DriftAccessor(tables: [PendingQueue, RetryQueue, RelayQueue])
final class QueueDao extends DatabaseAccessor<OneBitDatabase>
    with _$QueueDaoMixin {
  QueueDao(super.db);

  @override
  $PendingQueueTable get pendingQueue => db.pendingQueue;

  @override
  $RetryQueueTable get retryQueue => db.retryQueue;

  @override
  $RelayQueueTable get relayQueue => db.relayQueue;

  // ---- Pending queue ------------------------------------------------------------

  Future<int> enqueuePending(PendingQueueRow row) =>
      into(pendingQueue).insert(row, mode: InsertMode.insertOrIgnore);

  /// The next items that are due (attempt window passed or unset).
  Future<List<PendingQueueRow>> drainPending({int limit = 100, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return (select(pendingQueue)
          ..where(
            (t) =>
                t.nextAttemptAt.isNull() |
                t.nextAttemptAt.isSmallerThanValue(
                  timestamp.millisecondsSinceEpoch,
                ),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.enqueuedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> removePending(int queueId) =>
      (delete(pendingQueue)..where((t) => t.queueId.equals(queueId))).go();

  // ---- Retry -------------------------------------------------------------------

  Future<int> enqueueRetry(RetryQueueRow entry) =>
      into(retryQueue).insert(entry, mode: InsertMode.insertOrIgnore);

  /// Retries that are due (state queued, attempt window passed or unset).
  Future<List<RetryQueueRow>> dueRetries({int limit = 100, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return (select(retryQueue)
          ..where(
            (t) =>
                t.state.equalsValue(QueueState.queued) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerThanValue(
                      timestamp.millisecondsSinceEpoch,
                    )),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.nextAttemptAt)])
          ..limit(limit))
        .get();
  }

  Future<int> updateRetryAttempts(
    int retryId, {
    required int attempts,
    required DateTime nextAttemptAt,
    String? lastError,
  }) => (update(retryQueue)..where((t) => t.retryId.equals(retryId))).write(
    RetryQueueCompanion(
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      lastAttemptAt: Value(DateTime.now()),
      lastError: Value(lastError),
      state: const Value(QueueState.queued),
    ),
  );

  Future<int> markRetryFailed(int retryId) =>
      (update(retryQueue)..where((t) => t.retryId.equals(retryId))).write(
        const RetryQueueCompanion(state: Value(QueueState.failed)),
      );

  Future<int> removeRetry(int retryId) =>
      (delete(retryQueue)..where((t) => t.retryId.equals(retryId))).go();

  // ---- Relay -------------------------------------------------------------------

  Future<int> enqueueRelay(
    String packetId, {
    required String source,
    required String destination,
    required int hopsRemaining,
    DateTime? enqueuedAt,
  }) => into(relayQueue).insertOnConflictUpdate(
    RelayQueueRow(
      relayId: 0,
      packetId: packetId,
      source: source,
      destination: destination,
      hopsRemaining: hopsRemaining,
      enqueuedAt: enqueuedAt ?? DateTime.now(),
      state: RelayState.queued,
    ),
  );

  Future<List<RelayQueueRow>> pendingRelays({int limit = 100}) =>
      (select(relayQueue)
            ..where((t) => t.state.equalsValue(RelayState.queued))
            ..orderBy([(t) => OrderingTerm.asc(t.enqueuedAt)])
            ..limit(limit))
          .get();

  Future<int> markRelayState(int relayId, RelayState state) =>
      (update(relayQueue)..where((t) => t.relayId.equals(relayId))).write(
        RelayQueueCompanion(state: Value(state)),
      );

  Future<int> removeRelay(int relayId) =>
      (delete(relayQueue)..where((t) => t.relayId.equals(relayId))).go();

  // ---- Counts -------------------------------------------------------------------

  Future<QueueSnapshot> snapshot() async {
    Future<int> pendingCount() async {
      final row = await (selectOnly(
        pendingQueue,
      )..addColumns([countAll()])).getSingle();
      return row.read(countAll()) ?? 0;
    }

    Future<int> retryCount() async {
      final row = await (selectOnly(
        retryQueue,
      )..addColumns([countAll()])).getSingle();
      return row.read(countAll()) ?? 0;
    }

    Future<int> relayCount() async {
      final row = await (selectOnly(
        relayQueue,
      )..addColumns([countAll()])).getSingle();
      return row.read(countAll()) ?? 0;
    }

    return QueueSnapshot(
      pending: await pendingCount(),
      retrying: await retryCount(),
      relaying: await relayCount(),
    );
  }
}
