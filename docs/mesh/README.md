# OneBit Mesh — Phase 5: Networking Engine

## Scope

This phase builds the **networking layer only** for OneBit's fully
decentralized Bluetooth mesh:

- Automatic discovery
- Dynamic routing (MANET-style, hop-by-hop)
- Self healing, route recovery, adaptive route selection
- Relaying with TTL, duplicate and loop prevention
- Topology tracking and network monitoring
- Diagnostics and developer tooling
- Headless simulation (2…50 nodes)

Out of scope (later phases): packet serialization/encryption, messaging,
chat UI, voice, media, store-and-forward, application layer. This engine
consumes transport events from the Bluetooth layer and produces routing
decisions for higher layers.

## Design principle

There is **no coordinator**. Every node is a peer that runs the identical
engine. The network is an opportunistic MANET over Bluetooth Low Energy:
nodes advertise, scan, connect on demand, and relay packets for each other.
State is local to each node — no global state is ever assumed.

## Why a distance-vector / on-demand hybrid (not AODV, not OLSR, not B.A.T.M.A.N.)

BLE imposes a unique constraint set:

- **Asymmetric, intermittent links** — a phone is not a router with a
  stable backbone; links come and go as people move and radios sleep.
- **Low duty cycle** — constant route-table flooding (OLSR-style) would
  burn the battery. BLE advertising windows must stay short.
- **Small packets** — a mesh header must stay tiny; exchanging full path
  vectors (B.A.T.M.A.N./SR-style) wastes payload space.
- **No ACKs at mesh layer** — BLE writes can be unacknowledged, so link
  reliability must be *estimated*, not assumed.

Therefore OneBit uses a **proactive distance-vector core with on-demand
route repair**, specifically:

1. **Neighbor state is proactive** (discovery + RSSI smoothing), because it
   is free: it rides on BLE advertisements we already scan.
2. **Route computation is reactive-lazy**: a node learns routes from
   (a) direct links, (b) overheard packet paths, (c) explicit route
   discovery requests (broadcast, replied to by the target). No periodic
   route flooding.
3. **Route quality is adaptive**: cost blends hop count, link quality
   (smoothed RSSI), freshness, and next-hop reliability history. Better
   routes replace worse ones the moment they are observed.

This keeps control overhead near zero when the mesh is quiet, while
remaining fully reactive under churn — the correct trade-off for phone
hardware.

## Component map

| Component | File | Responsibility |
| --- | --- | --- |
| `MeshEngine` | `engine/mesh_engine.dart` | Composition root: owns all engines, dispatch, self-healing loop |
| `MeshRepository` | `domain/mesh_repository.dart` + `data/mesh_repository_impl.dart` | Domain facade; `Result`-wrapped streams |
| `MeshTransport` | `domain/mesh_transport.dart` + `data/bluetooth_mesh_transport_adapter.dart` | Bluetooth↔mesh event boundary |
| `NeighborDiscoveryEngine` | `neighbor/neighbor_discovery_engine.dart` | Turns transport events into neighbor table entries |
| `NeighborTable` | `neighbor/neighbor_table.dart` | Freshness, expiry, RSSI smoothing, distance estimates |
| `RoutingEngine` | `routing/routing_engine.dart` | Route learning, discovery, repair, replacement |
| `RouteTable` | `routing/route_table.dart` | Primary + alternative routes per destination |
| `RouteOptimizer` | `routing/route_optimizer.dart` | Cost model, adaptive switching |
| `LoopDetector` | `routing/loop_detector.dart` | Path validation, loop rejection |
| `TTLManager` | `relay/ttl_manager.dart` | TTL decrement/expiry |
| `DuplicatePacketDetector` | `cache/duplicate_packet_detector.dart` | Bounded seen-cache, dedup |
| `RelayEngine` | `relay/relay_engine.dart` | Relay decisions, queue, stats |
| `TopologyManager` | `topology/topology_manager.dart` | Local topology graph + partitions |
| `NetworkMonitor` | `metrics/network_monitor.dart` | Health aggregates (avg RSSI/hops, stability, success) |
| `MeshStatistics` | `statistics/mesh_statistics_tracker.dart` | Counter snapshot |
| `MeshDiagnostics` | `diagnostics/mesh_diagnostics_builder.dart` | Inspector reports |

## Layer rule

`presentation` → `MeshRepository` → `MeshEngine` → sub-engines →
`MeshTransport` → Bluetooth. The engine and everything under it are pure
Dart (no Flutter imports). Widgets only ever read providers.

## Scalability

Designed for thousands of nodes without a central coordinator:

- **Bounded state**: duplicate cache is size-capped (LRU-style) with TTL
  sweeps; neighbor and route tables expire entries; memory is
  `O(neighbors + known destinations)`, never `O(network²)`.
- **Constant-time lookups**: hash maps for neighbor, route, and dedup
  lookups.
- **Local decisions only**: relay decisions need only the local tables —
  a packet never carries global state.
- **Battery-first**: no periodic flooding; passive learning via
  overheard advertisements and packets; adaptive scan duty cycle comes
  from the Bluetooth phase.
- **Flood-scoped discovery**: route discovery broadcasts are TTL-bounded
  and duplicate-filtered, so even a 1000-node flood terminates in
  `O(ttl × degree)` relays.

## Integration with later phases

- **Packet Protocol (Phase 6)** — replaces the opaque `payload` byte list
  with a wire codec; `MeshPacket` already carries the full header the
  codec needs (id, src, dst, ttl, hops, path, control kind). No engine
  change required.
- **Store-and-Forward** — the `RelayQueue` interface is the hook; the
  queue drains on `flush()` today, later it persists and drains when the
  destination is next seen.
- **Messaging** — the engine exposes `send(destination, payload)` and
  `observeDeliveredUp`; the messaging layer becomes a payload producer
  and consumer only.
- **Encryption** — payload bytes are opaque to the engine; encryption
  wraps the payload before it reaches `send`.

## Developer UI

`MeshDevScreen` (route `/mesh-debug`) exposes engineering panels only:
neighbor list, route table, statistics, network status, topology graph,
relay event log, RSSI history, diagnostics. No production UI in this
phase.
