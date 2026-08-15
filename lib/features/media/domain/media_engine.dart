import 'dart:async';
import 'dart:convert';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import '../attachments/attachment.dart';
import '../cache/cache_cleaner.dart';
import '../cache/cache_entry.dart';
import '../compression/compression_engine.dart';
import '../compression/compression_profile.dart';
import '../compression/compression_statistics.dart';
import '../compression/compressor.dart';
import '../preview/media_metadata_parser.dart';
import '../preview/media_preview.dart';
import '../storage/attachment_store.dart';
import '../storage/storage_statistics.dart';
import '../thumbnail/thumbnail.dart';
import '../thumbnail/thumbnail_generator.dart';
import '../transfer/transfer_engine.dart';
import '../transfer/transfer_session.dart';
import '../transfer/transfer_statistics.dart';
import '../validation/media_validator.dart';
import '../validation/validation_result.dart';
import 'media_repository.dart';

/// Runtime knobs of the media subsystem (safe defaults for BLE mesh).
final class MediaEngineConfig {
  const MediaEngineConfig({
    this.chunkSize = 32 * 1024,
    this.minSendIntervalMs = 120,
    this.maxConcurrentInFlight = 1,
    this.ackTimeout = const Duration(seconds: 60),
    this.chunkRetryBudget = 5,
    this.sessionTtl = const Duration(days: 7),
    this.progressInterval = const Duration(seconds: 30),
    this.cacheCleanInterval = const Duration(hours: 1),
    this.inlineThreshold = 8 * 1024,
    this.headerWindow = MediaMetadataParser.defaultHeaderWindow,
  });

  /// Payload bytes per chunk — must fit one DTN envelope after encoding.
  final int chunkSize;

  /// Token-bucket pacing between chunk transmissions (battery leash).
  final int minSendIntervalMs;

  /// Max chunk envelopes in flight per session.
  final int maxConcurrentInFlight;

  /// Time after which an unacknowledged chunk is considered lost.
  final Duration ackTimeout;

  /// Retries per chunk before the session fails.
  final int chunkRetryBudget;

  /// Terminal sessions are swept after this.
  final Duration sessionTtl;

  /// How often the engine probes in-flight sessions and sweeps expiry.
  final Duration progressInterval;

  /// How often the cache cleaner runs.
  final Duration cacheCleanInterval;

  /// Payloads at/below this size may live inline in the database row.
  final int inlineThreshold;

  /// Header window fed to the metadata parser.
  final int headerWindow;
}

/// The media subsystem façade: owns the attach pipeline, transfer engine,
/// compression, thumbnails, previews and scheduled maintenance.
///
/// Pure domain — the only seams are interfaces ([MediaRepository],
/// [AttachmentStore], parser, validator, generators, engines). No
/// `dart:io`, no storage, no network here.
final class MediaEngine implements MediaValidationContext {
  MediaEngine({
    required this.config,
    required this.repository,
    required this.store,
    required this.parser,
    required this.validator,
    required this.thumbnailGenerators,
    required this.compressionEngine,
    required this.transferEngine,
    required this.cacheCleaner,
    required this.logger,
  });

  final MediaEngineConfig config;
  final MediaRepository repository;
  final AttachmentStore store;
  final MediaMetadataParser parser;
  final MediaValidator validator;

  /// Raster generators tried in order; the probe generator is the built-in
  /// fallback (last resort).
  final List<ThumbnailGenerator> thumbnailGenerators;
  final CompressionEngine compressionEngine;
  final TransferEngine transferEngine;
  final CacheCleaner cacheCleaner;
  final AppLogger logger;

  static const _tag = LogTags.media;

  bool _started = false;
  Timer? _progressTimer;
  Timer? _cacheTimer;
  final StreamController<bool> _lifecycle = StreamController.broadcast();

  bool get isStarted => _started;

