# Database Architecture

## Stack

| Layer | Choice | Rationale |
|---|---|---|
| Engine | SQLite | Single-file, zero-daemon, battle-tested offline store; supports millions of rows with proper indexes |
| ORM | Drift (codegen) | Typed queries, compile-time SQL validation, transactions, streamable `watch` queries, `Migrator` |
| Driver | `drift_flutter` + `sqlite3_flutter_libs` | Bundles native SQLite for Android/iOS/desktop; `sqlitecipher_flutter_libs` is already a transitive dep for the future SQLCipher switch |
| Repos | Hand-written `abstract interface class` + impl | Matches the existing `TrustContactRepository`/`IdentityRepository` convention |
| State | Riverpod 3 (manual providers) | No codegen for providers, per repo convention |
| Errors | `Result<T>` / `Failure` | DB errors map to `StorageFailure(operation: ...)` at the data edge |

## Module layout

```
lib/core/database/
├── database.dart              OneBitDatabase (@DriftDatabase), PRAGMA setup, migration wiring
├── database_provider.dart     Riverpod composition root for the database
├── config/                    DatabaseConfig (+ provider)
├── connection/                ConnectionFactory (default + in-memory), open policy
├── migration/                 MigrationStep registry + MigrationManager
├── tables/                    One file per domain; enums shared
├── models/                    Cross-cutting models (Page, summaries, backup header)
├── query/                     Paged queries and typed query objects
├── dao/                       DriftAccessor classes (typed CRUD + aggregates)
├── repository/                Result-wrapping repositories
├── cache/                     Read-through in-memory caches
└── backup/                    Export / import / integrity / compression / encryption
```

## Layering

```
presentation (UI) ──> providers ──> Repository (Result<T>) ──> DAO ──> OneBitDatabase ──> SQLite
                                         │ cache (read-through)          │ migrations
                                         └── AppLogger (tag: storage)    └── backup
```

- **Repository** is the only API surface consumed by features. It owns
  business rules (pagination, expiry, dedup), cache policy, and Result mapping.
- **DAO** is generated-adjacent: typed SQL access per aggregate (compiled
  queries = prepared statements).
- **Database** owns the connection, PRAGMAs and the migration strategy.
- **Features never import `dao/` or `tables/`** — they consume repositories.

## Database file & connection lifecycle

- File: `<app documents>/onebit.db` via `drift_flutter` (path_provider).
  One file per app install; WAL journal, `foreign_keys=ON`, `busy_timeout=5000`,
  `synchronous=NORMAL` (durable + fast under WAL).
- Opening is lazy: `OneBitDatabase` receives a `LazyDatabase` from the
  `ConnectionFactory`; the first query triggers open + migrations. No async
  bootstrap needed.
- `ConnectionFactory` is an interface so tests swap in
  `NativeDatabase.memory()`. The future SQLCipher switch only replaces the
  factory (see 09-future-expansion.md).

## Timestamps

Stored as INTEGER **epoch milliseconds** (via a `TypeConverter`), not text or
float. Gives sub-second precision (message ordering), 8-byte storage, fast
range scans, and is locale-independent.

## Secrets

- **No private key material is ever written to SQLite.**
- `identity.public_key` holds only public bytes; fingerprints are public.
- `messages.encrypted_payload` is an app-layer ciphertext blob by contract;
  `attachments.encrypted_data` likewise. SQLCipher (when enabled) then
  protects the whole file on top.
- Backups are plaintext only if no passphrase is supplied; with a passphrase
  the payload is wrapped in the existing `BackupCipher` (AES-256-GCM, HKDF,
  authenticated header).

## Failure boundary

Every repository method returns `Future<Result<T>>`. Drift exceptions are
caught at the DAO/repository edge and converted via `ExceptionMapper` to
`StorageFailure(operation: <table>.<action>)`. Streams map errors to
`Err(StorageFailure(...))` emissions. Logging happens once, at the boundary,
with `LogTags.storage`.
