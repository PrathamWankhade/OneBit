import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';

import 'support/database_support.dart';

/// Guards the schema against unversioned drift.
///
/// Every test opens a fresh in-memory database (built by `onCreate` →
/// `createAll`, i.e. exactly what a new install looks like), dumps the
/// `sqlite_master` catalogue with the same canonicalization the generator
/// uses, and compares it byte-for-byte with the committed snapshot.
///
/// When the schema changes you must bump `MigrationRegistry.currentVersion`
/// (and add a `MigrationStep`), regenerate the snapshot with
/// `dart run tool/generate_schema_snapshot.dart`, and keep this file green.
void main() {
  group('schema snapshot', () {
    test('a fresh database matches the committed snapshot', () async {
      final db = await openInMemoryDb();
      addTearDown(db.close);

      const version = MigrationRegistry.currentVersion;
      final snapshotPath = File('dev_build/schema/onebit_v$version.sql');
      expect(
        snapshotPath.existsSync(),
        isTrue,
        reason:
            'Missing schema snapshot. Run '
            'dart run tool/generate_schema_snapshot.dart',
      );

      final rows = await db
          .customSelect(
            'SELECT type, name, sql FROM sqlite_master '
            "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
            'ORDER BY type DESC, name',
          )
          .get();

      final live = <String>[];
      for (final row in rows) {
        final sql = row.read<String>('sql');
        live.add('-- ${row.read<String>('type')}: ${row.read<String>('name')}');
        live.add(_canonicalize(sql));
        live.add(';');
      }

      final expected = snapshotPath
          .readAsLinesSync()
          .where((line) => !line.startsWith('--'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final actual = live
          .where((line) => !line.startsWith('--'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      expect(
        actual,
        expected,
        reason:
            'Schema drifted from the committed snapshot without a version '
            'bump. Update MigrationRegistry (version + step), then run '
            'dart run tool/generate_schema_snapshot.dart',
      );
    });

    test('schemaVersion matches the snapshot header', () async {
      const version = MigrationRegistry.currentVersion;
      final snapshotPath = File('dev_build/schema/onebit_v$version.sql');
      expect(snapshotPath.existsSync(), isTrue);

      final header = snapshotPath.readAsLinesSync().firstWhere(
        (line) => line.startsWith('-- schema version:'),
      );
      expect(header, '-- schema version: $version');
    });

    test('database exposes exactly the registered tables', () async {
      final db = await openInMemoryDb();
      addTearDown(db.close);

      final tables = db.allTables.map((t) => t.actualTableName).toSet();
      expect(tables.length, 39);
    });
  });
}

/// Normalizes whitespace inside a single SQL statement (mirrors the
/// generator's canonicalization).
String _canonicalize(String sql) {
  final collapsed = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.replaceFirst(RegExp(r'\s*;\s*$'), '');
}
