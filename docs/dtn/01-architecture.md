# DTN Architecture — Store-and-Forward for OneBit

Status: Phase 7 baseline. No servers, no internet, no cloud — every node must
deliver eventually, across offline periods, partitions, reboots and
intermittent Bluetooth.

## 1. Problem statement

OneBit is a decentralized Bluetooth-mesh messaging platform. The transport is
ephemeral: links drop mid-transfer, destinations go to sleep, and the network
can split into disconnected partitions for hours or months. A message handed
to the mesh at the wrong moment is lost forever unless a layer above the
transport *refuses to give up on it*.

That layer is the DTN engine.

## 2. Design goals

| Goal | Requirement | Mechanism |
|---|---|---|
| Eventual delivery | A packet is delivered whenever connectivity permits, until it expires | Persistent store + scheduler + retry |
| Months offline | Thousands of queued packets survive reboot, app kill, battery cycles | Drift persistence, restart-safe recovery |
| No loss on disconnect | Transmit failure never destroys a packet | Store-then-forward: payload is durable *before* the first attempt |
| No duplicate delivery | Retries must not double-deliver | Delivery state machine + idempotent ACK |
| Bounded cost | No CPU/memory/battery burn while offline | Tick-based scheduler with connectivity gate and delivery budget |
| Independent of UI | DTN never imports Flutter widgets | Pure-Dart core; Riverpod only at the presentation seam |

## 3. Where DTN sits

```
┌──────────────────────────────┐
│  Messaging Engine (Phase 8)  │  enqueue() → stream of delivered packets
├──────────────────────────────┤
│  DTN Engine  (this phase)    │  store → persist → schedule → transmit → ack
├──────────────────────────────┤
│  Packet Protocol (Phase 6)   │  serialize/fragment/reassemble/validate
├──────────────────────────────┤
│  Mesh Routing  (Phase 5)     │  discover routes, relay, topology
├──────────────────────────────┤
│  Bluetooth Transport (Phase4)│  BLE scan/advertise/connect
└──────────────────────────────┘
```

The DTN engine is the only layer allowed to *hold on* to a packet. Every layer
below it is best-effort; DTN makes the system eventual.

## 4. Core abstraction: the envelope

A `DtnPacket` (the *envelope*) is an immutable value:

- `packetId` — `localNode:sequence`, unique per source.
- `source` / `destination` — node ids.
- `payload` — opaque bytes (message, relay, ack, or control).
- `priority` — critical | high | normal | low | background.
- `ttlSeconds` / `expiresAt` — wall-clock expiry (createdAt + ttl).
- `direction` — outbound (own packets), inbound (to upper layers), relay.
- `state` — the persisted lifecycle status (see §7).
- `attemptCount`, `lastAttemptAt`, `nextAttemptAt`, `lastError` — retry bookkeeping.
- `ackState` — none | awaiting | received | timedOut, plus `ackDeadlineAt`.

One row per envelope in the `DtnPackets` table. The envelope **is** the packet:
there is no second representation to drift out of sync.

## 5. Component diagram

```
                        ┌─────────────────────────────────────────┐
                        │              DTNEngine                  │
                        │  facade: store/cancel/ack/start/stop    │
                        └──────┬────────────────────┬─────────────┘
             owns              │                    │ streams
┌──────────────────────────────────────────┐   ┌────┴──────────────────┐
│         StoreForwardEngine              │   │  DeliveryStatistics   │
│  the transition state machine           │   │  DiagnosticsEngine    │
└───────┬────────┬────────┬───────────────┘   └───────────────────────┘
        │        │        │
┌───────▼───┐ ┌──▼──────┐ ┌▼────────────┐   ┌──────────────────────┐
│QueueMgr   │ │Delivery │ │RetryManager │   │AcknowledgementManager │
│8 ordered  │ │Scheduler│ │backoff+jitter│   │ack flow, duplicates  │
│views      │ └────┬─────┘ └─────────────┘   └──────────┬───────────┘
└───────┬───┘      │                                    │
        │          │                                  ┌─▼─────────────┐
┌───────▼───┐ ┌────▼─────┐   ┌──────────────────────┐ │ForwardingEngine│
│Expiration │ │Recovery  │   │PacketPersistenceMgr  │ └───────┬───────┘
│Manager    │ │Manager   │   │(Drift DtnDao)        │         │
└───────┬───┘ └──────────┘   └──────────────────────┘         │
        │                    ┌──────────────────────┐   ┌─────▼──────────┐
        └───────────────────►│     DtnGateway       │◄──┤ DtnTopologySrc │
            expires          │ transmit / deliver   │   │ visibility     │
                             └──────────┬───────────┘   └────────────────┘
                                        │ (adapters in data/)
                          PacketRepository (Phase 6) + MeshEngine
```

