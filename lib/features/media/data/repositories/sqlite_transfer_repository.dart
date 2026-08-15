import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/data/mappers/transfer_mapper.dart';
import 'package:onebit/features/media/transfer/transfer_chunk.dart';
import 'package:onebit/features/media/transfer/transfer_repository.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';
import 'package:onebit/features/media/transfer/transfer_statistics.dart';

/// Drift-backed [TransferRepository] over [MediaDao].
///
/// `createSession` writes the session row and its chunk ledger in ONE
/// transaction (drift's `batch` + `transaction` in [MediaDao]); the ledger's
/// tail-chunk size is derived from the catalog's `sizeBytes` so
/// `bytesTransferred` stays exact even for partial final chunks.
final class SqliteTransferRepository implements TransferRepository {
  SqliteTransferRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  /// Persistent aggregate counters of the transfer mirror: cumulative chunk
  /// activity + peak in-flight (counters without a session-row source).
  final _Mirror _mirror = const _Mirror();

  @override
  Future<Result<TransferSession>> createSession(TransferSession session) =>
      ResultGuards.guard(logger, 'transfer.createSession', () async {
        final attachment = await dao.attachmentRow(session.attachmentId);
        final totalSize =
            attachment?.sizeBytes ?? session.totalChunks * session.chunkSize;
        await dao.insertSessionWithChunks(
          TransferMapper.toSessionRow(session),
          TransferMapper.initialChunkRows(session, totalSize),
        );
        await _mirror.bump(dao, MediaStatConstants.sessionsStarted);
        return session;
      });

  @override
  Future<Result<TransferSession?>> sessionOf(String sessionId) =>
      ResultGuards.guard(logger, 'transfer.sessionOf', () async {
        final row = await dao.sessionRow(sessionId);
        return row == null ? null : TransferMapper.fromSessionRow(row);
      });

  @override
  Future<Result<TransferSession>> updateSession(TransferSession session) =>
      ResultGuards.guard(logger, 'transfer.updateSession', () async {
        await dao.updateSession(TransferMapper.toSessionRow(session));
        if (session.state.isTerminal) {
          await _mirror.onTerminalState(dao, session.state.name);
        }
        return session;
      });

  @override
  Future<Result<List<TransferSession>>> sessionsForAttachment(
    String attachmentId,
  ) => ResultGuards.guard(logger, 'transfer.sessionsForAttachment', () async {
    final rows = await dao.sessionsForAttachment(attachmentId);
    return rows.map(TransferMapper.fromSessionRow).toList();
  });

  @override
  Future<Result<List<TransferSession>>> activeSessions() =>
      ResultGuards.guard(logger, 'transfer.activeSessions', () async {
        final rows = await dao.activeSessions();
        return rows.map(TransferMapper.fromSessionRow).toList();
      });

  @override
  Future<Result<void>> setChunkHash(
    String sessionId,
    int index,
    String sha256,
  ) => ResultGuards.guard(logger, 'transfer.setChunkHash', () async {
    await dao.setChunkHash(sessionId, index, sha256);
  });

  @override
  Future<Result<void>> markChunkAcknowledged(String sessionId, int index) =>
      ResultGuards.guard(logger, 'transfer.markChunkAcked', () async {
        await dao.markChunkBit(sessionId, index);
        await _mirror.bump(dao, MediaStatConstants.chunksSent);
      });

  @override
  Future<Result<void>> markChunkReceived(String sessionId, int index) =>
      ResultGuards.guard(logger, 'transfer.markChunkReceived', () async {
        await dao.markChunkBit(sessionId, index);
        await _mirror.bump(dao, MediaStatConstants.chunksReceived);
      });

  @override
  Future<Result<void>> markChunkState(
    String sessionId,
    int index,
    ChunkState state, {
    int? attempts,
    DateTime? sentAt,
    DateTime? ackedAt,
  }) => ResultGuards.guard(logger, 'transfer.markChunkState', () async {
    await dao.updateChunkState(
      sessionId,
      index,
      core.ChunkState.values.byName(state.name),
      attempts: attempts,
      sentAt: sentAt,
      ackedAt: ackedAt,
    );
  });

