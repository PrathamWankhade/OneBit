# DTN Simulation and Testing

Status: Phase 7. Documents the simulation harness and the test suite for the
store-and-forward engine, and how they exercise the failure scenarios DTN
exists for.

## 1. The simulator

`features/dtn/simulation/` contains a headless multi-node harness:

| Type | File | Purpose |
|---|---|---|
| `DtnSimulator` | `simulation/dtn_simulator.dart` | Multi-node cluster; per-node engine + controllable `SimulatedMeshGateway` + shared manual clock |
| `DtnSimNode` | same file | One node: `StoreForwardEngine` over `MemoryDtnPersistence` |
| `DtnScenarioRun` | `simulation/dtn_scenarios.dart` | Named run with a set of pass/fail checks |
| `DtnScenarios` | `simulation/dtn_scenarios.dart` | The scenario catalogue |

The simulator drives the *same* engine code the app runs — there is no test
double for the engine itself. Scenarios toggle reachability, step the wall
clock, and call the scheduler pass directly (no real timers, so runs are
deterministic and fast).

### How a scenario is driven

```
sim.addNode('a');          // create an isolated engine
sim.setReachable('a', false);            // gateway reports offline
sim.store('a', packetId: 'p1', destination: 'b');  // durable store
sim.advance(Duration(minutes: 5));       // clock + one scheduler pass per node
```

`advance()` runs one scheduling pass per node: expiry sweep → connectivity
gate → retry re-arm → forwarding re-arm → delivery batch → ack pass — exactly
matching `DeliveryScheduler.tick`.

## 2. Scenarios covered

| Scenario | What it proves |
|---|---|
| `offlineNode` | Stored envelopes survive offline time parked (deferred), never dropped |
| `reconnect` | Connectivity restored ⇒ parked envelopes auto-resume and deliver |
| `largeQueue1000` | 1000 queued packets drain through bounded batches without loss |
| `delayedDelivery` | Flapping link — eventual delivery after every gap |
| `networkPartitionAndMerge` | Isolated groups keep state; merge resumes both sides |
| `queueRecovery` | "Reboot": fresh engine restored from serialized envelopes continues delivery |
| `retryStorm` | Transient gateway failures → exponential backoff → all drain, none lost |
| `packetExpiration` | TTL expiry removes packets even while offline |

Run with:

```sh
flutter test tool/dtn_simulation.dart
```

## 2. Unit tests

The DTN test suite lives in `test/features/dtn/` reusing one harness
(`support/dtn_test_support.dart`: `DtnHarness` + `TestGateway` + `TestClock`):

| File | Coverage |
|---|---|
| `dtn_engine_test.dart` | Store/restore/ack/cancel engine behaviour (pre-existing) |
| `dtn_persistence_test.dart` | Sqlite round-trips, idempotent upsert, delete, row mapper (pre-existing) |
| `dtn_queue_test.dart` | Every `QueueManager` view, counts, ordering (priority/expiry), priority scheduler batch & buckets |
| `dtn_retry_test.dart` | Backoff math, retry limit, due windows, immediate retry, tracker |
| `dtn_ack_test.dart` | Delivery/relay/forward ACKs, duplicate detection, timeouts, pending counters |
| `dtn_store_forward_test.dart` | Store/deliver/park/critical exemption/ack re-arm/cancel/relay |
| `dtn_recovery_test.dart` | Restore repairs deadlines, prunes expired, resumes delivery |
| `dtn_expiration_test.dart` | TTL + max-age sweeps, expiring soon, next expiration, stats |
| `dtn_stress_test.dart` | 2000-envelope offline restart + drain; priority storm ordering |

### Key properties asserted

- **No loss offline**: 2000 envelopes stay alive one simulated day.
- **Eventual delivery**: every parked envelope re-enters delivery once the
  gateway is reachable.
- **Priority is total**: in a mixed critical/background storm no critical
  packet transmits after a background one in any batch.
- **Deduplication**: a second `acknowledge()` for the same packet id is a no-op.
- **No fake engine**: persistence-facade tests run against real drift DB
  (`dtn_persistence_test.dart`).

Run with:

```bash
flutter test test/features/dtn
```

## 3. Developer screens

`presentation/dtn_dev_screen.dart` renders the DTN surface used during
development:

- **Connectivity** — simulated mesh toggle; park/unpark visible.
- **Queue monitor** — outgoing/deferred/retry/incoming/relaying/awaiting-ack +
  live totals.
- **Retry viewer** — envelopes on backoff with attempt count and next window.
- **Forwarding** — relayed counters + current relaying envelopes.
- **ACK monitor** — acked/deduplicated counters + awaiting list with deadlines.
- **Packet lifetime** — per-envelope priority/created/expires/state.
- **Statistics** — stored/delivered/expired/retried/parked/deduplicated +
  average latency.
- **Diagnostics** — bounded ring of engine transition events.

## 7. Persisted statistics

The statistics stream is mirrored to the shared `Statistics` table by
`DtnStatisticsPersister` (keyed under `dtn.*`). Updating is idempotent
(gauge-style absolute values), so re-running a snapshot never double-counts.
Wiring: `dtnStatisticsSinkProvider` keeps a subscription alive as long as the
`dtnRepositoryProvider` is watched.