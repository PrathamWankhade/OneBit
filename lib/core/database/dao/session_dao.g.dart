// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $SessionsTable get sessions => attachedDatabase.sessions;
  $SessionKeysTable get sessionKeys => attachedDatabase.sessionKeys;
  SessionDaoManager get managers => SessionDaoManager(this);
}

class SessionDaoManager {
  final _$SessionDaoMixin _db;
  SessionDaoManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$SessionKeysTableTableManager get sessionKeys =>
      $$SessionKeysTableTableManager(_db.attachedDatabase, _db.sessionKeys);
}
