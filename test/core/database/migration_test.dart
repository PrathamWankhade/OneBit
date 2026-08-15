import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/migration/migration_manager.dart';
import 'package:onebit/core/database/migration/migration_registry.dart';
import 'package:onebit/core/database/migration/migration_step.dart';

import 'support/database_support.dart';

void main() {
  group('migration registry', () {
    test('schemaVersion matches the database schema version', () async {
      final db = await openInMemoryDb();
      expect(db.schemaVersion, MigrationRegistry.currentVersion);
      await db.close();
    });

    test('registry holds the exact steps and the newest matches v5', () {
      expect(
        MigrationRegistry.currentVersion,
        MigrationRegistry.steps.last.targetVersion,
      );
      expect(MigrationRegistry.steps.map((s) => s.targetVersion), [2, 3, 4, 5]);
    });
  });

  group('MigrationManager', () {
    test('applies only steps in (from, to] sorted ascending', () {
      final manager = MigrationManager(
        steps: [
          MigrationStep(
            targetVersion: 3,
            description: 'bump 3',
            up: (_, _) async {},
          ),
          MigrationStep(
            targetVersion: 1,
            description: 'bump 1',
            up: (_, _) async {},
          ),
          MigrationStep(
            targetVersion: 2,
            description: 'bump 2',
            up: (_, _) async {},
          ),
        ],
      );
      final applied = manager.stepsBetween(1, 3).map((s) => s.targetVersion);
      expect(applied, [2, 3]);
      expect(manager.stepsBetween(0, 1).map((s) => s.targetVersion), [1]);
      expect(manager.stepsBetween(3, 5), isEmpty);
    });
  });

  test('step receives the bound database', () async {
    final db = await openInMemoryDb();
    OneBitDatabase? seen;
    final step = MigrationStep(
      targetVersion: 2,
      description: 'capture db',
      up: (migrator, database) async => seen = database,
    );
    final manager = MigrationManager(steps: [step]);
    final migrator = Migrator(db);
    await manager.apply(migrator, from: 1, to: 2, db: db);
    expect(seen, same(db));
    await db.close();
  });
}
