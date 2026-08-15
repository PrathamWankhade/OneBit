import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../config/database_config.dart';

/// Creates the [QueryExecutor] backing the [OneBitDatabase].
///
/// This is the single seam for the storage engine: swapping SQLite for
/// SQLCipher (encryption), sharding, or per-channel files later replaces only
/// this factory — tables, DAOs and repositories stay untouched.
abstract interface class ConnectionFactory {
  /// Opens (lazily, where supported) a query executor for [config].
  ///
  /// Implementations return immediately; actual file opening happens on the
  /// first executed query.
  QueryExecutor open(DatabaseConfig config);
}

/// Production factory: a real on-disk SQLite database in the app documents
/// directory, with bundled native sqlite3.
final class DriftFlutterConnectionFactory implements ConnectionFactory {
  const DriftFlutterConnectionFactory();

  @override
  QueryExecutor open(DatabaseConfig config) {
    assert(!config.inMemory, 'Use InMemoryConnectionFactory for in-memory dbs');
    return driftDatabase(name: config.name);
  }
}

/// Test/ephemeral factory: a fresh in-memory SQLite database per open.
final class InMemoryConnectionFactory implements ConnectionFactory {
  const InMemoryConnectionFactory();

  @override
  QueryExecutor open(DatabaseConfig config) => NativeDatabase.memory();
}
