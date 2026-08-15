import 'package:drift/drift.dart';

import '../database.dart';
import 'migration_step.dart';

/// Applies the correct subset of [MigrationStep]s for an upgrade.
///
/// Only steps with `targetVersion` in `(from, to]` run, in ascending order,
/// so an upgrade N→M always applies exactly the delta. Drift runs the whole
/// `onUpgrade` in one transaction — a failing step rolls everything back to
/// the previous version.
final class MigrationManager {
  const MigrationManager({required this.steps});

  /// All known steps, oldest first.
  final List<MigrationStep> steps;

  /// The steps that apply when migrating [from] → [to].
  List<MigrationStep> stepsBetween(int from, int to) {
    final applicable = steps.where(
      (step) => step.targetVersion > from && step.targetVersion <= to,
    );
    final sorted = [...applicable]
      ..sort((a, b) => a.targetVersion.compareTo(b.targetVersion));
    return sorted;
  }

  /// Applies every step in range to [migrator].
  Future<void> apply(
    Migrator migrator, {
    required int from,
    required int to,
    required OneBitDatabase db,
  }) async {
    for (final step in stepsBetween(from, to)) {
      await step.up(migrator, db);
    }
  }
}
