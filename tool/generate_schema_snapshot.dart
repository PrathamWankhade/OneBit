// Generates the committed schema snapshot used to verify migrations and to
// guard against unversioned schema drift.
//
// Usage:
//   dart run tool/generate_schema_snapshot.dart
//
// Output:
//   dev_build/schema/onebit_v1.sql
//
// The snapshot is a canonical, normalized dump of the `sqlite_master`
// catalogue produced by `OneBitDatabase` on a fresh install. Because drift
// emits the final schema through `onCreate` (Migrator.createAll), this dump
// is exactly what a new database looks like at the current schema version.
//
// When the schema changes (tables, columns, indexes, FKs):
//   1. bump MigrationRegistry.currentVersion and add a MigrationStep,
//   2. run this tool again to refresh the snapshot,
//   3. keep schema_snapshot_test.dart green (it compares the live database
//      against this file on every test run).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';

Future<void> main() async {
  const version = MigrationRegistry.currentVersion;
  final db = OneBitDatabase(NativeDatabase.memory());
  try {
    // Force the schema to be created (onCreate -> createAll), then dump the
    // catalogue exactly like schema_snapshot_test.dart does.
    await db.customSelect('SELECT 1').get();

    final rows = await db
        .customSelect(
          'SELECT type, name, sql FROM sqlite_master '
          "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
          'ORDER BY type DESC, name',
        )
        .get();

    final buffer = StringBuffer()
      ..writeln('-- OneBit database schema snapshot')
      ..writeln('-- schema version: $version')
      ..writeln('-- Do not edit by hand. Regenerate with:')
      ..writeln('--   dart run tool/generate_schema_snapshot.dart')
      ..writeln();

    for (final row in rows) {
      final type = row.read<String>('type');
      final name = row.read<String>('name');
      final sql = row.read<String>('sql');
      buffer
        ..writeln('-- $type: $name')
        ..writeln(_canonicalize(sql))
        ..writeln(';')
        ..writeln();
    }

    final outDir = Directory('dev_build/schema');
    await outDir.create(recursive: true);
    final outFile = File('${outDir.path}/onebit_v$version.sql');
    await outFile.writeAsString(buffer.toString());
    stdout.writeln('Wrote ${outFile.path} (${rows.length} objects)');
  } finally {
    await db.close();
  }
}

/// Normalizes whitespace inside a single SQL statement so the snapshot stays
/// stable across SQLite builds that emit slightly different whitespace.
String _canonicalize(String sql) {
  final collapsed = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.replaceFirst(RegExp(r'\s*;\s*$'), '');
}