  @override
  Future<Result<List<TransferChunk>>> chunks(String sessionId) =>
      ResultGuards.guard(logger, 'transfer.chunks', () async {
        final rows = await dao.chunkRowsForSession(sessionId);
        return rows.map(TransferMapper.fromChunkRow).toList();
      });

  @override
  Future<Result<void>> purgeSessionsBefore(DateTime cutoff) =>
      ResultGuards.guard(logger, 'transfer.purgeSessionsBefore', () async {
        await dao.purgeSessionsBefore(cutoff);
      });

  @override
  Future<Result<TransferStatistics>> statistics() => ResultGuards.guard(
    logger,
    'transfer.statistics',
    () async {
      final sessions = await dao.allSessions();
      final mirror = await _mirror.snapshot(dao);
      var active = 0;
      var completed = 0;
      var failed = 0;
      var cancelled = 0;
      var expired = 0;
      var sentBytes = 0;
      var receivedBytes = 0;
      for (final row in sessions) {
        final state =
            TransferState.fromWireName(row.state.name) ?? TransferState.failed;
        switch (state) {
          case TransferState.completed:
            completed++;
          case TransferState.failed:
            failed++;
          case TransferState.cancelled:
            cancelled++;
          case TransferState.expired:
            expired++;
          default:
            active++;
        }
        if (row.direction == core.TransferDirection.send) {
          sentBytes += row.bytesTransferred;
        } else {
          receivedBytes += row.bytesTransferred;
        }
      }
      return TransferStatistics(
        sessionsStarted: sessions.length,
        activeSessions: active,
        completedSessions: completed,
        failedSessions: failed,
        cancelledSessions: cancelled,
        expiredSessions: expired,
        bytesTransferred: sentBytes,
        bytesReceived: receivedBytes,
        chunksSent: mirror.chunksSent,
        chunksReceived: mirror.chunksReceived,
        chunkRetries: mirror.chunkRetries,
        averageChunkRate: mirror.averageChunkRate,
        peakInFlight: mirror.peakInFlight,
      );
    },
  );

  @override
  Stream<Result<TransferSession?>> watchSession(String sessionId) =>
      ResultGuards.guardWatch(
        logger,
        'transfer.watchSession',
        // The raw drift watch emits null for a missing session; map that to
        // a null value so the UI can render its not-found state instead of
        // hanging in an infinite loading spinner.
        dao
            .watchSession(sessionId)
            .map(
              (row) => row == null ? null : TransferMapper.fromSessionRow(row),
            ),
      );
}

/// Reads/writes the `MediaStatistics` counter mirror.
final class _Mirror {
  const _Mirror();

  Future<int> _read(MediaDao dao, String key) async =>
      await dao.statisticValue(key) ?? 0;

  Future<void> bump(MediaDao dao, String key) async {
    await dao.upsertStatistic(key, (await _read(dao, key)) + 1);
  }

  Future<void> onTerminalState(MediaDao dao, String state) async {
    final key = switch (state) {
      'completed' => MediaStatConstants.sessionsCompleted,
      'failed' => MediaStatConstants.sessionsFailed,
      'cancelled' => MediaStatConstants.sessionsCancelled,
      'expired' => MediaStatConstants.sessionsExpired,
      _ => null,
    };
    if (key != null) await bump(dao, key);
  }

  Future<
    ({
      int chunksSent,
      int chunksReceived,
      int chunkRetries,
      int peakInFlight,
      double averageChunkRate,
    })
  >
  snapshot(MediaDao dao) async {
    final read = _read;
    return (
      chunksSent: await read(dao, MediaStatConstants.chunksSent),
      chunksReceived: await read(dao, MediaStatConstants.chunksReceived),
      chunkRetries: await read(dao, MediaStatConstants.chunkRetries),
      peakInFlight: await read(dao, MediaStatConstants.peakInFlight),
      averageChunkRate: 0.0,
    );
  }
}
