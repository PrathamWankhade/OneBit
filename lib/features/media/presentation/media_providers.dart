import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/database/database_providers.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/media/cache/cache_cleaner.dart';
import 'package:onebit/features/media/cache/cache_repository.dart';
import 'package:onebit/features/media/cache/media_cache.dart';
import 'package:onebit/features/media/cache/thumbnail_cache.dart';
import 'package:onebit/features/media/compression/compression_engine.dart';
import 'package:onebit/features/media/compression/compressor.dart';
import 'package:onebit/features/media/compression/deflate_compressor.dart';
import 'package:onebit/features/media/data/attachment_manager.dart';
import 'package:onebit/features/media/data/repositories/sqlite_attachment_repository.dart';
import 'package:onebit/features/media/data/repositories/sqlite_cache_repository.dart';
import 'package:onebit/features/media/data/repositories/sqlite_preview_repository.dart';
import 'package:onebit/features/media/data/repositories/sqlite_thumbnail_repository.dart';
import 'package:onebit/features/media/data/repositories/sqlite_transfer_repository.dart';
import 'package:onebit/features/media/data/repositories/sqlite_voice_repository.dart';
import 'package:onebit/features/media/data/storage/disk_cache.dart';
import 'package:onebit/features/media/data/storage/file_store.dart';
import 'package:onebit/features/media/data/wire/attachment_wire_codec.dart';
import 'package:onebit/features/media/domain/media_engine.dart';
import 'package:onebit/features/media/domain/media_repository.dart';
import 'package:onebit/features/media/preview/media_metadata_parser.dart';
import 'package:onebit/features/media/storage/attachment_store.dart';
import 'package:onebit/features/media/thumbnail/thumbnail_generator.dart';
import 'package:onebit/features/media/transfer/transfer_engine.dart';
import 'package:onebit/features/media/transfer/transfer_gateway.dart';
import 'package:onebit/features/media/validation/media_validator.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart'
    show localNodeIdProvider;

/// Composition root of the Phase 9 media subsystem.
///
/// Builds the six SQLite repositories over [mediaDaoProvider], folds them
/// into the shared [MediaRepository] aggregate, and wires the engines:
/// [MediaEngine] (attach/compress/thumbnail/cache), [TransferEngine] over
/// the DTN-backed [AttachmentManager] gateway. The engine starts lazily on
/// first touch (mirroring the DTN provider pattern).

// ---------------------------------------------------------------------------
// Repositories (one Drift-backed implementation per domain contract)
// ---------------------------------------------------------------------------

