# OneBit Database Module

The offline persistence layer — SQLite via Drift, repository-driven, offline-first.

## Documents

| Doc | Covers |
|---|---|
| [01-database-architecture.md](01-database-architecture.md) | Stack, layering, database file, connection lifecycle |
| [02-er-diagram.md](02-er-diagram.md) | Schema, ER diagram, relationships, indexes |
| [03-migration-strategy.md](03-migration-strategy.md) | Versioned migrations, safety, testing |
| [04-repository-pattern.md](04-repository-pattern.md) | DAO → Repository layering, Result boundary |
| [05-caching-strategy.md](05-caching-strategy.md) | In-memory read-through caches |
| [06-performance-strategy.md](06-performance-strategy.md) | Indexes, transactions, batches, pagination |
| [07-backup-strategy.md](07-backup-strategy.md) | Export/import, integrity, compression, encryption |
| [08-testing-strategy.md](08-testing-strategy.md) | Test matrix and harness |
| [09-future-expansion.md](09-future-expansion.md) | Sync, SQLCipher, multi-million-row growth |

## Non-goals (this phase)

Bluetooth, BLE advertising/scans, mesh routing, packet relay, messaging UI,
cryptographic sessions. The schema reserves the tables for them; the DAO layer
already exposes CRUD so later phases only add logic, never schema redesign.

## Key invariants

- **SQLite is the source of truth.** No in-memory truth; caches are read-through.
- **Everything returns `Result<T>`.** Failures are mapped to
  `StorageFailure` at the data edge, never thrown.
- **No plaintext secrets in the DB.** Private keys stay in the Android
  Keystore; message payloads are ciphertext blobs by design.
- **Versioned from day one.** Every migration is a versioned step; the schema
  snapshot is committed under `dev_build/schema/` (regenerate with
  `dart run tool/generate_schema_snapshot.dart`) and verified on every test run.
- **Flavor-independent.** The database is one file per app install; flavors
  only change the app id, not the schema.
