# Repository Pattern

## Layering

```
feature (domain)          Repository interface (abstract, per feature)
lib/core/database/
  repository/             DatabaseRepository impls — Result boundary, cache policy, business rules
  dao/                    Drift DAOs — typed SQL, compiled/prepared queries, transactions
  database.dart           OneBitDatabase — connection, PRAGMAs, migrations
```

## Contracts

Repositories are hand-written `abstract interface class` per feature (matching
`TrustContactRepository` today), and this module provides the concrete
`*Repository` classes that will back them in later phases:

| Repository | Owns | Rules |
|---|---|---|
| `IdentityRepository` | identity row, trusted nodes, node profiles | single-row identity, trust CRUD |
| `ChannelRepository` | channels | unread counters, archive/pin/mute |
| `MessageRepository` | messages + attachments + receipts | pagination, dedup by id, status transitions, search |
| `PacketRepository` | packets + fragments | expiry, reassembly, retention |
| `RouteRepository` | routes | best-route pick, pruning |
| `NeighborRepository` | neighbors | staleness, presence order |
| `SessionRepository` | sessions + keys | ratchet step bookkeeping |
| `SettingsRepository` | settings, application metadata | JSON values, watch |
| `StatisticsRepository` | statistics + aggregates | counters, gauges, snapshot |

## Result boundary

Every method: `Future<Result<T>>`; stream watches: `Stream<Result<T>>`.

- DAO/Drift exceptions are caught at the repository edge and mapped with
  `ExceptionMapper` to `StorageFailure(operation: '<table>.<method>')`.
- The mapper gains a Drift-aware case (`SqliteException` → `StorageFailure`).
- Failures are logged once, at creation, tagged `LogTags.storage`.
- Streams never throw — a query failure emits `Err(...)` and the stream
  continues (re-subscription policy per watch).

## Transactions & batches

- Multi-write invariants (message + attachments, packet + fragments, backup
  import) run inside `db.transaction(() async { ... })`.
- Bulk inserts use drift `batch.insertAll` with conflict strategies
  (`insertOnConflictUpdate` for idempotent re-delivery).
- DAOs expose `Future<void>` helpers that repositories wrap with Result.

## Read paths

- DAOs expose typed `select(...)`/`selectOnly(...)` with compiled queries —
  Drift compiles each query once and prepares statements on first use
  (prepared statement requirement).
- Pageable reads use `PageRequest` (offset/limit/order) and return `Page<T>`.
- Writes invalidate the read-through cache via repository (never inside DAO —
  DAOs stay cache-agnostic).