final Provider<SqliteAttachmentRepository> sqliteAttachmentRepositoryProvider =
    Provider<SqliteAttachmentRepository>(
      (ref) => SqliteAttachmentRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<SqliteTransferRepository> sqliteTransferRepositoryProvider =
    Provider<SqliteTransferRepository>(
      (ref) => SqliteTransferRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<SqliteThumbnailRepository> sqliteThumbnailRepositoryProvider =
    Provider<SqliteThumbnailRepository>(
      (ref) => SqliteThumbnailRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<SqlitePreviewRepository> sqlitePreviewRepositoryProvider =
    Provider<SqlitePreviewRepository>(
      (ref) => SqlitePreviewRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<SqliteVoiceRepository> sqliteVoiceRepositoryProvider =
    Provider<SqliteVoiceRepository>(
      (ref) => SqliteVoiceRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<CacheRepository> sqliteCacheRepositoryProvider =
    Provider<CacheRepository>(
      (ref) => SqliteCacheRepository(
        dao: ref.watch(mediaDaoProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// The aggregate repository facade the engine consumes.
final Provider<MediaRepository> mediaRepositoryProvider =
    Provider<MediaRepository>(
      (ref) => CompositeMediaRepository(
        attachments: ref.watch(sqliteAttachmentRepositoryProvider),
        transfers: ref.watch(sqliteTransferRepositoryProvider),
        thumbnails: ref.watch(sqliteThumbnailRepositoryProvider),
        previews: ref.watch(sqlitePreviewRepositoryProvider),
        voice: ref.watch(sqliteVoiceRepositoryProvider),
        cache: ref.watch(sqliteCacheRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Storage, cache tiers, compression, gateway
// ---------------------------------------------------------------------------

/// Media root: app-writable temp storage by default, overridable in tests.
final Provider<AttachmentStore> attachmentStoreProvider =
    Provider<AttachmentStore>(
      (ref) => FileStore(
        root: Directory('${Directory.systemTemp.path}/onebit_media'),
      ),
    );

final Provider<BlobCache> memoryBlobCacheProvider = Provider<BlobCache>(
  (ref) => MemoryCache(policy: const CachePolicy()),
);

final Provider<BlobCache> diskBlobCacheProvider = Provider<BlobCache>((ref) {
  final store = ref.watch(attachmentStoreProvider) as FileStore;
  final root = store.mediaRoot;
  return DiskCache(directory: Directory('${root.path}/cache'));
});

final Provider<ThumbnailCache> thumbnailCacheProvider =
    Provider<ThumbnailCache>(
      (ref) => ThumbnailCache(
        memory: ref.watch(memoryBlobCacheProvider),
        disk: ref.watch(diskBlobCacheProvider),
        repository: ref.watch(sqliteCacheRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<CacheCleaner> cacheCleanerProvider = Provider<CacheCleaner>(
  (ref) => CacheCleaner(
    cache: ref.watch(thumbnailCacheProvider),
    repository: ref.watch(sqliteCacheRepositoryProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final Provider<CompressionEngine> compressionEngineProvider =
    Provider<CompressionEngine>((ref) {
      final compressors = <Compressor>[
        const DeflateCompressor(),
        const NoopCompressor(),
      ];
      return CompressionEngine(
        compressors: compressors,
        // Auto-compression dispatch is disabled by default; the engine's
        // explicit attach-pipeline runs always pass a concrete profile.
        profileFor: (_) => null,
        logger: ref.watch(appLoggerProvider),
      );
    });

final Provider<ThumbnailGenerator> probeThumbnailGeneratorProvider =
    Provider<ThumbnailGenerator>((ref) => const ProbeThumbnailGenerator());

/// The DTN-backed media transmission seam.
final Provider<AttachmentManager> attachmentManagerProvider =
    Provider<AttachmentManager>((ref) {
      final manager = AttachmentManager(
        localNodeId: ref.watch(localNodeIdProvider),
        dtn: ref.watch(dtnRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      );
      manager.attachInbound(ref.watch(dtnEngineProvider).inboundDeliveries);
      return manager;
    });

final Provider<TransferGateway> transferGatewayProvider =
    Provider<TransferGateway>((ref) => ref.watch(attachmentManagerProvider));

final Provider<TransferEngine> transferEngineProvider =
    Provider<TransferEngine>((ref) {
      final engine = TransferEngine(
        localNodeId: ref.watch(localNodeIdProvider),
        repository: ref.watch(sqliteTransferRepositoryProvider),
        attachments: ref.watch(sqliteAttachmentRepositoryProvider),
        store: ref.watch(attachmentStoreProvider),
        gateway: ref.watch(transferGatewayProvider),
        codec: const AttachmentWireCodec(),
        logger: ref.watch(appLoggerProvider),
      );
      return engine;
    });

// ---------------------------------------------------------------------------
// The media facade itself + lifecycle
// ---------------------------------------------------------------------------

final Provider<MediaEngine> mediaEngineProvider = Provider<MediaEngine>((ref) {
  final engine = MediaEngine(
    config: const MediaEngineConfig(),
    repository: ref.watch(mediaRepositoryProvider),
    store: ref.watch(attachmentStoreProvider),
    parser: BasicMediaMetadataParser(),
    validator: MediaValidator(maxSizeBytes: 256 * 1024 * 1024),
    thumbnailGenerators: [ref.watch(probeThumbnailGeneratorProvider)],
    compressionEngine: ref.watch(compressionEngineProvider),
    transferEngine: ref.watch(transferEngineProvider),
    cacheCleaner: ref.watch(cacheCleanerProvider),
    logger: ref.watch(appLoggerProvider),
  );
  unawaited(
    engine.start().catchError((Object error, StackTrace stack) {
      ref
          .watch(appLoggerProvider)
          .error(
            'media engine failed to start',
            error: error,
            stackTrace: stack,
          );
    }),
  );
  ref.onDispose(() => unawaited(engine.stop()));
  return engine;
});