  /// Emits true on start, false on [stop].
  Stream<bool> get lifecycle => _lifecycle.stream;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Restores active sessions and starts maintenance timers. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await transferEngine.start();
    _progressTimer = Timer.periodic(
      config.progressInterval,
      (_) => unawaited(transferEngine.maintenance(now: DateTime.now())),
    );
    _cacheTimer = Timer.periodic(
      config.cacheCleanInterval,
      (_) => unawaited(cacheCleaner.clean()),
    );
    _lifecycle.add(true);
    logger.info('media engine started', tag: _tag);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _progressTimer?.cancel();
    _progressTimer = null;
    _cacheTimer?.cancel();
    _cacheTimer = null;
    await transferEngine.stop();
    _lifecycle.add(false);
    logger.info('media engine stopped', tag: _tag);
  }

  // ---------------------------------------------------------------------
  // Attach pipeline
  // ---------------------------------------------------------------------

  /// Stages, validates, probes (and optionally compresses) [source] into
  /// the catalog. On any failure the staged payload is cleaned up.
  Future<Result<Attachment>> attachFile({
    required MediaSource source,
    String? messageId,
    bool compress = false,
    CompressionProfile? profile,
  }) async {
    // 1. Stage (single streaming pass: copy + whole-file SHA-256).
    final staged = await store.stage(
      fileName: source.fileName,
      category: source.declaredCategory ?? MediaCategory.binary,
      sourcePath: source.sourcePath,
      fileBytes: source.inlineBytes,
    );
    if (staged is Err<StagedPayload>) {
      return Err(staged.failure!);
    }
    final payload = staged.value!;

    // 2. Validate (pure rules; the engine supplies the storage context).
    final header = await store.readChunk(
      payload.relativePath,
      offset: 0,
      length: config.headerWindow,
    );
    final sniffed = MediaTypeRegistryCategory.sniff(header, source.fileName);
    final validation = await validator.validate(
      MediaValidationRequest(
        fileName: source.fileName,
        sizeBytes: payload.sizeBytes,
        headerBytes: header,
        declaredMimeType: source.declaredMimeType,
        declaredCategory: sniffed ?? source.declaredCategory,
        computedSha256: payload.sha256,
      ),
      this,
    );
    if (validation.hasErrors) {
      await store.delete(payload.relativePath);
      return Err(
        MediaValidationFailure(
          reason: validation.errors.first.code,
          message: validation.errors.first.message,
        ),
      );
    }

    // 3. Probe the staged payload.
    final probe = parser.parse(
      MediaProbeInput(
        fileName: source.fileName,
        sizeBytes: payload.sizeBytes,
        headerBytes: header,
        declaredMimeType: source.declaredMimeType,
        declaredCategory: sniffed ?? source.declaredCategory,
      ),
    );

    // 4. Optional compression (lossless families only in this phase).
    var sizeBytes = payload.sizeBytes;
    var sha256 = payload.sha256;
    if (compress) {
      final selected =
          profile ?? CompressionProfile.forCategory(probe.category);
      if (selected != null) {
        final stats = await compressionEngine.compress(
          AttachmentStoreCompressionSource(
            store: store,
            attachmentId: payload.relativePath,
            fileName: source.fileName,
            category: probe.category,
            relativePath: payload.relativePath,
            sizeBytes: payload.sizeBytes,
          ),
          selected,
        );
        if (stats is Ok<CompressionStatistics>) {
          final stat = stats.value!;
          if (stat.applied) {
            sizeBytes = stat.outputBytes;
            sha256 = await store.sha256Of(payload.relativePath);
          }
        }
      }
    }

    // 5. Persist the catalog row.
    final now = DateTime.now();
    final attachment = Attachment(
      attachmentId: AttachmentIds.next(),
      messageId: messageId,
      metadata: AttachmentMetadata(
        fileName: source.fileName,
        mimeType: probe.mimeType,
        category: probe.category,
        sizeBytes: sizeBytes,
        sha256: sha256,
        media: probe.detail,
      ),
      status: AttachmentStatus.ready,
      localPath: sizeBytes <= config.inlineThreshold
          ? null
          : payload.relativePath,
      isInline: sizeBytes <= config.inlineThreshold,
      inlineBytes: sizeBytes <= config.inlineThreshold
          ? await store.readChunk(
              payload.relativePath,
              offset: 0,
              length: sizeBytes,
            )
          : null,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await repository.attachments.save(attachment);
    if (saved is Err<Attachment>) {
      await store.delete(payload.relativePath);
      return Err(saved.failure!);
    }

    // 6. Best-effort lazy thumbnail.
    await generateThumbnail(saved.value!.attachmentId);

    logger.info(
      'attached ${saved.value!.attachmentId} '
      '${probe.category.name} $sizeBytes B',
      tag: _tag,
    );
    return saved;
  }

  /// Removes the catalog row and purges the payload + live sessions.
  Future<Result<void>> removeAttachment(String attachmentId) async {
    final found = await repository.attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) {
      return Err(MediaNotFoundFailure(id: attachmentId));
    }
    final sessions =
        (await repository.transfers.sessionsForAttachment(
          attachmentId,
        )).value ??
        const <TransferSession>[];
    for (final session in sessions) {
      if (session.state.isActive) {
        await transferEngine.cancelTransfer(session.sessionId);
      }
    }
    final path = attachment.localPath;
    if (path != null && await store.exists(path)) {
      await store.delete(path);
    }
    await repository.cache.deleteEntry(attachmentId);
    await repository.attachments.delete(attachmentId);
    return const Ok(null);
  }

  Future<Result<Attachment?>> attachmentOf(String attachmentId) =>
      repository.attachments.get(attachmentId);

  Future<Result<List<Attachment>>> listByMessage(String messageId) =>
      repository.attachments.listByMessage(messageId);

  Future<Result<List<Attachment>>> listByCategory(MediaCategory category) =>
      repository.attachments.listByCategory(category);

  // ---------------------------------------------------------------------
  // Transfers (passthroughs; the engine orchestrates the pump)
  // ---------------------------------------------------------------------

  Future<Result<TransferSession>> startTransfer({
    required String attachmentId,
    required String peerNodeId,
    int? chunkSize,
    Duration? ttl,
  }) => transferEngine.startTransfer(
    attachmentId: attachmentId,
    peerNodeId: peerNodeId,
    chunkSize: chunkSize,
    ttl: ttl,
  );

  Future<Result<TransferSession>> pauseTransfer(String sessionId) =>
      transferEngine.pause(sessionId);

  Future<Result<TransferSession>> resumeTransfer(String sessionId) =>
      transferEngine.resume(sessionId);

  Future<Result<void>> cancelTransfer(String sessionId) =>
      transferEngine.cancelTransfer(sessionId);

  Future<Result<TransferSession>> retryTransfer(String sessionId) =>
      transferEngine.retry(sessionId);

  Future<Result<TransferSession?>> sessionOf(String sessionId) =>
      transferEngine.sessionOf(sessionId);

  Future<Result<void>> handleInbound(List<int> payload, String sourceNode) =>
      transferEngine.handleInbound(payload, sourceNode);

  Stream<Result<TransferSession?>> watchTransfer(String sessionId) =>
      repository.transfers.watchSession(sessionId);

  // ---------------------------------------------------------------------
  // Thumbnails
  // ---------------------------------------------------------------------

  /// Ensures a thumbnail exists for [attachmentId] (single-flight guarded
  /// by the repository: an existing row short-circuits).
  Future<Result<Thumbnail?>> generateThumbnail(
    String attachmentId, {
    bool force = false,
  }) async {
    if (!force) {
      final existing = (await repository.thumbnails.forAttachment(
        attachmentId,
      )).value;
      if (existing != null) return Ok(existing);
    }
    final found = await repository.attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) return Err(MediaNotFoundFailure(id: attachmentId));

    final request = ThumbnailRequest(
      attachment: attachment,
      probe: attachment.metadata.media,
      suggestedId: AttachmentIds.thumbnailFor(attachmentId),
    );
    for (final generator in thumbnailGenerators) {
      if (generator is ProbeThumbnailGenerator) continue;
      final result = await generator.generate(request);
      if (result is Ok<Thumbnail>) {
        final saved = await repository.thumbnails.save(result.value!);
        if (saved is Ok<Thumbnail>) {
          logger.debug(
            'thumbnail ${saved.value!.thumbnailId} '
            '${saved.value!.kind.name} ready',
            tag: _tag,
          );
          return Ok(saved.value);
        }
      }
    }
    // Probe fallback (metadata-only; never fails).
    final probe = await const ProbeThumbnailGenerator().generate(request);
    if (probe is Ok<Thumbnail>) {
      final saved = await repository.thumbnails.save(probe.value!);
      return Ok(saved.value);
    }
    return Err(probe.failure ?? const UnexpectedFailure());
  }

  // ---------------------------------------------------------------------
  // Compression
  // ---------------------------------------------------------------------

  /// Compresses an existing attachment when its profile qualifies.
  Future<Result<CompressionStatistics>> compressMedia(
    String attachmentId, {
    CompressionProfile? profile,
  }) async {
    final found = await repository.attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) return Err(MediaNotFoundFailure(id: attachmentId));
    final path = attachment.localPath;
    if (path == null || attachment.isInline) {
      return const Ok(CompressionStatistics.skipped);
    }
    final selected =
        profile ?? CompressionProfile.forCategory(attachment.metadata.category);
    if (selected == null) {
      return const Ok(CompressionStatistics.skipped);
    }
    final result = await compressionEngine.compress(
      AttachmentStoreCompressionSource(
        store: store,
        attachmentId: attachmentId,
        fileName: attachment.metadata.fileName,
        category: attachment.metadata.category,
        relativePath: path,
        sizeBytes: attachment.metadata.sizeBytes,
      ),
      selected,
    );
    if (result is Ok<CompressionStatistics>) {
      final stats = result.value!;
      if (stats.applied) {
        final newSha = await store.sha256Of(path);
        final updated = attachment.copyWith(
          metadata: attachment.metadata.copyWith(
            sizeBytes: stats.outputBytes,
            sha256: newSha,
          ),
          updatedAt: DateTime.now(),
        );
        await repository.attachments.save(updated);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  /// Re-validates a catalog entry (attachment-level rules only).
  Future<Result<ValidationResult>> validateAttachment(
    String attachmentId, {
    Set<String>? rules,
  }) async {
    final found = await repository.attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) return Err(MediaNotFoundFailure(id: attachmentId));
    final header = attachment.isInline
        ? (attachment.inlineBytes ?? const <int>[])
        : await store.readChunk(
            attachment.localPath!,
            offset: 0,
            length: config.headerWindow,
          );
    final result = await validator.validate(
      MediaValidationRequest(
        fileName: attachment.metadata.fileName,
        sizeBytes: attachment.metadata.sizeBytes,
        headerBytes: header,
        declaredMimeType: attachment.metadata.mimeType,
        declaredCategory: attachment.metadata.category,
        computedSha256: attachment.metadata.sha256,
      ),
      this,
    );
    return Ok(result);
  }

  // ---------------------------------------------------------------------
  // Previews
  // ---------------------------------------------------------------------

  /// Caches (or serves) the preview metadata of [attachmentId].
  Future<Result<MediaPreview?>> loadPreview(String attachmentId) async {
    final existing = (await repository.previews.forAttachment(
      attachmentId,
    )).value;
    if (existing != null) return Ok(existing);
    final found = await repository.attachments.get(attachmentId);
    if (found is Err<Attachment?>) return Err(found.failure!);
    final attachment = found.value;
    if (attachment == null) return Err(MediaNotFoundFailure(id: attachmentId));
    final header = attachment.isInline
        ? (attachment.inlineBytes ?? const <int>[])
        : await store.readChunk(
            attachment.localPath!,
            offset: 0,
            length: config.headerWindow,
          );
    final probe = parser.parse(
      MediaProbeInput(
        fileName: attachment.metadata.fileName,
        sizeBytes: attachment.metadata.sizeBytes,
        headerBytes: header,
        declaredMimeType: attachment.metadata.mimeType,
        declaredCategory: attachment.metadata.category,
      ),
    );
    final preview = MediaPreview(
      previewId: AttachmentIds.previewFor(attachmentId),
      attachmentId: attachmentId,
      kind: PreviewKind.forCategory(probe.category),
      metadataJson: jsonEncode(probe.toJson()),
      createdAt: DateTime.now(),
    );
    final saved = await repository.previews.save(preview);
    if (saved is Err<MediaPreview>) return Err(saved.failure!);
    return Ok(saved.value);
  }

  // ---------------------------------------------------------------------
  // Statistics / storage / cache
  // ---------------------------------------------------------------------

  Future<Result<TransferStatistics>> statistics() =>
      repository.transfers.statistics();

  Future<Result<StorageStatistics>> storageStatistics() => store.statistics();

  Future<Result<CacheStatistics>> cacheStatistics() =>
      repository.cache.statistics();

  Future<Result<CacheCleanupReport>> runCacheCleanup() => cacheCleaner.clean();

  // ---------------------------------------------------------------------
  // MediaValidationContext implementation
  // ---------------------------------------------------------------------

  @override
  Future<bool> existsBySha256(String sha256) async {
    final rows = await repository.attachments.listByCategory(
      MediaCategory.binary,
    );
    if (rows is Err<List<Attachment>>) return false;
    return rows.value!.any((a) => a.metadata.sha256 == sha256);
  }

  @override
  Future<bool> storageAvailable(int bytes) => store.storageAvailable(bytes);
}

