// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dtn_dao.dart';

// ignore_for_file: type=lint
mixin _$DtnDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $DtnPacketsTable get dtnPackets => attachedDatabase.dtnPackets;
  DtnDaoManager get managers => DtnDaoManager(this);
}

class DtnDaoManager {
  final _$DtnDaoMixin _db;
  DtnDaoManager(this._db);
  $$DtnPacketsTableTableManager get dtnPackets =>
      $$DtnPacketsTableTableManager(_db.attachedDatabase, _db.dtnPackets);
}
