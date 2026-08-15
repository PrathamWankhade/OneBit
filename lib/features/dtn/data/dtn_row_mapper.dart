import 'dart:typed_data';

import '../../../core/database/database.dart';
import '../../../core/database/tables/dtn_tables.dart' as db;
import '../domain/dtn_envelope.dart';
import '../domain/dtn_priority.dart';

/// Two-way mapping between persisted rows and engine envelopes.
///
/// Enums map by *wire name*, matching the table convention (`textEnum`):
/// values are stored as strings, so reordering either side never invalidates
/// stored rows. A value missing on one side fails loudly on restore.
abstract final class DtnRowMapper {
  const DtnRowMapper._();

  static DtnPacket toPacket(DtnPacketRow row) {
    return DtnPacket(
      packetId: row.packetId,
      source: row.source,
      destination: row.destination,
      payload: List<int>.unmodifiable(row.payload),
      priority: DtnPriority.values.byName(row.priority.name),
      direction: DtnDirection.values.byName(row.direction.name),
      ttlSeconds: row.ttlSeconds,
      createdAt: row.createdAt,
      expiresAt: row.expiresAt,
      type: DtnEnvelopeType.values.byName(row.envelopeType.name),
      state: DtnPacketState.values.byName(row.state.name),
      attemptCount: row.attemptCount,
      lastAttemptAt: row.lastAttemptAt,
      nextAttemptAt: row.nextAttemptAt,
      lastError: row.lastError,
      ackState: DtnAckState.values.byName(row.ackState.name),
      ackDeadlineAt: row.ackDeadlineAt,
      ackedBy: row.ackedBy,
      deliveredAt: row.deliveredAt,
      hopCount: row.hopCount,
      enqueuedAt: row.enqueuedAt,
    );
  }

  static DtnPacketRow toRow(DtnPacket packet) {
    return DtnPacketRow(
      packetId: packet.packetId,
      source: packet.source,
      destination: packet.destination,
      payload: Uint8List.fromList(packet.payload),
      priority: db.DtnPriorityLevel.values.byName(packet.priority.name),
      direction: db.DtnDirectionPersisted.values.byName(packet.direction.name),
      ttlSeconds: packet.ttlSeconds,
      createdAt: packet.createdAt,
      expiresAt: packet.expiresAt,
      envelopeType: db.DtnEnvelopeType.values.byName(packet.type.name),
      state: db.DtnPacketState.values.byName(packet.state.name),
      attemptCount: packet.attemptCount,
      lastAttemptAt: packet.lastAttemptAt,
      nextAttemptAt: packet.nextAttemptAt,
      lastError: packet.lastError,
      ackState: db.DtnAckState.values.byName(packet.ackState.name),
      ackDeadlineAt: packet.ackDeadlineAt,
      ackedBy: packet.ackedBy,
      deliveredAt: packet.deliveredAt,
      hopCount: packet.hopCount,
      enqueuedAt: packet.enqueuedAt,
    );
  }
}