Dependency rules:

- Domain, queue, scheduler, retry, ack, forwarding, expiration, statistics,
  diagnostics, store, persistence — **pure Dart**, no Flutter imports.
- `data/` holds the adapters: drift persistence and the mesh/packet gateway.
- `presentation/` holds Riverpod providers and the developer screens only.

## 6. Store-and-forward design

The invariant that makes the whole system correct:

> **A packet is durable before it is ever transmitted.**

`store()` flow:

```
store(envelope) ──► PersistenceManager.upsert (durable, fsync) ──Ok──► QueueManager.add
                                                                        │
                                                    outbound, priority-ordered
                                                                        ▼
                                                          DeliveryScheduler.arm()
```

The scheduler only ever transmits packets that exist in both the in-memory
queue set and the database. Consequences:

- A crash between persistence and transmit loses nothing (the packet simply
  resumes at recovery).
- A crash during a transmit attempt loses nothing (the retry bookkeeping is
  updated only *after* the outcome is known, and the state transition is
  persisted before the queue view changes).
- The destination being offline is a scheduling concern, never a data-loss
  concern: the packet parks in the deferred view until connectivity returns.

## 7. Packet lifecycle state machine

```
                  store()                     connectivity lost
   (new) ─────────────────► outbound ◄───────────────────────── retrying
                              │  │                                  ▲
                    scheduled │  │ connectivity lost                │ backoff due
                              ▼  │                                  │
                          pending_delivery ──transmit Ok (hop)──► relaying ──► delivered
                              │  transmit Err / ack timeout             (ack received)
                              ▼
                          retrying ──(attempts < limit)──► outbound (re-armed)
                              │
                              │ (attempts ≥ limit)  ──► deferred (parked, not lost)
                              ▼
                          deferred ◄──── connectivity returns ──► outbound
   inbound:  (new) ──► inbound ──► delivered-to-upper-layer ──► auto-ack sent
   any state: expiresAt <= now ──► expired (cleaned from queues and db)
```

Transitions are centralized in `StoreForwardEngine`; every transition is
persisted before it becomes visible, so the state machine is crash-safe.

## 8. Eventual delivery loop

The scheduler runs on a tick (injectable clock — tests advance it manually,
the app uses a periodic timer) and on events:

1. **Expire sweep** — drop envelopes past `expiresAt` (cheap, sorted view).
2. **Connectivity gate** — read the latest connectivity snapshot; when the
   network is unavailable, outbound work parks (deferred), the tick costs ~0.
3. **Retry window** — envelopes whose `nextAttemptAt` is due rejoin the
   deliverable set.
4. **Forwarding pass** — opportunistically move relay candidates when the
   topology improved (§11).
5. **Delivery pass** — transmit up to `batchLimit` envelopes in priority
   order (critical first), honoring the battery budget.
6. **Ack pass** — finalize acked packets, re-arm timed-out ones.

Every pass is idempotent and bounded — a tick is O(candidates) with small
constants.

## 9. Failure model

All failures are `Failure` values inside `Result`s (core/errors). The DTN
layer adds `DtnFailure` (queue overflow, already expired, already pending,
persistence error, gateway error, recovery error). Nothing crosses the feature
boundary as an exception.

## 10. Fault tolerance summary

