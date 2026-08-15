# Simulation & Testing

## Simulation architecture

`lib/features/mesh/simulation/` hosts a **headless, deterministic** world:

- `SimulatedTransport` — an in-memory `MeshTransport` per node: emits
  advertisements with a signal-strength model, delivers bytes to in-range
  neighbors with configurable loss, and exposes link cuts (partitioning).
- `MeshSimulator` — owns `N` full `MeshEngine` instances sharing a
  `ManualMeshClock`; each engine is the *production* engine, so the
  simulation exercises real routing/relay/topology code, not a mock.
- Scenarios run in `tool/mesh_simulation.dart` (CLI runner) and are
  replayed as `flutter_test` cases in
  `test/features/mesh/mesh_scenarios_test.dart`.

## Connectivity model

Nodes are placed on an explicit radio graph: `sim.link(a, b,
intensityDb)`. Two linked nodes hear each other's advertisements with an
RSSI that jitters around the link intensity (`intensityDb ± 3 dBm`), and
unicast frames only cross *live* links — a cut link drops the frame like
real radio loss. Unlisted links never exist. `unlink` tears a link out
(partition); re-linking restores it (recovery). This keeps every scenario
deterministic and topology-driven, which is how the real BLE mesh actually
behaves: connectivity is granted by proximity, not by geometry.

## Scenarios

| Scenario | Size | Assertion focus |
| --- | --- | --- |
| 2 nodes | 2 | direct link, hop-1 route, delivery |
| 5 nodes | 5 | multi-hop convergence, reverse-route learning |
| 10 nodes | 10 | ring: far-side delivery, no loops, no drops |
| 20 nodes | 20 | 5×4 lattice, 6-hop diagonal delivery, bounded route |
| 50 nodes | 50 | ladder + mid-run cut/restore; bounded caches, delivery after churn |
| node join | 2→3 | newcomer added mid-run; two-hop route converges |
| node leave | 3→2 | leaver expires, routes dissolve, discovery re-arms |
| route failure | 4 | diamond: primary relay dies, surviving relay promoted |
| relay failure | 4 | hub dies overnight→ outage detected → new link recovers |
| partition | 5 | bridge cut: far cluster leaves the hub's view, traffic stops |
| recovery | 5 | bridge restored → neighbours re-trusted, routes reconverge |

## Test strategy

- **Unit**: TTLManager, DuplicatePacketDetector, LoopDetector,
  RouteOptimizer cost math, NeighborTable expiry/distance/
  capability-propagation, RelayQueue.
- **Engine**: NeighborDiscoveryEngine, RoutingEngine (adaptive switch,
  repair), RelayEngine (every decision branch), TopologyManager
  (partitions), NetworkMonitor aggregates, MeshStatistics counters,
  MeshEngine end-to-end (2–3 node ring), MeshRepository streams.
- **Simulation**: the multi-node scenarios above with the deterministic
  clock.
- **Stress** (`test/features/mesh/mesh_stress_test.dart`): 50-node churn
  with bounded neighbour/route/duplicate state, rapid join/leave cycles
  that leave no table leaks, and a 10k-packet deduplication burst whose
  cache never grows past its capacity.

All tests are pure Dart `flutter_test` cases in `test/features/mesh/`.