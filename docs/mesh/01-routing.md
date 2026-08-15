# Mesh Routing

## Route model

A route is a hop-by-hop instruction: `(destination → nextHop)`. A node does
not store full end-to-end paths. Every route carries enough metadata to
compare quality at decision time.

```
MeshRoute {
  destination   // node id of the target
  nextHop       // immediate relay to use
  hopCount      // hops to destination via this nextHop
  cost          // composite score (lower is better)
  quality       // 0..1 link-quality blend of the first hop
  reliability   // 0..1 success history of this next hop
  preferred     // true for the currently selected primary
  createdAt     // when learned
  lastUsed      // last time picked (adaptive + expiry)
}
```

## Cost model

`RouteOptimizer.cost(...)`:

```
cost = hopCount
     + (1 - linkQuality(nextHop)) * 2.0
     + freshnessPenalty
     + (1 - reliability(nextHop)) * 1.5
```

- `linkQuality` is derived from the *smoothed* RSSI of the neighbor that
  provides the route (`clamp((rssi+90)/40, 0, 1)`): ≈1 at -50 dBm, ≈0 at
  -90 dBm.
- `freshnessPenalty` grows when a route has been unused: +0.5 after 60 s,
  +1.5 after 5 min. Stale routes stay usable for failover but lose.
- `reliability` is the packet-success history of `nextHop` measured by the
  relay engine (forwards − failures over forwards).

This makes the optimizer prefer lower hop counts, stronger first-hop RSSI,
fresh routes, and relays that actually deliver.

## Adaptive selection

`RouteOptimizer.improveWhenStationary` rules:

1. A **new route is offered** whenever the engine learns one
   (direct link up, overheard packet path, route-discovery reply).
2. If `candidate.cost + epsilon < best.cost`, replace the primary and keep
   the old primary as an **alternative**.
3. If the candidate matches cost within `epsilon`, prefer it only when its
   `quality` is higher (stability bias — avoids hop-flapping).
4. Alternatives are retained (top `K`) for instant failover; the route
   table never holds more than `K` routes per destination.

## Route lifecycle

- **Learn** — from direct neighbors (always hop 1) and from relayed
  packets: the packet's `path` reveals the last relay toward the source,
  yielding a reverse route to the source, and each hop count is observed.
- **Use / touch** — `lastUsed` updates on adoption; expiry timer refreshes
  activity.
- **Fail** — a relay failure or neighbor loss marks the primary stale;
  `RoutingEngine` demotes it and promotes the best alternative
  (self-healing).
- **Repair** — when no alternative exists, a `routeDiscoveryRequest`
  control packet is broadcast (TTL-bounded); the target replies with a
  path summary and every node on the way learns a route.
- **Expire** — routes with `lastUsed` older than the route TTL are
  dropped during the periodic sweep step.

## Route discovery control packets

`MeshControlType`:

- `routeDiscoveryRequest(destination)` — broadcast by any node that needs
  a route; TTL-scoped, duplicate-filtered.
- `routeDiscoveryReply(destination, path)` — unicast back along the
  reverse path; intermediate nodes install reverse routes.

The control objects are domain values (no serialization in this phase —
the packet codec lands in Phase 6).

## Self healing

- On `neighbor lost`: all routes whose `nextHop` is that neighbor are
  dissolved; affected destinations fall back to alternatives or trigger
  discovery.
- On `relay failure`: reliability of the next hop drops, cost rises, and
  the primary rotates out.
- On radio return (strong scan signal again): topology refresh + neighbor
  re-scan rebuild the picture; blocked routes are re-discovered via the
  normal learning path.

## Why not source routing

BLE payloads are small. Hop-by-hop distance-vector headers are
`O(1)` per hop, whereas source routing embeds the whole path into every
packet. With opportunistic phone topology the path ratio is rarely useful
and wastes bytes — so OneBit carries only the precise chosen path in the
header (for loop and flood prevention), not a full planned route.