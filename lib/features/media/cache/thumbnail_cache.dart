import 'dart:async';
import 'dart:typed_data';

import 'package:onebit/core/logger/app_logger.dart';

import 'cache_entry.dart';
import 'cache_repository.dart';
import 'media_cache.dart';

/// Facade over the memory + disk tiers for attachment thumbnails and
/// payloads: checks memory first, falls back to disk, keeps the catalogue
/// in sync. Pure domain — stores are injected.
final class ThumbnailCache {
  ThumbnailCache({
    required this.memory,
    required this.disk,
    required this.repository,
    required this.logger,
  });

  final BlobCache memory;
  final BlobCache disk;
  final CacheRepository repository;
  final AppLogger logger;

  /// Reads [key] from memory, then disk; bumps recency on hit and mirrors
  /// the access into the catalogue.
  Future<Uint8List?> get(String key) async {
    final memoryHit = await memory.get(key);
    if (memoryHit != null) {
      await repository.recordHit(key);
      return memoryHit;
    }
    final diskHit = await disk.get(key);
    if (diskHit != null) {
      await memory.put(key, diskHit);
      await repository.recordHit(key);
      return diskHit;
    }
    await repository.recordMiss(key);
    return null;
  }

  /// Stores [bytes] in both tiers under [key].
  Future<void> put(
    String key,
    Uint8List bytes, {
    CacheKind kind = CacheKind.thumbnail,
    String? path,
  }) async {
    await memory.put(key, bytes);
    await disk.put(key, bytes);
    await repository.upsertEntry(
      MediaCacheEntry(
        key: key,
        kind: kind,
        sizeBytes: bytes.length,
        accessCount: 1,
        lastAccessAt: DateTime.now(),
        createdAt: DateTime.now(),
        path: path,
      ),
    );
  }

  /// Evicts [key] from both tiers and the catalogue.
  Future<void> evict(String key) async {
    await memory.evict(key);
    await disk.evict(key);
    await repository.deleteEntry(key);
  }

  Future<void> clear() async {
    await memory.clear();
    await disk.clear();
    await repository.clear();
  }
}
