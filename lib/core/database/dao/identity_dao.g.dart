// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_dao.dart';

// ignore_for_file: type=lint
mixin _$IdentityDaoMixin on DatabaseAccessor<OneBitDatabase> {
  $IdentityTable get identity => attachedDatabase.identity;
  $TrustedNodesTable get trustedNodes => attachedDatabase.trustedNodes;
  $NodeProfilesTable get nodeProfiles => attachedDatabase.nodeProfiles;
  IdentityDaoManager get managers => IdentityDaoManager(this);
}

class IdentityDaoManager {
  final _$IdentityDaoMixin _db;
  IdentityDaoManager(this._db);
  $$IdentityTableTableManager get identity =>
      $$IdentityTableTableManager(_db.attachedDatabase, _db.identity);
  $$TrustedNodesTableTableManager get trustedNodes =>
      $$TrustedNodesTableTableManager(_db.attachedDatabase, _db.trustedNodes);
  $$NodeProfilesTableTableManager get nodeProfiles =>
      $$NodeProfilesTableTableManager(_db.attachedDatabase, _db.nodeProfiles);
}
