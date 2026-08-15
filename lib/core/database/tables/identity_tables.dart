import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// The local node's own identity (single row).
///
/// Only public material lives here: private key material stays in the
/// platform keystore and never enters SQLite.
@DataClassName('IdentityRow')
class Identity extends Table {
  TextColumn get nodeId => text()();

  TextColumn get uuid => text().unique()();

  TextColumn get displayName => text()();

  /// 32-byte public identity key (Ed25519, public only).
  BlobColumn get publicKey => blob()();

  /// 64-char lowercase hex fingerprint of the identity key.
  TextColumn get fingerprint => text()();

  /// Avatar color index used by the UI.
  IntColumn get avatarColor => integer().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  /// Optimistic concurrency counter for the identity row.
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {nodeId};
}

/// Peers this device explicitly knows and (optionally) trusts.
@DataClassName('TrustedNodeRow')
class TrustedNodes extends Table {
  TextColumn get nodeId => text()();

  /// 32-byte public key of the peer.
  BlobColumn get publicKey => blob().nullable()();

  TextColumn get fingerprint => text().nullable()();

  TextColumn get trustStatus =>
      textEnum<TrustStatus>().withDefault(const Constant('pending'))();

  TextColumn get verificationMethod =>
      textEnum<VerificationMethod>().withDefault(const Constant('none'))();

  IntColumn get lastSeen =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  IntColumn get rssi => integer().nullable()();

  TextColumn get nickname => text().nullable()();

  /// Free-form JSON metadata (notes, tags).
  TextColumn get metadata => text().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  @override
  Set<Column> get primaryKey => {nodeId};
}

/// Observational profiles of nodes seen on the mesh but not yet trusted.
@DataClassName('NodeProfileRow')
class NodeProfiles extends Table {
  TextColumn get nodeId => text()();

  BlobColumn get publicKey => blob().nullable()();

  TextColumn get fingerprint => text().nullable()();

  TextColumn get displayName => text().nullable()();

  IntColumn get avatarColor => integer().nullable()();

  IntColumn get firstSeen => integer().map(dateTimeMsConverter)();

  IntColumn get lastSeen => integer().map(dateTimeMsConverter)();

  /// Free-form JSON metadata (capabilities, advertised info).
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {nodeId};
}
