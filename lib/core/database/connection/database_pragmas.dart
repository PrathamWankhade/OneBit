import 'package:drift/drift.dart';

/// Connection-level SQLite pragmas applied on every connection, before
/// migrations run.
///
/// `foreign_keys` is per-connection in SQLite — it MUST be re-applied after
/// every reconnect, which `MigrationStrategy.beforeOpen` guarantees.
abstract final class DatabasePragmas {
  const DatabasePragmas._();

  static const int busyTimeoutMs = 5000;

  static Future<void> apply(GeneratedDatabase db) async {
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement('PRAGMA busy_timeout = $busyTimeoutMs');
    // WAL keeps readers/writers concurrent; no-op on :memory: databases.
    await db.customStatement('PRAGMA journal_mode = WAL');
    // NORMAL is durable under WAL and avoids per-transaction fsync storms.
    await db.customStatement('PRAGMA synchronous = NORMAL');
  }
}
