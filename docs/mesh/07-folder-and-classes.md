# Folder Structure

```
lib/features/mesh/
├── domain/                      # pure Dart models + contracts
│   ├── mesh_packet.dart         # MeshPacket, kinds, control types
│   ├── mesh_neighbor.dart       # MeshNeighbor, states, capabilities, trust
│   ├── mesh_route.dart          # MeshRoute value (routing output)
│   ├── mesh_topology.dart       # TopologySnapshot/Node/Link
│   ├── mesh_statistics.dart     # MeshStatistics snapshot
│   ├── mesh_network_status.dart # MeshNetworkStatus snapshot
│   ├── mesh_diagnostics.dart    # MeshDiagnostics report
│   ├── mesh_engine_state.dart   # engine + radio + link state enums
│   ├── mesh_clock.dart          # MeshClock (system + manual)
│   ├── mesh_transport.dart      # MeshTransport contract + events
│   ├── mesh_events.dart         # engine event types
│   └── mesh_repository.dart     # MeshRepository contract + send result
├── neighbor/
│   ├── neighbor_table.dart      # storage, freshness, expiry, streams
│   └── neighbor_discovery_engine.dart
├── routing/
│   ├── route_entry.dart        # internal RouteEntry + cost accessor
│   ├── route_table.dart         # primary + alternatives per destination
│   ├── route_optimizer.dart     # cost model + adaptive switching
│   ├── routing_engine.dart      # learn/discover/repair/expire
│   └── loop_detector.dart       # path validation
├── relay/
│   ├── ttl_manager.dart
│   ├── relay_decision.dart
│   ├── relay_queue.dart
│   └── relay_engine.dart
├── cache/
│   └── duplicate_packet_detector.dart
├── topology/
│   └── topology_manager.dart
├── metrics/
│   ├── rssi_history.dart
│   └── network_monitor.dart
├── statistics/
│   └── mesh_statistics_tracker.dart
├── diagnostics/
│   └── mesh_diagnostics_builder.dart
├── engine/
│   └── mesh_engine.dart
├── data/
│   ├── mesh_gatt_constants.dart
│   ├── bluetooth_mesh_transport_adapter.dart
│   └── mesh_repository_impl.dart
├── presentation/
│   ├── mesh_providers.dart
│   ├── mesh_controllers.dart
│   └── mesh_dev_screen.dart
└── simulation/
    ├── simulated_transport.dart
    ├── mesh_simulator.dart
    └── simulation_scenarios.dart
```

`tool/mesh_simulation.dart` — CLI scenario runner that prints scenario
summaries to stdout and exits non-zero on assertion failure.

## Domain purity

Everything under `domain/`, `neighbor/`, `routing/`, `relay/`, `cache/`,
`topology/`, `metrics/`, `statistics/`, `diagnostics/`, `engine/` and
`simulation/` is pure Dart — zero Flutter imports. Only `data/`
(transport adapter, repository) and `presentation/` (providers, screens,
controllers) bridge to Flutter/Riverpod. This keeps the engine unit-
testable headlessly and future-proofs the C++/dart FFI migration.

## Class map

```
MeshTransport (interface) ← BluetoothMeshTransportAdapter
MeshRepository (interface) ← MeshRepositoryImpl
MeshEngine ── owns → NDD, NeighborTable, RoutingEngine, RouteTable,
                      RouteOptimizer, LoopDetector, RelayEngine, TTLManager,
                      RelayQueue, DupPacketDetector, TopologyManager,
                      NetworkMonitor, MeshStatisticsTracker,
                      MeshDiagnosticsBuilder
RoutingEngine ── optimize via → RouteOptimizer (cost, alternatives)
RoutingEngine ── validate with → LoopDetector
RelayEngine ── ar → RelayDecision; queue drains via onForward sink
```