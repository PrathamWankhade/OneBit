# Topology, Network Monitoring, Self Healing

## TopologyManager

Builds a *local* topology view (never global):

- **Nodes** — the local node + every live neighbor entry.
- **Links** — each neighbor edge with its current link quality (smoothed
  RSSI-derived).
- **Partitions** — count of connected components reachable from the local
  node's perspective (BFS over the neighbor graph + observed routes); a
  partition count > 1 signals a broken region.

The graph is a projection of `NeighborTable` + `RouteTable`. Any change to
neighbor state (join/leave/quality shift) or routes re-derives the graph
lazily (dirty flag) and emits `TopologyChangedEvent` + a `TopologySnapshot`
for the network graph panel and diagnostics.

## NetworkMonitor

Periodic health aggregation (`MeshNetworkStatus`):

- active neighbor count / known node count / disconnected count
- average smoothed RSSI across neighbors
- average hop count across current routes
- relay rate (packets forwarded per minute)
- connection quality (blend of mean link quality + up-time)
- **mesh stability** — `1 - (join/leave churn · window)/(stable window)`
- **packet success** — delivered-up + forwarded vs dropped (excluding
  duplicates), rolling window
- partition count, engine state, last-updated time

## Self healing loop (MeshEngine)

The engine routes every signal back into the decision loop:

| Signal | Reaction |
| --- | --- |
| neighbor expires / link lost | dissolve routes via that next hop; demote to alternative; if nothing left → issue `routeDiscoveryRequest` |
| relay forward fails | mark next hop unreliable → cost rises → primary rotates out; alternative promoted |
| radio off | engine → `degraded`; scanning pauses; state re-arm on radio-on |
| radio back | neighbor table refresh + topology recount + re-scan request |
| route discovers improve | `RouteOptimizer` swaps in better route (adaptive routing) |

All recovery is local and event-driven — no timers beyond the shared
sweep tick, no coordinator.

## Battery discipline

- Sweep tick (default 5 s) drives expiry, queue flush and statistics;
  it does **not** touch the radio.
- Scanning duty cycle and Doze behavior belong to the Bluetooth transport;
  the engine merely reacts to `RadioStateChanged` / `BatterySaverChanged`.