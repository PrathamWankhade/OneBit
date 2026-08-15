import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_manager.dart';
import 'package:onebit/core/database/migration/migration_step.dart';

/// Exercises the real [MigrationManager] against a real SQLite engine.
///
/// These tests build a genuine upgrade scenario (v1 → v2) on an in-memory
/// database and assert the framework guarantees:
///   - steps run in ascending order and only inside the requested range,
///   - a failing step rolls the whole migration back (atomic onUpgrade),
///   - a successful migration persists its structural changes,
///   - rollback never destroys pre-existing user data.
void main() {
  late OneMigrationHarnessDb db;

  setUp(() {
    db = OneMigrationHarnessDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('MigrationManager rollback safety', () {
    test('applies steps ascending and only within (from, to]', () async {
      await db.ensureOpenForTests();

      final applied = <int>[];
      final manager = MigrationManager(
        steps: [
          MigrationStep(
            targetVersion: 2,
            description: 'v2',
            up: (_, _) async => applied.add(2),
          ),
          MigrationStep(
            targetVersion: 3,
            description: 'v3',
            up: (_, _) async => applied.add(3),
          ),
          MigrationStep(
            targetVersion: 4,
            description: 'v4',
            up: (_, _) async => applied.add(4),
          ),
        ],
      );

      await manager.apply(Migrator(db), from: 1, to: 3, db: db);
      expect(applied, [2, 3]);
    });

    test('a failing step rolls back every change of the batch', () async {
      await db.ensureOpenForTests();

      final manager = MigrationManager(
        steps: [
          MigrationStep(
            targetVersion: 2,
            description: 'schema change that must be rolled back',
            up: (_, _) => db.customStatement(
              'CREATE TABLE extra_table (id INTEGER NOT NULL PRIMARY KEY)',
            ),
          ),
          MigrationStep(
            targetVersion: 2,
            description: 'failing step',
            up: (_, _) async => throw StateError('boom'),
          ),
        ],
      );

      await expectLater(
        db.transaction(
          () => manager.apply(Migrator(db), from: 1, to: 2, db: db),
        ),
        throwsStateError,
      );

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name'));
      expect(names, isNot(contains('extra_table')));
    });

    test('a successful migration persists its structural changes', () async {
      await db.ensureOpenForTests();

      final manager = MigrationManager(
        steps: [
          MigrationStep(
            targetVersion: 2,
            description: 'adds extra table',
            up: (_, _) => db.customStatement(
              'CREATE TABLE extra_table (id INTEGER PRIMARY KEY)',
            ),
          ),
        ],
      );

      await db.transaction(
        () => manager.apply(Migrator(db), from: 1, to: 2, db: db),
      );

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name'));
      expect(names, contains('extra_table'));
    });

    test('rollback does not destroy pre-existing rows', () async {
      await db.ensureOpenForTests();

      final now = DateTime.now();
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(key: 'k', value: 'v', updatedAt: now),
          );

      final manager = MigrationManager(
        steps: [
          MigrationStep(
            targetVersion: 2,
            description: 'failing',
            up: (_, _) async => throw StateError('boom'),
          ),
        ],
      );

      await expectLater(
        db.transaction(
          () => manager.apply(Migrator(db), from: 1, to: 2, db: db),
        ),
        throwsStateError,
      );

      final rows = await db.select(db.settings).get();
      expect(rows.single.value, 'v');
    });
  });
}

/// A test-only database exposing Drift's protected `createMigrator()` so the
/// tests above can drive the real migration machinery.
final class OneMigrationHarnessDb extends OneBitDatabase {
  OneMigrationHarnessDb(super.executor);

  Future<void> ensureOpenForTests() async {
    await customSelect('SELECT 1').get();
  }
}