| Fault | Behaviour |
|---|---|
| Destination offline | Envelope parked in deferred view; nothing is lost |
| Route disappears | Topology change re-arms forwarding; packet waits |
| Bluetooth disconnect | Transmit fails → retry with backoff; on limit → deferred |
| Device reboot | Recovery manager restores every envelope from `DtnPackets` in its persisted state |
| Network partition | Both sides keep their queues; partition merge re-arms both schedulers via connectivity/topology streams |
| Corrupt row | DAO read failure logged; the rest of the queue is unaffected (row-level isolation) |
| DB failure | Persistence failure surfaces to store(); in-memory queues keep running with degraded durability |
| Duplicate ACK | Ack ledger is idempotent; second ack is a no-op |
| Ack lost | `ackDeadlineAt` expires → envelope re-enters delivery with a fresh ack request |

## 11. Opportunistic forwarding

`ForwardingEngine` consumes `DtnTopologySnapshot` (routes + neighbors +
quality) and, for every relayable envelope, applies `DtnRelayPolicy`:

- direct route to destination beats any relay;
- otherwise prefer the candidate with the best blend of fewer hops, higher
  RSSI, trusted status and delivery success history;
- a "better relay appeared" event re-arms the queue so the packet moves
  immediately instead of waiting for the next tick.

Forwarding is *advisory*: the decision is re-made per attempt, because topology
changes between ticks.

## 12. Battery & CPU optimization

- **No timers while parked**: the scheduler wakes on events (store,
  connectivity, ack, topology) and on a coarse tick; when the connectivity
  gate is closed the tick does O(1) work.
- **Delivery budget**: `batchLimit` + optional `DeliveryBudget` (battery
  state lands here when the platform provides it) — bursts are amortized
  across ticks instead of draining the radio.
- **Deferred index**: expiry and retry windows are sorted views, so each
  pass scans only the due window, not the whole queue.
- **Batch persistence**: transitions are coalesced per tick into batched
  drift writes.
- **No polling for ACKs**: ack deadlines are part of the sorted retry view.

## 13. Scalability targets

- 10 000+ envelopes: in-memory index is a hash map; queues are ordered views,
  never O(n) scans per tick (only the due window is visited).
- Months offline: expiry keeps the table bounded; nothing transmits until the
  gate opens.
- Multiple partitions merging at once: the recovery + forwarding passes are
  re-armed once per topology change; work is amortized across ticks.

## 14. Phase 8 integration (messaging) — no future changes required

The DTN engine exposes `DTNRepository`, the exact seam Phase 8 consumes:

- `store(destination, payload, priority, ttl)` → `Future<Result<String>>`
  (returns the envelope id).
- `observeDelivered()` → stream of envelopes whose direction is inbound and
  whose payload is the message body.
- `cancel(packetId)`, `statusOf(packetId)`, `observeQueue()`,
  `observeStatistics()`.

The messaging engine never touches queues, retries or the database — it calls
`store()` and listens. Because the envelope is already the durable unit, a
message survives months of offline time and arrives as a fully-formed
`DtnPacket` that Phase 8 maps to its message model. ACK envelopes are handled
inside the DTN layer and never surface upward.

## 15. Folder structure

```
features/dtn/
  domain/        envelope, priority, connectivity/topology snapshots,
                 statistics, diagnostics events, repository interface, failures
  queue/         QueueManager + the eight ordered queue views
  scheduler/     DeliveryScheduler, DeliveryBudget
  retry/         RetryManager (exponential backoff + jitter + limits)
  delivery/      DtnGateway, DtnGatewayOutcome, DtnTopologySource
  forwarding/    ForwardingEngine, DtnRelayPolicy
  ack/           AcknowledgementManager
  expiration/    PacketExpirationManager
  statistics/    DeliveryStatistics (recorder + snapshot)
  diagnostics/   DiagnosticsEngine (bounded event log)
  store/         StoreForwardEngine (state machine)
  data/          DtnDao adapter (drift), PacketPersistenceManager,
                 NetworkRecoveryManager, DTNRepositoryImpl, mesh gateway adapter
  presentation/  providers + developer screens
core/database/
  tables/dtn_tables.dart   DtnPackets (schema v2)
  dao/dtn_dao.dart
```

See `02-queues-and-scheduling.md` for the queue and scheduler design and
`03-delivery-lifecycle.md` for retry, ACK, expiration and recovery detail.
