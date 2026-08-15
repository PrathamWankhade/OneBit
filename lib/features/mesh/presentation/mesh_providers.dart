import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/mesh/data/bluetooth_mesh_transport_adapter.dart';
import 'package:onebit/features/mesh/data/mesh_repository_impl.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_diagnostics.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_neighbor.dart';
import 'package:onebit/features/mesh/domain/mesh_network_status.dart';
import 'package:onebit/features/mesh/domain/mesh_repository.dart';
import 'package:onebit/features/mesh/domain/mesh_route.dart';
import 'package:onebit/features/mesh/domain/mesh_statistics.dart';
import 'package:onebit/features/mesh/domain/mesh_topology.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';
import 'package:onebit/features/mesh/engine/mesh_engine.dart';
import 'package:onebit/features/mesh/presentation/mesh_controllers.dart';

/// The mesh transport over the Bluetooth repository.
///
/// [BluetoothMeshTransportAdapter] projects BLE addresses onto node ids 1:1.
/// The identity phase later swaps `localNodeId` for the node's derived id.
final Provider<MeshTransport> meshTransportProvider = Provider<MeshTransport>((
  ref,
) {
  final adapter = BluetoothMeshTransportAdapter(
    bluetooth: ref.watch(bluetoothRepositoryProvider),
    localNodeId: 'local',
    advertisedName: 'OneBit',
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// The engine (composition root). Pure Dart; wired to the fixed clock.
final Provider<MeshEngine> meshEngineProvider = Provider<MeshEngine>((ref) {
  final engine = MeshEngine(
    localNodeId: 'local',
    transport: ref.watch(meshTransportProvider),
    clock: const SystemMeshClock(),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// The repository consumed by the UI.
final Provider<MeshRepository> meshRepositoryProvider =
    Provider<MeshRepository>((ref) {
      final repository = MeshRepositoryImpl(
        engine: ref.watch(meshEngineProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Engine lifecycle stream (replays current state on listen).
final StreamProvider<Result<MeshEngineState>> meshStateProvider =
    StreamProvider<Result<MeshEngineState>>(
      (ref) => ref.watch(meshRepositoryProvider).observeState(),
    );

final StreamProvider<Result<List<MeshNeighbor>>> meshNeighborsProvider =
    StreamProvider<Result<List<MeshNeighbor>>>(
      (ref) => ref.watch(meshRepositoryProvider).observeNeighbors(),
    );

final StreamProvider<Result<List<MeshRoute>>> meshRoutesProvider =
    StreamProvider<Result<List<MeshRoute>>>(
      (ref) => ref.watch(meshRepositoryProvider).observeRoutes(),
    );

final StreamProvider<Result<TopologySnapshot>> meshTopologyProvider =
    StreamProvider.autoDispose<Result<TopologySnapshot>>(
      (ref) => ref.watch(meshRepositoryProvider).observeTopology(),
    );

final StreamProvider<Result<MeshStatistics>> meshStatisticsProvider =
    StreamProvider.autoDispose<Result<MeshStatistics>>(
      (ref) => ref.watch(meshRepositoryProvider).observeStatistics(),
    );

final StreamProvider<Result<MeshNetworkStatus>> meshNetworkStatusProvider =
    StreamProvider.autoDispose<Result<MeshNetworkStatus>>(
      (ref) => ref.watch(meshRepositoryProvider).observeNetworkStatus(),
    );

final StreamProvider<Result<MeshDiagnostics>> meshDiagnosticsProvider =
    StreamProvider.autoDispose<Result<MeshDiagnostics>>(
      (ref) => ref.watch(meshRepositoryProvider).observeDiagnostics(),
    );

final StreamProvider<Result<MeshRelayEvent>> meshRelayEventsProvider =
    StreamProvider.autoDispose<Result<MeshRelayEvent>>(
      (ref) => ref.watch(meshRepositoryProvider).observeRelayEvents(),
    );

final StreamProvider<Result<MeshNeighborEvent>> meshNeighborEventsProvider =
    StreamProvider.autoDispose<Result<MeshNeighborEvent>>(
      (ref) => ref.watch(meshRepositoryProvider).observeNeighborEvents(),
    );

final StreamProvider<Result<MeshRouteChangedEvent>> meshRouteEventsProvider =
    StreamProvider.autoDispose<Result<MeshRouteChangedEvent>>(
      (ref) => ref.watch(meshRepositoryProvider).observeRouteEvents(),
    );

/// Lifecycle control (start/stop) plus state mirror.
final NotifierProvider<MeshLifecycleController, MeshEngineState>
meshLifecycleControllerProvider =
    NotifierProvider<MeshLifecycleController, MeshEngineState>(
      MeshLifecycleController.new,
    );
