# Testing Strategy

## Harness

- `test/core/database/database_test_support.dart` — `openTestDatabase()` opens
  a real in-memory SQLite (`NativeDatabase.memory()`) with the real migration
  strategy, so every test exercises actual SQL, FKs, and PRAGMAs.
- No mocks of SQLite — only fakes for logger/caches where needed.
- Tests run on CI (`flutter test`) with the committed schema snapshot.

## Matrix

| Suite | File | Verifies |
|---|---|---|
| Schema | `schema_test.dart` | all 25 tables exist, column types, FK enforcement, cascade deletes |
| Migration | `migration_test.dart`, `migration_rollback_test.dart` | step ordering, range filtering, atomic rollback of failing steps, data survival |
| DAOs | `dao/*_test.dart` | CRUD per aggregate: identity, channels, messages (pagination, batch, unread), packets (fragments, expiry), routes (best-next-hop), neighbors (staleness), sessions (ratchet), settings, statistics, queues, logs |
| Repositories | `repository/*_test.dart` | Result wrapping, `StorageFailure` mapping on engine errors, cache invalidation on writes, stream error emission |
| Backup | `backup_test.dart` | export→import roundtrip preserves all rows; tamper, bad magic, future version, newer schema, wrong passphrase all fail typed |
| Cache | `cache_test.dart` | TTL expiry, capacity eviction, invalidation, single-flight miss |
| Transactions | `transaction_test.dart` | atomic multi-table writes; mid-transaction failure rolls back everything |
| Performance | `performance_test.dart` | batch-insert 10k messages + pagination under a generous bound; asserts correctness of paging |

## Conventions

- Each test file opens/closes its own database (`addTearDown(db.close)`).
- Repository tests assert `Ok`/`Err` shapes with `.value`/`.failure` — never
  throw-based assertions.
- Edge cases: empty tables, `offset > total`, duplicate ids (idempotent
  upserts), expired packets, unknown enum values (defensive parsing),
  nulls in nullable columns, negative timestamps.
