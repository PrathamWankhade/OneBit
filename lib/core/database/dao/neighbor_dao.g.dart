// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'neighbor_dao.dart';

// ignore_for_file: type=lint
mixin _$NeighborDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $NeighborsTable get neighbors => attachedDatabase.neighbors;
  NeighborDaoManager get managers => NeighborDaoManager(this);
}

class NeighborDaoManager {
  final _$NeighborDaoMixin _db;
  NeighborDaoManager(this._db);
  $$NeighborsTableTableManager get neighbors =>
      $$NeighborsTableTableManager(_db.attachedDatabase, _db.neighbors);
}
