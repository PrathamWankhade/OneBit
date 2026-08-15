# Relay, TTL, Loop Prevention, Duplicate Detection

## Relay decision pipeline

`RelayEngine.ingest(packet, fromNode)` runs a strict pipeline. The first
matching rule wins; every drop is counted with a reason:

```
1. destination == local node          → DeliverUp (higher layers)
2. packet.source == local node        → Drop(ownPacket)   (we originated it)
3. TTLManager.expired(packet)         → Drop(ttlExpired)
4. DuplicatePacketDetector.seen(...)  → Drop(duplicate)
5. LoopDetector wouldReenter (path
   already contains the local node)   → Drop(loop)
6. route to destination exists        → Forward(nextHop, decrementedPacket)
7. destination is a direct neighbor   → Forward(neighbor)
8. otherwise                          → Drop(noRoute)   (+ possibly discovery)
```

**Prevent relay loops** — `LoopDetector` rejects any packet whose `path`
already contains the local node; combined with duplicate detection (rule 4)
this makes forwarding a DAG: a packet can never revisit a node, and each
node forwards it at most once per (source, sequence) pair.

**TTL flow** — on every forward the `TTLManager` decrements TTL; at 0 the
packet dies. TTL defaults to 8 and bounds flood (route discovery)
diameter, preventing infinite relay storms.

**Duplicate detection** — `DuplicatePacketDetector` keys on
`hash(source + ":" + sequence)`, stores `(key, seenAt)` in a capacity-
bounded map (default 2048 entries, TTL 10 s). On overflow the oldest
entries are evicted first — memory stays flat regardless of traffic.

**Reverse route learning** — every relayed packet teaches a route: the
packet's `path` shows who relayed it, so the relay installs (or improves)
a route toward `packet.source` via the last hop. This is how multi-hop
routes emerge without any route-protocol traffic.

## Relay queue

`RelayQueue` is the seam for the future store-and-forward phase:

- `enqueue(task)` / `next()` / `size` / `capacity` / `clear`
- The engine drains the queue on every sweep tick and after each transport
  send; `flush()` hands packets to the transport sink immediately.
- Store-and-forward later persists this queue and drains it when the
  destination reappears — the engine API does not change.

## Relay statistics

`MeshStatisticsTracker` records per-decision counters: forwarded,
delivered-up, dropped-by-reason (ttl, duplicate, loop, noRoute, queueFull,
ownPacket), packets seen, plus reliability sampling per next hop (for the
route cost model).

## Broadcast / flood semantics

Route-discovery requests use `destination = ""` (broadcast). They follow
rules 1–5, then relay to *all* neighbors (constrained by TTL and dedup).
The target's reply is unicast along the reverse path learned by each
relay.
