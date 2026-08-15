// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packet_dao.dart';

// ignore_for_file: type=lint
mixin _$PacketDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $PacketsTable get packets => attachedDatabase.packets;
  $PacketFragmentsTable get packetFragments => attachedDatabase.packetFragments;
  PacketDaoManager get managers => PacketDaoManager(this);
}

class PacketDaoManager {
  final _$PacketDaoMixin _db;
  PacketDaoManager(this._db);
  $$PacketsTableTableManager get packets =>
      $$PacketsTableTableManager(_db.attachedDatabase, _db.packets);
  $$PacketFragmentsTableTableManager get packetFragments =>
      $$PacketFragmentsTableTableManager(
        _db.attachedDatabase,
        _db.packetFragments,
      );
}
