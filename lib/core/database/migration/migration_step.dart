import 'package:drift/drift.dart';

import '../database.dart';

/// A single versioned schema change.
///
/// A step applies when upgrading from any version strictly below
/// [targetVersion] to at least [targetVersion]. Steps are additive or
/// data-preserving; destructive changes are staged across releases.
final class MigrationStep {
  const MigrationStep({
    required this.targetVersion,
    required this.description,
    required this.up,
  });

  /// The schema version this step produces.
  final int targetVersion;

  /// Human-readable description surfaced in logs.
  final String description;

  /// Applies the schema change with the drift [Migrator].
  ///
  /// The bound [OneBitDatabase] is provided so steps can create tables
  /// through the generated, already-attached references
  /// (`migrator.createTable(db.someTable)`).
  final Future<void> Function(Migrator migrator, OneBitDatabase db) up;
}
