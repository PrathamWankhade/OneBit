# DTN Queues and Scheduling

## 1. Why eight queues?

The spec asks for outgoing, incoming, relay, retry, priority, expiration,
acknowledgement and deferred queues. These are **views over one envelope
store**, not eight copies of the data. A single `Map<packetId, DtnPacket>`
is the source of truth; each queue is an ordered view derived from
`state`/`direction` plus its sorting key. One envelope is visible in exactly
one *lifecycle* queue at a time, and in multiple *service* queues (e.g. it is
simultaneously in `expiration` order and `priority` order). This keeps memory
at one copy per envelope and makes every transition a single map move.

| View | Contains | Sorted by | Serves |
|---|---|---|---|
| outgoing | outbound, scheduled for delivery | priority desc, enqueuedAt asc | delivery pass |
| deferred | outbound, parked (no connectivity / retry limit hit) | expiresAt asc | re-arm on connectivity |
| retry | outbound, retrying with backoff | nextAttemptAt asc | retry window scan |
| incoming | inbound, awaiting upper layer | enqueuedAt asc | `observeDelivered()` |
| relay | relaying (multi-hop, awaiting next hop) | priority desc, enqueuedAt asc | forwarding pass |
| priority | live envelopes | priority desc, enqueuedAt asc | precedence decisions (dev + delivery) |
| expiration | live envelopes | expiresAt asc | expiry sweep (O(window)) |
| ack | envelopes awaiting ack | ackDeadlineAt asc | ack timeout scan |

## 2. Priority system

Five levels, stored as stable strings:

```
critical > high > normal > low > background
```

- Ordering is strict and total: `(priority, enqueuedAt)`.
- **critical** is delivered even when the connectivity gate is degraded
  (it is the only level that may pre-empt the deferred park).
- **background** packets are only attempted when the batch budget has room;
  they never wake the radio by themselves.
- Priority is persisted per envelope; a re-prioritization requires an
  explicit `store()`/update — the queue never re-sorts silently.

## 3. QueueManager

- `add/remove/move` keep the views consistent and emit one
  `DtnQueueSnapshot` per mutation (broadcast stream for the dev monitors).
- Lookup is O(1) by id; removal is O(1) + view bookkeeping.
- Overflow: `maxLiveEnvelopes` (default 10 000) — `store()` returns
  `DtnFailure(queueOverflow)` instead of unbounded growth.
- Duplicate `store()` for an id already pending returns the existing
  envelope (idempotent) — the caller sees the same id.

## 4. Delivery scheduler

Tick structure (injectable `now()`; app wiring uses a periodic timer,
tests advance the clock manually):

```
tick(now):
  1. expiration.run(now)            # cheap: only the due window
  2. retry.due(now)  -> move retrying->outgoing
  3. if !connectivity.reachable: park outgoing->deferred (except critical); stop
  4. forwarding.sweep()             # better relays appeared?
  5. delivery pass:
       budget = min(batchLimit, battery budget)
       candidates = outgoing.head(budget)
       for each: transmit -> outcome -> state transition (persisted)
  6. ack.run(now)                   # finalize / re-arm
```

Properties:

- **Connectivity gate first**: when unreachable, the tick is O(1).
- **Ordering is by priority, not FIFO**: `critical` traffic moves first even
  under a full queue.
- **Bounded work**: each pass consumes at most `batchLimit` (default 32)
  envelopes per tick; large floods drain over several ticks instead of
  flooding the radio.
- **Idempotent**: ticks may be re-entered (event-triggered) freely; state
  transitions are guarded by the persisted state.

### 4.1 Event-driven wakeups

`store()`, connectivity change, ACK arrival, topology change each call
`arm()` — the scheduler runs immediately, not at the next coarse tick, so
latency on reconnect is bounded by one processing pass.

## 5. Retry strategy

Retry is a *scheduling* concern, not a loop:

- Every failed transmit updates `attemptCount`, `lastAttemptAt`,
  `lastError` and computes `nextAttemptAt`:

```
delay(attempt) = min(baseDelay * 2^attempt + jitter, maxDelay)
```

  Defaults: `baseDelay = 30 s`, `maxDelay = 1 h`, jitter ±10 %.
- `retryLimit` (default 12) is not a drop trigger — DTN never drops a live
  packet for failing. Reaching the limit parks the envelope in `deferred`
  until connectivity returns (or it expires). This is the difference between
  a *transport* retry (gives up) and a *DTN* retry (waits).
- Transient vs permanent: a gateway error marked `permanent` (e.g. invalid
  destination refused) fails the envelope immediately — retrying a refused
  packet is battery waste.

## 6. Why deferred instead of a timer per packet?

Timers are battery and bookkeeping poison at thousands of packets. The
deferred view + connectivity stream gives the same behaviour with one global
re-arm: when the gate opens, everything parked re-enters `outgoing` in a
single pass, already priority-sorted.
