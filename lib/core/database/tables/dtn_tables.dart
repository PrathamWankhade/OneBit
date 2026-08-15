import 'package:drift/drift.dart';

import 'converters.dart';

/// Persisted DTN envelopes (Phase 7: store-and-forward layer).
///
/// One row == one `DtnPacket`. Lifecycle fields (`state`, `ackState`,
/// attempt counters, next attempt / ack deadlines) mirror the engine view,
/// and the expiry index drives the retention sweep after restarts.
///
/// No foreign keys: a DTN envelope addresses a *node*, not a row in another
/// table, and relayed envelopes may reference nodes this device has never
/// seen in `Neighbors`.
@TableIndex(name: 'idx_dtn_packets_expires', columns: {#expiresAt})
@TableIndex(name: 'idx_dtn_packets_state', columns: {#state})
@TableIndex(name: 'idx_dtn_packets_destination', columns: {#destination})
@DataClassName('DtnPacketRow')
class DtnPackets extends Table {
  TextColumn get packetId => text()();

  TextColumn get source => text()();

  TextColumn get destination => text()();

  TextColumn get envelopeType => textEnum<DtnEnvelopeType>()();

  TextColumn get priority => textEnum<DtnPriorityLevel>()();

  TextColumn get direction => textEnum<DtnDirectionPersisted>()();

  BlobColumn get payload => blob()();

  TextColumn get state => textEnum<DtnPacketState>()();

  IntColumn get ttlSeconds => integer()();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get expiresAt => integer().map(dateTimeMsConverter)();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  IntColumn get lastAttemptAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  IntColumn get nextAttemptAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  TextColumn get lastError => text().nullable()();

  TextColumn get ackState =>
      textEnum<DtnAckState>().withDefault(const Constant('none'))();

  IntColumn get ackDeadlineAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  TextColumn get ackedBy => text().nullable()();

  IntColumn get deliveredAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  IntColumn get hopCount => integer().withDefault(const Constant(0))();

  IntColumn get enqueuedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  Set<Column> get primaryKey => {packetId};
}

/// Persisted role of an envelope at this node.
enum DtnEnvelopeType {
  /// Application data (a message body in Phase 9).
  message,

  /// A logical acknowledgement referencing another envelope.
  ack,

  /// Control envelopes (route hints / discovery).
  control,
}

/// Persisted delivery priority. Kept independent from the Phase 4
/// `priority` on `Packets` so the DTN layer may evolve on its own.
enum DtnPriorityLevel { critical, high, normal, low, background }

/// Persisted direction at this node.
enum DtnDirectionPersisted { outbound, inbound, relay }

/// Persisted lifecycle state.
enum DtnPacketState {
  queued,
  pendingDelivery,
  retrying,
  deferred,
  relaying,
  awaitingAck,
  delivered,
  deliveredLocally,
  consumed,
  failed,
  expired,
}

/// Persisted acknowledgement handshake state.
enum DtnAckState { none, awaiting, received, timedOut }