/// Stable id generators of the media subsystem (pure; no clock injection
/// keeps call sites simple).
abstract final class AttachmentIds {
  const AttachmentIds._();

  static String next() =>
      'att-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static String thumbnailFor(String attachmentId) =>
      'thumb-$attachmentId-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static String previewFor(String attachmentId) =>
      'prev-$attachmentId-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}

/// Sniffing helper used before probing/validation.
abstract final class MediaTypeRegistryCategory {
  const MediaTypeRegistryCategory._();

  static MediaCategory? sniff(List<int> header, String fileName) {
    if (MagicBytes.startsWith(header, MagicBytes.png) ||
        MagicBytes.startsWith(header, MagicBytes.jpeg) ||
        MagicBytes.startsWith(header, MagicBytes.gif87) ||
        MagicBytes.startsWith(header, MagicBytes.gif89)) {
      return MediaCategory.image;
    }
    if (MagicBytes.startsWith(header, MagicBytes.pdf)) {
      return MediaCategory.document;
    }
    if (MagicBytes.startsWith(header, MagicBytes.zip) ||
        MagicBytes.startsWith(header, MagicBytes.zipEmpty)) {
      return MediaCategory.archive;
    }
    if (MagicBytes.startsWith(header, MagicBytes.ogg)) {
      return MediaCategory.audio;
    }
    return null;
  }
}

/// [CompressionSource] backed by the attachment store (keeps `dart:io`
/// out of the engine).
final class AttachmentStoreCompressionSource implements CompressionSource {
  AttachmentStoreCompressionSource({
    required this.store,
    required this.attachmentId,
    required this.fileName,
    required this.category,
    required this.relativePath,
    required this.sizeBytes,
  });

  final AttachmentStore store;
  final String relativePath;

  @override
  final String attachmentId;
  @override
  final String fileName;
  @override
  final MediaCategory category;
  @override
  final int sizeBytes;

  @override
  Future<List<int>> readBytes() async =>
      store.readChunk(relativePath, offset: 0, length: sizeBytes);

  @override
  Future<void> replaceBytes(List<int> bytes) =>
      store.replacePayload(relativePath, bytes);
}
