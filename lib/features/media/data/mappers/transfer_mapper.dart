import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/features/media/transfer/transfer_bitmap.dart';
import 'package:onebit/features/media/transfer/transfer_chunk.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';

/// Row ↔ domain mapping for transfer sessions, chunks and the ledger.
abstract final class TransferMapper {
  const TransferMapper._();

  static TransferSession fromSessionRow(
    TransferSessionRow row,
  ) => TransferSession(
    sessionId: row.sessionId,
    attachmentId: row.attachmentId,
    peerNodeId: row.peerNodeId,
    direction: TransferDirection.values.byName(row.direction.name),
    state: TransferState.fromWireName(row.state.name) ?? TransferState.failed,
    chunkSize: row.chunkSize,
    totalChunks: row.totalChunks,
    chunksBitmap: TransferBitmap.fromBytes(row.chunksBitmap, row.totalChunks),
    bytesTransferred: row.bytesTransferred,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    completedAt: row.completedAt,
    lastError: row.lastError,
    attemptCount: row.attemptCount,
    ttl: row.ttlSeconds == null ? null : Duration(seconds: row.ttlSeconds!),
  );

  static TransferSessionsCompanion toSessionRow(TransferSession session) =>
      TransferSessionsCompanion(
        sessionId: Value(session.sessionId),
        attachmentId: Value(session.attachmentId),
        peerNodeId: Value(session.peerNodeId),
        direction: Value(
          core.TransferDirection.values.byName(session.direction.name),
        ),
        state: Value(core.TransferState.values.byName(session.state.name)),
        chunkSize: Value(session.chunkSize),
        totalChunks: Value(session.totalChunks),
        chunksBitmap: Value(session.chunksBitmap.toBytes()),
        bytesTransferred: Value(session.bytesTransferred),
        createdAt: Value(session.createdAt),
        updatedAt: Value(session.updatedAt),
        completedAt: Value(session.completedAt),
        lastError: Value(session.lastError),
        attemptCount: Value(session.attemptCount),
        ttlSeconds: Value(session.ttl?.inSeconds),
      );

  static TransferChunk fromChunkRow(TransferChunkRow row) => TransferChunk(
    sessionId: row.sessionId,
    index: row.index,
    offset: row.offset,
    sizeBytes: row.sizeBytes,
    sha256: row.sha256,
    state: ChunkState.fromWireName(row.state.name) ?? ChunkState.pending,
    attempts: row.attempts,
    sentAt: row.sentAt,
    ackedAt: row.ackedAt,
  );

  static TransferChunksCompanion toChunkRow(TransferChunk chunk) =>
      TransferChunksCompanion(
        sessionId: Value(chunk.sessionId),
        index: Value(chunk.index),
        offset: Value(chunk.offset),
        sizeBytes: Value(chunk.sizeBytes),
        sha256: Value(chunk.sha256),
        state: Value(core.ChunkState.values.byName(chunk.state.name)),
        attempts: Value(chunk.attempts),
        sentAt: Value(chunk.sentAt),
        ackedAt: Value(chunk.ackedAt),
      );

  /// The pending chunk ledger of a fresh session (geometry only; hashes
  /// are filled by the engine on first transmission). [totalSize] (the
  /// catalog's authoritative payload size) sizes the partial final chunk.
  static List<TransferChunksCompanion> initialChunkRows(
    TransferSession session,
    int totalSize,
  ) => [
    for (var i = 0; i < session.totalChunks; i++)
      TransferChunksCompanion(
        sessionId: Value(session.sessionId),
        index: Value(i),
        offset: Value(i * session.chunkSize),
        sizeBytes: Value(_chunkSizeAt(session, totalSize, i)),
        state: const Value(core.ChunkState.pending),
        attempts: const Value(0),
      ),
  ];

  static int _chunkSizeAt(TransferSession session, int totalSize, int index) {
    if (session.totalChunks == 1) return totalSize;
    if (index == session.totalChunks - 1) {
      final tail = totalSize - index * session.chunkSize;
      return tail > 0 ? tail : session.chunkSize;
    }
    return session.chunkSize;
  }
}
