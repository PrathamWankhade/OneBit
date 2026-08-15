import 'dart:async';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';

import '../attachments/attachment.dart';
import '../attachments/attachment_repository.dart';
import '../storage/attachment_store.dart';
import 'transfer_bitmap.dart';
import 'transfer_chunk.dart';
import 'transfer_envelope.dart';
import 'transfer_gateway.dart';
import 'transfer_repository.dart';
import 'transfer_session.dart';
import 'transfer_state.dart';

/// Runtime knobs of the chunk pump.
final class TransferEngineConfig {
  const TransferEngineConfig({
    this.chunkSize = 32 * 1024,
    this.minSendIntervalMs = 120,
    this.maxConcurrentInFlight = 1,
    this.ackTimeout = const Duration(seconds: 60),
    this.chunkRetryBudget = 5,
    this.sessionTtl = const Duration(days: 7),
  });

  final int chunkSize;
  final int minSendIntervalMs;
  final int maxConcurrentInFlight;
  final Duration ackTimeout;
  final int chunkRetryBudget;
  final Duration sessionTtl;
}

/// The chunked transfer orchestrator.
///
/// Owns the pump (send side), the inbound envelope dispatch (receive side),
/// timeouts/retries and session expiry. Persistence goes through
/// [TransferRepository]; bytes through [AttachmentStore]; the wire through
/// [TransferGateway] + [MediaEnvelopeCodec]. No `dart:io`, no Bluetooth.
final class TransferEngine {
  TransferEngine({
    required this.localNodeId,
    required this.repository,
    required this.attachments,
    required this.store,
    required this.gateway,
    required this.codec,
    required this.logger,
    this.config = const TransferEngineConfig(),
  });

  final String localNodeId;
  final TransferRepository repository;
  final AttachmentRepository attachments;
  final AttachmentStore store;
  final TransferGateway gateway;
  final MediaEnvelopeCodec codec;
  final AppLogger logger;
  final TransferEngineConfig config;

  static const _tag = LogTags.media;

