import 'package:flutter/foundation.dart';

/// Immutable configuration for the local SQLite database.
///
/// Only transport concerns live here (name, location, mode); schema versioning
/// is owned by `MigrationRegistry` so config and migrations cannot disagree.
@immutable
final class DatabaseConfig {
  const DatabaseConfig({this.name = defaultName, this.inMemory = false});

  /// Stable file name (without extension) for the on-disk database.
  static const String defaultName = 'onebit';

  /// Logical database name, used for the on-disk file.
  final String name;

  /// When true, the database lives entirely in RAM (`:memory:`).
  ///
  /// Used by tests and ephemeral sessions; content is lost on close.
  final bool inMemory;
}
