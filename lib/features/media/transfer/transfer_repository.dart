import 'package:onebit/core/result/result.dart';

import 'transfer_chunk.dart';
import 'transfer_session.dart';
import 'transfer_state.dart';
import 'transfer_statistics.dart';

/// Contract for transfer session persistence.
///
/// Bitmap transitions are transactional: marking a chunk acked/received
/// recomputes `bytesTransferred` from the bitmap inside one SQLite
/// transaction, so the two can never disagree — even mid-crash.
abstract interface class TransferRepository {
  /// Persists the session AND its chunk ledger transactionally. The chunk
  /// geometry is derived from [TransferSession.chunkSize]/[totalChunks]
  /// (offsets `index * chunkSize`); hashes are filled later by
  /// [setChunkHash] on first transmission.
  Future<Result<TransferSession>> createSession(TransferSession session);

  Future<Result<TransferSession?>> sessionOf(String sessionId);

  Future<Result<List<TransferSession>>> sessionsForAttachment(
    String attachmentId,
  );

  /// Sessions not yet in a terminal state (resume candidates).
  Future<Result<List<TransferSession>>> activeSessions();

  Future<Result<TransferSession>> updateSession(TransferSession session);

  /// Records the verified chunk hash on the ledger (send side, computed at
  /// transmit time).
  Future<Result<void>> setChunkHash(String sessionId, int index, String sha256);

  /// Marks chunk [index] acknowledged (send side) — transactional bitmap +
  /// bytes + chunk row.
  Future<Result<void>> markChunkAcknowledged(String sessionId, int index);

  /// Marks chunk [index] received + verified (receive side).
  Future<Result<void>> markChunkReceived(String sessionId, int index);

  /// Marks chunk [index] in-flight / pending / failed (ledger transitions).
  Future<Result<void>> markChunkState(
    String sessionId,
    int index,
    ChunkState state, {
    int? attempts,
    DateTime? sentAt,
    DateTime? ackedAt,
  });

  /// The chunk ledger of [sessionId], ascending by index.
  Future<Result<List<TransferChunk>>> chunks(String sessionId);

  /// Hard-deletes sessions (and their chunks) not updated before [cutoff].
  Future<Result<void>> purgeSessionsBefore(DateTime cutoff);

  /// Durably persisted counters + live aggregates.
  Future<Result<TransferStatistics>> statistics();

  /// Live session stream (re-emits on every transition).
  Stream<Result<TransferSession?>> watchSession(String sessionId);
}
