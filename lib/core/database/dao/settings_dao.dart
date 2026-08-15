import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/metadata_tables.dart';

part 'settings_dao.g.dart';

/// Typed persistence for settings and application metadata.
@DriftAccessor(tables: [Settings, ApplicationMetadata])
final class SettingsDao extends DatabaseAccessor<OneBitDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  @override
  $SettingsTable get settings => db.settings;

  @override
  $ApplicationMetadataTable get applicationMetadata => db.applicationMetadata;

  // ---- Settings ------------------------------------------------------------------

  Future<SettingRow?> getSetting(String key) =>
      (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<String?> getSettingValue(String key) async {
    final row = await getSetting(key);
    return row?.value;
  }

  Future<List<SettingRow>> getAllSettings() => select(settings).get();

  Stream<List<SettingRow>> watchAllSettings() => select(settings).watch();

  Future<int> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingRow(
          key: key,
          value: value,
          updatedAt: DateTime.now(),
          version: 1,
        ),
      );

  Future<int> deleteSetting(String key) =>
      (delete(settings)..where((t) => t.key.equals(key))).go();

  // ---- Application metadata ----------------------------------------------------------

  Future<MetadataRow?> getMetadata(String key) => (select(
    applicationMetadata,
  )..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<String?> getMetadataValue(String key) async {
    final row = await getMetadata(key);
    return row?.value;
  }

  Future<int> setMetadata(String key, String value) =>
      into(applicationMetadata).insertOnConflictUpdate(
        MetadataRow(key: key, value: value, updatedAt: DateTime.now()),
      );

  Future<int> deleteMetadata(String key) =>
      (delete(applicationMetadata)..where((t) => t.key.equals(key))).go();
}
