import 'package:drift/drift.dart';

import 'converters.dart';

/// Key-value user/app settings. Values are JSON-encoded text.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {key};
}

/// Machine-readable application metadata (schema version, install id, ...).
@DataClassName('MetadataRow')
class ApplicationMetadata extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {key};
}