  bool _started = false;
  Timer? _ticker;
  StreamSubscription<DtnPacket>? _inboundSubscription;
  final Set<String> _completedSendSessions = <String>{};

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Restores active sessions and subscribes to inbound deliveries.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _inboundSubscription = gateway.inboundDeliveries.listen(
      (packet) => unawaited(_onInboundPacket(packet)),
      onError: (Object error) {
        logger.warning('inbound delivery stream error: $error', tag: _tag);
      },
    );
    _ticker = Timer.periodic(
      Duration(milliseconds: config.minSendIntervalMs),
      (_) => unawaited(pumpOnce()),
    );
    logger.debug('transfer engine started', tag: _tag);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _ticker?.cancel();
    _ticker = null;
    await _inboundSubscription?.cancel();
    _inboundSubscription = null;
  }

  // ---------------------------------------------------------------------
  // Send side
  // ---------------------------------------------------------------------

  /// Creates a send session and announces the file to [peerNodeId].
  Future<Result<TransferSession>> startTransfer({
    required String attachmentId,
    required String peerNodeId,
    int? chunkSize,
    Duration? ttl,
  }) async {
    final found = await attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) {
      return Err(MediaNotFoundFailure(id: attachmentId));
    }
    if (attachment.isInline || attachment.localPath == null) {
      return const Err(
        MediaValidationFailure(
          reason: 'noPayload',
          message: 'attachment has no staged payload for transfer',
        ),
      );
    }
    final size = attachment.metadata.sizeBytes;
    final perChunk = chunkSize ?? config.chunkSize;
    if (perChunk < 1024) {
      return const Err(
        MediaValidationFailure(
          reason: 'chunkTooSmall',
          message: 'chunk size must be at least 1024 bytes',
        ),
      );
    }
    final totalChunks = max(1, (size / perChunk).ceil());
    final now = DateTime.now();
    final session = TransferSession(
      sessionId: 'trx-${now.microsecondsSinceEpoch.toRadixString(36)}',
      attachmentId: attachmentId,
      peerNodeId: peerNodeId,
      direction: TransferDirection.send,
      state: TransferState.queued,
      chunkSize: perChunk,
      totalChunks: totalChunks,
      chunksBitmap: TransferBitmap.empty(totalChunks),
      bytesTransferred: 0,
      createdAt: now,
      updatedAt: now,
      ttl: ttl,
    );
    final created = await repository.createSession(session);
    if (created is Err<TransferSession>) return Err(created.failure!);
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.announce,
        sessionId: session.sessionId,
        direction: 'send',
        attachmentId: attachmentId,
        fileName: attachment.metadata.fileName,
        mimeType: attachment.metadata.mimeType,
        category: attachment.metadata.category.wireName,
        totalSize: size,
        sha256: attachment.metadata.sha256,
      ),
      peerNodeId,
    );
    await _transition(session, TransferState.transferring);
    logger.info(
      'transfer ${session.sessionId} started: $size B in '
      '$totalChunks chunks → $peerNodeId',
      tag: _tag,
    );
    return Ok(session);
  }

  /// One pump round: for every active send session, dispatch chunks within
  /// the in-flight window (paced by the ticker / manual calls in tests).
  Future<void> pumpOnce({DateTime? now}) async {
    if (!_started) return;
    final current = now ?? DateTime.now();
    final sessions =
        (await repository.activeSessions()).value ?? const <TransferSession>[];
    for (final session in sessions) {
      if (session.direction != TransferDirection.send) continue;
      if (!session.state.isActive) continue;
      await _pumpSendSession(session, current);
    }
  }

  Future<void> _pumpSendSession(TransferSession session, DateTime now) async {
    if (session.isComplete) {
      await _finishSend(session);
      return;
    }
    final chunks =
        (await repository.chunks(session.sessionId)).value ??
        const <TransferChunk>[];
    final pending = chunks
        .where((c) => c.isPending)
        .take(config.maxConcurrentInFlight)
        .toList();
    if (pending.isEmpty) return;
    final attachment = (await attachments.get(session.attachmentId)).value;
    if (attachment == null || attachment.localPath == null) return;
    for (final chunk in pending) {
      if (chunk.attempts >= config.chunkRetryBudget) {
        await _failSession(
          session,
          'chunk ${chunk.index} exhausted '
          '${chunk.attempts} attempts',
        );
        return;
      }
      final bytes = await _readChunk(attachment, chunk);
      if (bytes == null) {
        await _failSession(session, 'chunk ${chunk.index} unreadable');
        return;
      }
      final sha = _hex((await Sha256().hash(bytes)).bytes);
      final envelope = MediaEnvelope(
        kind: MediaEnvelopeKind.chunk,
        sessionId: session.sessionId,
        direction: 'send',
        attachmentId: session.attachmentId,
        chunkIndex: chunk.index,
        offset: chunk.offset,
        byteLength: bytes.length,
        data: bytes,
        sha256: sha,
      );
      final sent = await _transmit(envelope, session.peerNodeId);
      if (sent is Err<DtnPacket>) {
        logger.warning(
          'chunk ${chunk.index} transmit failed: ${sent.failure}',
          tag: _tag,
        );
        continue;
      }
      await repository.setChunkHash(session.sessionId, chunk.index, sha);
      await repository.markChunkState(
        session.sessionId,
        chunk.index,
        ChunkState.inFlight,
        attempts: chunk.attempts + 1,
        sentAt: now,
      );
      if (_started) {
        await Future<void>.delayed(
          Duration(milliseconds: config.minSendIntervalMs),
        );
      }
    }
  }

  Future<List<int>?> _readChunk(
    Attachment attachment,
    TransferChunk chunk,
  ) async {
    try {
      final bytes = await store.readChunk(
        attachment.localPath!,
        offset: chunk.offset,
        length: chunk.sizeBytes,
      );
      if (bytes.length != chunk.sizeBytes) return null;
      return bytes;
    } on Object {
      return null;
    }
  }

  Future<void> _finishSend(TransferSession session) async {
    if (_completedSendSessions.contains(session.sessionId)) return;
    _completedSendSessions.add(session.sessionId);
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.complete,
        sessionId: session.sessionId,
        direction: 'send',
        attachmentId: session.attachmentId,
        ok: true,
      ),
      session.peerNodeId,
    );
    final terminal = session.copyWith(
      state: TransferState.completed,
      updatedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    final saved = await repository.updateSession(terminal);
    if (saved is Ok<TransferSession>) {
      await attachments.updateStatus(
        session.attachmentId,
        AttachmentStatus.complete,
      );
    }
    logger.info(
      'transfer ${session.sessionId} completed (${session.bytesTransferred} B)',
      tag: _tag,
    );
  }

  // ---------------------------------------------------------------------
  // Control
  // ---------------------------------------------------------------------

  Future<Result<TransferSession?>> sessionOf(String sessionId) =>
      repository.sessionOf(sessionId);

  Future<Result<TransferSession>> pause(String sessionId) async {
    final session = (await repository.sessionOf(sessionId)).value;
    if (session == null) {
      return Err(MediaNotFoundFailure(id: sessionId));
    }
    if (!session.state.isActive) {
      return Err(
        MediaTransitionFailure(
          from: session.state.name,
          to: TransferState.paused.name,
        ),
      );
    }
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.pause,
        sessionId: sessionId,
        ok: true,
      ),
      session.peerNodeId,
    );
    return _transition(session, TransferState.paused);
  }

  Future<Result<TransferSession>> resume(String sessionId) async {
    final session = (await repository.sessionOf(sessionId)).value;
    if (session == null) {
      return Err(MediaNotFoundFailure(id: sessionId));
    }
    if (session.state != TransferState.paused) {
      return Err(
        MediaTransitionFailure(
          from: session.state.name,
          to: TransferState.transferring.name,
        ),
      );
    }
    // Missing chunks are already in the bitmap; the pump resumes from it.
    return _transition(session, TransferState.transferring);
  }

  Future<Result<void>> cancelTransfer(String sessionId) async {
    final session = (await repository.sessionOf(sessionId)).value;
    if (session == null) {
      return Err(MediaNotFoundFailure(id: sessionId));
    }
    if (!session.state.isActive) {
      return const Ok(null);
    }
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.cancel,
        sessionId: sessionId,
        reason: 'cancelled by user',
      ),
      session.peerNodeId,
    );
    if (session.direction == TransferDirection.receive) {
      await store.deleteTemp(sessionId);
    }
    final terminal = session.copyWith(
      state: TransferState.cancelled,
      updatedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    await repository.updateSession(terminal);
    if (session.direction == TransferDirection.send) {
      await attachments.updateStatus(
        session.attachmentId,
        AttachmentStatus.ready,
      );
    }
    return const Ok(null);
  }

  Future<Result<TransferSession>> retry(String sessionId) async {
    final session = (await repository.sessionOf(sessionId)).value;
    if (session == null) {
      return Err(MediaNotFoundFailure(id: sessionId));
    }
    if (session.state != TransferState.failed) {
      return Err(
        MediaTransitionFailure(
          from: session.state.name,
          to: TransferState.queued.name,
        ),
      );
    }
    final reset = session.copyWith(
      state: TransferState.queued,
      updatedAt: DateTime.now(),
      attemptCount: session.attemptCount + 1,
      lastError: null,
      completedAt: null,
    );
    final saved = await repository.updateSession(reset);
    if (saved is Ok<TransferSession>) {
      await _transmit(
        MediaEnvelope(
          kind: MediaEnvelopeKind.announce,
          sessionId: sessionId,
          direction: 'send',
          attachmentId: session.attachmentId,
        ),
        session.peerNodeId,
      );
    }
    return saved;
  }

  // ---------------------------------------------------------------------
  // Inbound dispatch
  // ---------------------------------------------------------------------

  Future<void> _onInboundPacket(DtnPacket packet) =>
      handleInbound(packet.payload, packet.source);

  /// Decodes and dispatches one media envelope payload (the provider /
  /// gateway feed). Non-media payloads are dropped silently.
  Future<Result<void>> handleInbound(
    List<int> payload,
    String sourceNode,
  ) async {
    final decoded = codec.decode(payload);
    if (decoded is Err<MediaEnvelope>) {
      return Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'non-media or malformed payload dropped',
          cause: decoded.failure,
        ),
      );
    }
    final envelope = decoded.value!;
    switch (envelope.kind) {
      case MediaEnvelopeKind.announce:
        await _onAnnounce(envelope, sourceNode);
      case MediaEnvelopeKind.chunk:
        await _onChunk(envelope);
      case MediaEnvelopeKind.ack:
        await _onAck(envelope);
      case MediaEnvelopeKind.request:
        await _onRequest(envelope);
      case MediaEnvelopeKind.pause:
        await _onPause(envelope);
      case MediaEnvelopeKind.complete:
        await _onComplete(envelope);
      case MediaEnvelopeKind.cancel:
        await _onCancel(envelope);
    }
    return const Ok(null);
  }

  Future<void> _onAnnounce(MediaEnvelope envelope, String sourceNode) async {
    final existing = (await repository.sessionOf(envelope.sessionId)).value;
    if (existing != null) {
      logger.trace(
        'duplicate announce ${envelope.sessionId} dropped',
        tag: _tag,
      );
      return;
    }
    final now = DateTime.now();
    final totalSize = envelope.totalSize ?? 0;
    final perChunk = config.chunkSize;
    final totalChunks = max(1, (totalSize / perChunk).ceil());
    final session = TransferSession(
      sessionId: envelope.sessionId,
      attachmentId: envelope.attachmentId ?? envelope.sessionId,
      peerNodeId: sourceNode,
      direction: TransferDirection.receive,
      state: TransferState.queued,
      chunkSize: perChunk,
      totalChunks: totalChunks,
      chunksBitmap: TransferBitmap.empty(totalChunks),
      bytesTransferred: 0,
      createdAt: now,
      updatedAt: now,
    );
    final created = await repository.createSession(session);
    if (created is Err<TransferSession>) {
      logger.warning('announce store failed: ${created.failure}', tag: _tag);
      return;
    }
    final attachment = Attachment(
      attachmentId: envelope.attachmentId ?? envelope.sessionId,
      metadata: AttachmentMetadata(
        fileName: envelope.fileName ?? 'incoming.bin',
        mimeType: envelope.mimeType ?? 'application/octet-stream',
        category:
            MediaCategory.fromWireName(envelope.category ?? '') ??
            MediaCategory.binary,
        sizeBytes: totalSize,
        sha256: envelope.sha256,
      ),
      status: AttachmentStatus.downloading,
      createdAt: now,
      updatedAt: now,
    );
    await attachments.save(attachment);
    logger.info(
      'inbound announce ${envelope.sessionId}: $totalSize B',
      tag: _tag,
    );
  }

  Future<void> _onChunk(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    if (session == null || session.direction != TransferDirection.receive) {
      logger.trace('chunk for unknown session dropped', tag: _tag);
      return;
    }
    final index = envelope.chunkIndex;
    if (index == null || envelope.data == null) {
      await _nack(session, index, 'malformed chunk envelope');
      return;
    }
    final bytes = envelope.data!;
    // Chunk-level integrity: declared hash must match the received bytes.
    if (envelope.sha256 != null &&
        _hex((await Sha256().hash(bytes)).bytes) != envelope.sha256) {
      await _nack(session, index, 'chunk hash mismatch');
      return;
    }
    final offset = envelope.offset ?? index * session.chunkSize;
    await store.writeTempAt(session.sessionId, offset, bytes);

    final marked = await repository.markChunkReceived(session.sessionId, index);
    if (marked is Err<void>) {
      await _nack(session, index, 'chunk store failed: ${marked.failure}');
      return;
    }
    // Acknowledge: sender advances its bitmap.
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.ack,
        sessionId: session.sessionId,
        direction: 'receive',
        chunkIndex: index,
        ok: true,
      ),
      session.peerNodeId,
    );
    final updated = (await repository.sessionOf(session.sessionId)).value;
    if (updated != null && updated.isComplete) {
      await _verifyAndFinalize(updated);
    }
  }

  Future<void> _nack(TransferSession session, int? index, String reason) async {
    if (index != null) {
      await repository.markChunkState(
        session.sessionId,
        index,
        ChunkState.failed,
      );
    }
    await _transmit(
      MediaEnvelope(
        kind: MediaEnvelopeKind.ack,
        sessionId: session.sessionId,
        direction: 'receive',
        chunkIndex: index,
        ok: false,
        reason: reason,
      ),
      session.peerNodeId,
    );
  }

  Future<void> _onAck(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    if (session == null || session.direction != TransferDirection.send) return;
    if (!envelope.ok) {
      final index = envelope.chunkIndex;
      if (index != null) {
        await repository.markChunkState(
          session.sessionId,
          index,
          ChunkState.pending,
        );
      }
      logger.warning(
        'chunk ${envelope.chunkIndex} nacked: ${envelope.reason}',
        tag: _tag,
      );
      return;
    }
    if (envelope.chunkIndex == null) return;
    await repository.markChunkAcknowledged(
      session.sessionId,
      envelope.chunkIndex!,
    );
    final updated = (await repository.sessionOf(session.sessionId)).value;
    if (updated != null && updated.isComplete) {
      await _finishSend(updated);
    }
  }

  Future<void> _onRequest(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    final index = envelope.chunkIndex;
    if (session == null || index == null) return;
    if (session.direction == TransferDirection.receive) {
      // The peer asks for a chunk it believes we hold; we're the receiver —
      // this is a resume hint, requeue the chunk for the pump.
      await repository.markChunkState(
        session.sessionId,
        index,
        ChunkState.pending,
      );
    } else {
      await repository.markChunkState(
        session.sessionId,
        index,
        ChunkState.pending,
      );
      await pumpOnce();
    }
  }

  Future<void> _onPause(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    if (session == null || session.state.isTerminal) return;
    await _transition(session, TransferState.paused);
  }

  Future<void> _onCancel(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    if (session == null) return;
    if (session.direction == TransferDirection.receive) {
      await store.deleteTemp(session.sessionId);
    }
    await repository.updateSession(
      session.copyWith(
        state: TransferState.cancelled,
        updatedAt: DateTime.now(),
        completedAt: DateTime.now(),
        lastError: envelope.reason,
      ),
    );
  }

  Future<void> _onComplete(MediaEnvelope envelope) async {
    final session = (await repository.sessionOf(envelope.sessionId)).value;
    if (session == null || session.direction != TransferDirection.receive) {
      return;
    }
    await _verifyAndFinalize(session);
  }

  /// Whole-file verification: size + SHA-256 of the assembled temp file vs
  /// the announced attachment hash. On success the temp file becomes the
  /// attachment payload (finalized rename) and the session completes.
  Future<void> _verifyAndFinalize(TransferSession session) async {
    if (session.state == TransferState.completed) return;
    final attachment = (await attachments.get(session.attachmentId)).value;
    final expectedSize =
        attachment?.metadata.sizeBytes ??
        (await repository.sessionOf(session.sessionId)).value?.bytesTransferred;
    final expectedSha = attachment?.metadata.sha256;
    final length = await store.tempLength(session.sessionId);
    final sizeOk = length == expectedSize;
    var shaOk = true;
    if (expectedSha != null) {
      shaOk = await store.sha256Temp(session.sessionId) == expectedSha;
    }
    if (!sizeOk || !shaOk) {
      await _failSession(
        session,
        'file verification failed (size ${sizeOk ? 'ok' : 'mismatch'}, '
        'sha256 ${shaOk ? 'ok' : 'mismatch'})',
      );
      if (session.direction == TransferDirection.receive) {
        await store.deleteTemp(session.sessionId);
      }
      return;
    }
    final fileName = attachment?.metadata.fileName ?? 'incoming.bin';
    final relative = await store.finalizeTemp(session.sessionId, fileName);
    final completed = session.copyWith(
      state: TransferState.completed,
      updatedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    await repository.updateSession(completed);
    if (attachment != null) {
      await attachments.save(
        attachment.copyWith(
          status: AttachmentStatus.complete,
          localPath: relative,
          updatedAt: DateTime.now(),
        ),
      );
    }
    logger.info(
      'transfer ${session.sessionId} verified and finalized → $relative',
      tag: _tag,
    );
  }

  // ---------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------

  /// Periodic sweep: chunk timeouts + retries, TTL expiry, terminal purge.
  Future<void> maintenance({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final sessions =
        (await repository.activeSessions()).value ?? const <TransferSession>[];
    for (final session in sessions) {
      // TTL expiry.
      final ttl = session.ttl;
      if (ttl != null && current.difference(session.createdAt) > ttl) {
        logger.warning(
          'transfer ${session.sessionId} expired (TTL)',
          tag: _tag,
        );
        if (session.direction == TransferDirection.receive) {
          await store.deleteTemp(session.sessionId);
        }
        await repository.updateSession(
          session.copyWith(
            state: TransferState.expired,
            updatedAt: current,
            completedAt: current,
          ),
        );
        continue;
      }
      if (session.direction != TransferDirection.send) continue;
      // Chunk timeouts.
      final chunks =
          (await repository.chunks(session.sessionId)).value ??
          const <TransferChunk>[];
      var lost = false;
      for (final chunk in chunks) {
        if (chunk.state != ChunkState.inFlight) continue;
        final sentAt = chunk.sentAt;
        if (sentAt == null || current.difference(sentAt) < config.ackTimeout) {
          continue;
        }
        final attempts = chunk.attempts + 1;
        if (attempts > config.chunkRetryBudget) {
          await _failSession(
            session,
            'chunk ${chunk.index} timed out '
            '($attempts attempts)',
          );
          lost = true;
          break;
        }
        await repository.markChunkState(
          session.sessionId,
          chunk.index,
          ChunkState.pending,
          attempts: attempts,
        );
      }
      if (lost) continue;
    }
    // Terminal sessions older than the TTL are purged.
    await repository.purgeSessionsBefore(current.subtract(config.sessionTtl));
  }

  Future<void> _failSession(TransferSession session, String reason) async {
    logger.warning('transfer ${session.sessionId} failed: $reason', tag: _tag);
    await repository.updateSession(
      session.copyWith(
        state: TransferState.failed,
        updatedAt: DateTime.now(),
        lastError: reason,
      ),
    );
    if (session.direction == TransferDirection.send) {
      await attachments.updateStatus(
        session.attachmentId,
        AttachmentStatus.failed,
      );
    }
  }

  Future<Result<TransferSession>> _transition(
    TransferSession session,
    TransferState state,
  ) async {
    final updated = session.copyWith(state: state, updatedAt: DateTime.now());
    final result = await repository.updateSession(updated);
    if (result is Ok<TransferSession>) {
      logger.debug(
        'transfer ${session.sessionId}: ${session.state.name} → '
        '${state.name}',
        tag: _tag,
      );
    }
    return result;
  }

  Future<Result<DtnPacket>> _transmit(
    MediaEnvelope envelope,
    String peerNodeId,
  ) async {
    final result = await gateway.transmit(envelope, peerNodeId);
    if (result is Err<DtnPacket>) {
      logger.warning(
        'transmit ${envelope.kind.name} failed: ${result.failure}',
        tag: _tag,
      );
    }
    return result;
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
