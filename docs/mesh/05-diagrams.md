# Mesh Diagrams

## Component diagram

```
┌──────────────────────────────────────────────────────────────┐
│ presentation/  mesh_providers + mesh_controllers + dev screens │
└───────────────┬────────────────────────────────────────────────┘
                │  watch / read
┌───────────────▼────────────────────────────────────────────────┐
│ domain/  MeshRepository  (contract)                            │
└───────────────┬────────────────────────────────────────────────┘
                │  implement
┌───────────────▼────────────────────────────────────────────────┐
│ data/  MeshRepositoryImpl ────► engine/ MeshEngine             │
│ data/  BluetoothMeshTransportAdapter                            │
└───────────────┬────────────────────────────────────────────────┘
                │ events                                   │ owns
┌───────────────▼───┐                 ┌──────────────────────▼──────┐
│ domain/          │                 │ neighbor/  NeighborDiscovery│
│  MeshTransport   │                 │      NeighborTable          │
│  (contract)      │                 │ routing/  RoutingEngine     │
└───────────────┬───┘                 │      RouteTable, Optimizer │
                │                     │      LoopDetector          │
                │                     ├ relay/    RelayEngine, TTL │
                │                     │            RelayQueue      │
┌───────────────▼───────┐             ├ cache/    DuplicateDetector│
│ features/bluetooth/   │             ├ topology/ TopologyManager   │
│  BluetoothRepository  │             ├ metrics/  NetworkMonitor    │
└───────────────────────┘             ├ statistics/ MeshStatistics  │
                                      └ diagnostics/ MeshDiagnostics │
                  pure Dart, no Flutter imports below this line
```

## Sequence diagram — multi-hop delivery with route learning

```
A             B (relay)          C (relay)          D (target)
│ emit adv     │                  │                  │
│──────────────►NeighborTable B   │                  │
│ ... B relays for D ...         │                  │
│                                                      │
│ A.send(pkt to D) via B         │                  │
│   RoutingEngine.routeFor(D)→B │                  │
│   Relay: forward(nextHop B)   │                  │
│               │   ingest(pkt,D)                   │
│               │   learn reverse route to A via  B's path
│               │   TTL--, path+b     │              │
│               │─────────────────────► ingest:
│               │                      dedup, loop? no, TTL?
│               │                      route for D → C   │
│               │                      forward           │
│               │                                        │ ingest
│               │                                        │ DeliverUp
│               │                                        │ reply: reverse
│               │◄──────────────────────────────────────┘ route to A/C/B
```

## Sequence — self healing via discovery

```
Engine                 RoutingEngine           RelayEngine        Transport
  │ neighborLost(B)      │                        │                  │
  ├──► dissolve via B    │                        │                  │
  ├──► no alternative    │                        │                  │
  ├──► discoverRoute(D)  │                        │                  │
  │    └─► control routeDiscoveryRequest(D)       │                  │
  │                 └────────────────────────────►│ broadcast (TTL)  │
  │                 ◄─────────────────────────────┤ discoverReply(D) │
  │    └─► offerRoute(D, C, hops=2)  adaptive swap│                  │
  ├──► route for D via C selected                │                  │
  └──► next packet to D → forward via C ─────────►│ connect/send C    │
```

## State diagram — MeshEngine

```
        ┌──────────┐   start()    ┌──────────┐  radio/neighbors ready ┌─────────┐
        │  stopped  │────────────►│ starting │───────────────────────►│ running │
        └──────────┘              └──────────┘                          │   ▲    │
            ▲                                                           │   │    │
   stop() │  radio off / fatal                                        │   │ radio off
            │                                                            ▼   │
        ┌──────────────────────────────┐  radio on             ┌────────────┐
        │        degraded              │───────────────────────► re-arming  │
        └──────────────────────────────┘                       └────────────┘
```

`degraded`: no radio reach, engine keeps tables; `running`: full
discovery/routing/relay; `re-arming`: topology refresh on radio return.

## Class overview

See `08-class-diagram.md` for the class-level map; the folder layout is in
`09-folder-structure.md`.