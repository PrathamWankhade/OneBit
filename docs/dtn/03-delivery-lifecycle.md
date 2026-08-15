# DTN Delivery Lifecycle, ACK, Expiration, Recovery

## 1. Acknowledgements

OneBit has transport-level best effort only (Phase 4–6: no per-link ACK for
data). The DTN layer therefore implements its own logical acknowledgment flow.

### 1.1 ACK envelopes

The receiver's DTN layer, when a packet reaches the local node (directly or
relayed), transitions the envelope to `inbound` and — unless the packet was
itself a control frame — sends an **ack envelope** back to the source. The
ack envelope is itself a DTN packet (`envelopeType = ack`) whose payload is
the acked `packetId`. Ack envelopes:

- respect a **lower priority** than data (they are cheap; they must not
  starve the data queues);
- are **deduplicated**: the ACK manager keeps a bounded, time-boxed ledger of
  recently seen `dtnAck` ids — a duplicate ack is a no-op.

### 1.2 Sender-side ack state

Each outbound envelope carries `ackState`:

```
none ──► awaiting ──► received ──► (delivered; envelope removed)
               │
               └──► timedOut (deadline): enqueue again with fresh ack request
```

- `transmitOk` without a receiver ack only means "handed to the mesh" —
  the envelope stays `awaiting` until the ack deadline.
- `ackDeadlineAt = lastAttempt + ackTimeout` (default 5 minutes).
- On `timedOut`, the envelope re-enters the delivery pass; the mesh layer's
  duplicate detection (Phase 5) keeps duplicate frames rare, and the ack is
  idempotent on both sides, so re-sending is safe.

### 1.3 ACK flow (sequence)

```
Sender                                   Receiver
  │ store(msg A)                            │
  │ persist + queue                         │
  │ tick: transmit A ──────────────────────►│ envelope arrives
  │ ackState = awaiting, deadline set       │ direction=inbound, store
  │                                         │ deliver to upper layer
  │ ◄────────────────── store(ack for A)    │ (observeDelivered)
  │ ack ledger: received                    │
  │ envelope A → delivered, cleanup         │
```

## 2. Expiration

- `expiresAt = createdAt + ttlSeconds` (enforced at `store()` and after
  reboot — a packet can never outlive its TTL across a restart).
- The expiry sweep visits only the due window of the expiration view.
- Expired envelopes are removed from all views **and** from `DtnPackets`;
  their counters (`expiredCount`) and diagnostics event are recorded; no
  upper-layer signal is emitted (the message simply never existed for the
  caller beyond its TTL contract).
- A retry that would land after `expiresAt` is not scheduled at all —
  the envelope expires instead of wasting a transmission window.

## 3. Recovery after restart

`NetworkRecoveryManager.restore()` is the loader:

1. `DtnDao.selectAll()` → all envelopes in one bounded read.
2. State is grouped back into the matching views (outgoing / deferred /
   retrying / relaying / incoming / awaiting-ack — mirroring how the
   scheduler left them).
3. Per-envelope consistency fixes:
   - `nextAttemptAt` in the past but state `retrying` → schedule now (the
     reboot missed the window);
   - `ackDeadlineAt` in the past but state awaiting → timedOut, re-arm;
   - `expiresAt` passed → expire immediately;
   - attempts preserved (no phantom restarts after a crash mid-retry).
4. The connectivity snapshot is re-read; `arm()` is called, and delivery
   resumes from exactly where the node stopped.

`restore()` is idempotent and the engine is indistinguishable from a node
that stayed awake.

## 4. Long-offline behaviour

- Offline months: queues hold; expiration prunes TTL'd envelopes; the tick
  gate keeps work at O(1) per wakeup.
- Reconnect: connectivity stream fires → deferred/retrying envelopes re-arm in
  priority order → delivery drains within the batch budget.
- Partition merge: both sides restore the same envelopes; mesh duplicate
  detection + idempotent ACKs make the merge lossless.

## 5. Statistics & diagnostics

`DeliveryStatistics` records counters (stored, delivered, expired, retried,
acked, relayed, deduplicated, parked, recovered) and gauges (live queue size,
average delivery latency over the last N deliveries) — broadcast snapshot
stream, and persisted into the shared `Statistics` table via `StatisticsDao`
at the adapter layer.

`DtnDiagnosticsEngine` keeps a bounded (e.g. 200) ring of events
(stored/attempt/deliver/retry/expiry/recover/ack/connectivity-change) with
structure exposed to the dev screens; the same events go to `AppLogger` with
tag `dtn`. `LogTags.dtn` is registered so the dev log streams pick it up.

## 6. Component responsibilities (one line each)

- `PacketPersistenceManager` — single read/upsert/delete seam for
  `DtnPackets`, transactional, coalesced per transition.
- `NetworkRecoveryManager` — `restore()` above; also re-arms after app
  restart and after every connectivity change.
- `DeliveryStatistics` — flattened recorder + snapshot + persistent sink.
- `AcknowledgementManager` — ledger, deadline enforcement, idempotence.
- `PacketExpirationManager` — sweep + TTL healing after restore.
- `StoreForwardEngine` — owns the state machine; the only place transition
  edges live.
- `DTNEngine` — facade: `store`, `cancel`, `statusOf`, `acknowledge`,
  `start/stop`, streams. The `DTNRepository` (Phase 8 seam) is implemented
  over it without touching its internals.