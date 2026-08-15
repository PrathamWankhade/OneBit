# Migration Strategy

## Versioning

- `DatabaseConfig.schemaVersion` (currently `1`) is the single source of
  truth. It must equal `MigrationRegistry.currentVersion`.
- The committed schema snapshot lives at `dev_build/schema/` (generated with
  `dart run tool/generate_schema_snapshot.dart`). Tests verify the real
  database matches the snapshot on every CI run (`schema_snapshot_test.dart`).
- Drift generates the SQL for the current schema; each release of the app
  carries all `CREATE TABLE` statements from v1, so **onCreate always builds
  the newest schema for fresh installs**.

## Steps

```dart
// migration/migration_registry.dart
abstract final class MigrationRegistry {
  static const int currentVersion = 1;
  static const List<MigrationStep> steps = <MigrationStep>[
    // v2 example (future):
    // MigrationStep(targetVersion: 2, description: 'Add messages.expires_at',
    //   up: (m) => m.addColumn(messages, messages.expiresAt)),
  ];
}
```

A `MigrationStep` applies when `targetVersion > from && targetVersion <= to`.
`MigrationManager.apply()` sorts by target version and runs only the steps in
range, so upgrades N→M always apply the exact delta.

## Safety rules

1. **Forward compatible** — old app + new DB never happens (schema version is
   bumped with the app); new app + old DB runs only the delta.
2. **Rollback safe** — steps are additive (new columns/tables/indexes) or
   data-preserving (backfill). Destructive changes (drops, renames) are
   staged: add + backfill → migrate reads → drop in a later step.
3. **Transactional** — drift runs the whole `onUpgrade` in one transaction;
   a failed step rolls back to the previous version.
4. **Idempotent onCreate** — fresh installs use `Migrator.createAll()` which
   emits the final schema; `onCreate` never replays steps.
5. **Every migration has a test** — a migration test opens a DB at version N
   with real data, upgrades to N+1, and asserts data survival + new invariants
   (plus the schema snapshot comparison guards unversioned drift).

## Connection-level PRAGMAs (beforeOpen)

Applied on every connection, before migrations run:

```
PRAGMA foreign_keys = ON
PRAGMA busy_timeout = 5000
PRAGMA journal_mode = WAL          (no-op on :memory:)
PRAGMA synchronous = NORMAL
```

`foreign_keys` is per-connection in SQLite and must be re-applied after
reconnect — `beforeOpen` guarantees it.
