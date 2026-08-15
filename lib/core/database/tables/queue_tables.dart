import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';
import 'packet_tables.dart';

/// Outbound items awaiting transport (messages, packets, control frames).
@DataClassName('PendingQueueRow')
@TableIndex(name: 'idx_pending_priority', columns: {#priority, #nextAttemptAt})
class PendingQueue extends Table {
  IntColumn get queueId => integer().autoIncrement()();

  /// What kind of entity is queued (`message` | `packet` | ...).
  TextColumn get entityType => text()();

  /// Id of the entity within its table.
  TextColumn get entityId => text()();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  IntColumn get enqueuedAt => integer().map(dateTimeMsConverter)();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get nextAttemptAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    <Column>{entityType, entityId},
  ];
}

/// Items that failed and wait for a retry with backoff.
@DataClassName('RetryQueueRow')
@TableIndex(name: 'idx_retry_next_attempt', columns: {#nextAttemptAt})
class RetryQueue extends Table {
  IntColumn get retryId => integer().autoIncrement()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get maxAttempts => integer().withDefault(const Constant(5))();

  IntColumn get lastAttemptAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  IntColumn get nextAttemptAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  TextColumn get lastError => text().nullable()();

  IntColumn get backoffMs => integer().withDefault(const Constant(1000))();

  TextColumn get state =>
      textEnum<QueueState>().withDefault(const Constant('queued'))();

  @override
  List<Set<Column>> get uniqueKeys => [
    <Column>{entityType, entityId},
  ];
}

/// Packets scheduled for relay to the mesh.
@DataClassName('RelayQueueRow')
@TableIndex(name: 'idx_relay_state', columns: {#state, #enqueuedAt})
class RelayQueue extends Table {
  IntColumn get relayId => integer().autoIncrement()();

  TextColumn get packetId =>
      text().references(Packets, #packetId, onDelete: KeyAction.cascade)();

  TextColumn get source => text()();

  TextColumn get destination => text()();

  IntColumn get hopsRemaining => integer()();

  IntColumn get enqueuedAt => integer().map(dateTimeMsConverter)();

  TextColumn get state =>
      textEnum<RelayState>().withDefault(const Constant('queued'))();
}
