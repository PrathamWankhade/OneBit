import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/database/dao/dtn_dao.dart';
import 'package:onebit/core/database/dao/statistics_dao.dart';
import 'package:onebit/core/database/database_providers.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/dtn/data/sqlite_dtn_persistence.dart';
import 'package:onebit/features/dtn/delivery/delivery_scheduler.dart';
import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/delivery/dtn_gateway.dart';
import 'package:onebit/features/dtn/delivery/simulated_mesh_gateway.dart';
import 'package:onebit/features/dtn/delivery/store_forward_engine.dart';
import 'package:onebit/features/dtn/domain/dtn_queue_snapshot.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';
import 'package:onebit/features/dtn/domain/dtn_statistics.dart';
import 'package:onebit/features/dtn/dtn_engine.dart';
import 'package:onebit/features/dtn/statistics/dtn_statistics_persister.dart';

/// Persists DTN statistics into the shared Statistics table on every
/// snapshot (counters are gauges, so re-running is idempotent).
final Provider<DtnStatisticsPersister> dtnStatisticsPersisterProvider =
    Provider<DtnStatisticsPersister>(
      (ref) =>
          DtnStatisticsPersister(StatisticsDao(ref.watch(databaseProvider))),
    );

/// Listens to the engine's statistics stream and mirrors it to the database.
/// Kept alive for the process lifetime via the engine provider.
final Provider<void> dtnStatisticsSinkProvider = Provider<void>((ref) {
  final persister = ref.watch(dtnStatisticsPersisterProvider);
  final subscription = ref
      .watch(dtnEngineProvider)
      .statisticsSnapshots()
      .listen((snapshot) {
        unawaited(persister.persist(snapshot));
      });
  ref.onDispose(subscription.cancel);
});

/// The mesh transport seam for the DTN layer.
///
/// The real radio transports land in later phases; until then the simulated
/// gateway lets the whole store-and-forward layer run end to end. Flip
/// `reachable` from the dtn dev console to observe parking/delivery.
final Provider<DtnGateway> dtnGatewayProvider = Provider<DtnGateway>(
  (ref) => SimulatedMeshGateway(),
);

/// The process-wide DTN engine — created lazily and started on touch.
final Provider<DtnEngine> dtnEngineProvider = Provider<DtnEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final gateway = ref.watch(dtnGatewayProvider);
  final engine = StoreForwardEngine(
    config: const DtnEngineConfig(),
    persistence: SqliteDtnPersistence(DtnDao(db)),
    now: DateTime.now,
    gateway: gateway,
  );
  final scheduler = DeliveryScheduler(engine: engine, gateway: gateway);
  final dtn = DtnEngine(engine: engine, scheduler: scheduler);
  unawaited(
    dtn.start().catchError((Object error, StackTrace stack) {
      ref
          .watch(appLoggerProvider)
          .error('DTN engine failed to start', error: error, stackTrace: stack);
    }),
  );
  ref.onDispose(() => unawaited(dtn.stop()));
  return dtn;
});

/// The repository contract the DTN layer exposes; today the engine itself.
/// Watching it also keeps the statistics persistence sink alive.
final Provider<DTNRepository> dtnRepositoryProvider = Provider<DTNRepository>((
  ref,
) {
  ref.watch(dtnStatisticsSinkProvider);
  return ref.watch(dtnEngineProvider);
});

/// Snapshot stream for dev monitors (queues).
final StreamProvider<DtnQueueSnapshot> dtnQueueSnapshotProvider =
    StreamProvider<DtnQueueSnapshot>(
      (ref) => ref.watch(dtnEngineProvider).queueSnapshots(),
    );

/// Snapshot stream for dev monitors (statistics).
final StreamProvider<DtnStatisticsSnapshot> dtnStatisticsSnapshotProvider =
    StreamProvider<DtnStatisticsSnapshot>(
      (ref) => ref.watch(dtnEngineProvider).statisticsSnapshots(),
    );
