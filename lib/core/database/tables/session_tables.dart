import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// A ratchet session with a peer node.
///
/// This table persists session state only — key derivation and message
/// encryption live in the crypto layer (later phase). `ratchetState` is an
/// opaque encrypted blob produced by the crypto layer.
@DataClassName('SessionRow')
@TableIndex(name: 'idx_sessions_node', columns: {#node})
class Sessions extends Table {
  TextColumn get sessionId => text()();

  TextColumn get node => text()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get updatedAt => integer().map(dateTimeMsConverter)();

  IntColumn get expiration =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  BlobColumn get ratchetState => blob().nullable()();

  TextColumn get state =>
      textEnum<SessionState>().withDefault(const Constant('active'))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Ratchet keys of a session, ordered by step.
@DataClassName('SessionKeyRow')
@TableIndex(name: 'idx_session_keys_step', columns: {#sessionId, #ratchetStep})
class SessionKeys extends Table {
  TextColumn get sessionKeyId => text()();

  TextColumn get sessionId =>
      text().references(Sessions, #sessionId, onDelete: KeyAction.cascade)();

  IntColumn get ratchetStep => integer()();

  TextColumn get direction => textEnum<SessionKeyDirection>()();

  BlobColumn get keyMaterial => blob().nullable()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get expiresAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  Set<Column> get primaryKey => {sessionKeyId};

  @override
  List<Set<Column>> get uniqueKeys => [
    <Column>{sessionId, ratchetStep},
  ];
}
