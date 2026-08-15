// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_dao.dart';

// ignore_for_file: type=lint
mixin _$SettingsDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  $ApplicationMetadataTable get applicationMetadata =>
      attachedDatabase.applicationMetadata;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
  $$ApplicationMetadataTableTableManager get applicationMetadata =>
      $$ApplicationMetadataTableTableManager(
        _db.attachedDatabase,
        _db.applicationMetadata,
      );
}
