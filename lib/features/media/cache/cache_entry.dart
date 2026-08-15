import 'package:flutter/foundation.dart';

/// Storage tier of a cache entry.
enum CacheKind {
  /// In-memory byte cache (LRU).
  memory,

  /// On-disk byte cache (hash-keyed files).
  disk,

  /// Generated thumbnails.
  thumbnail,

  /// Staged/downloaded attachment payloads.
  attachment;

  String get wireName => name;

  static CacheKind? fromWireName(String name) => switch (name) {
    'memory' => CacheKind.memory,
    'disk' => CacheKind.disk,
    'thumbnail' => CacheKind.thumbnail,
    'attachment' => CacheKind.attachment,
    _ => null,
  };
}

/// One cache catalogue row.
@immutable
final class MediaCacheEntry {
  const MediaCacheEntry({
    required this.key,
    required this.kind,
    required this.sizeBytes,
    required this.lastAccessAt,
    required this.createdAt,
    this.accessCount = 0,
    this.path,
  });

  final String key;
  final CacheKind kind;
  final int sizeBytes;
  final int accessCount;
  final DateTime lastAccessAt;
  final DateTime createdAt;

  /// Disk location for `disk`/`thumbnail`/`attachment` entries.
  final String? path;

  MediaCacheEntry copyWith({
    int? sizeBytes,
    int? accessCount,
    DateTime? lastAccessAt,
    String? path,
  }) => MediaCacheEntry(
    key: key,
    kind: kind,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    accessCount: accessCount ?? this.accessCount,
    lastAccessAt: lastAccessAt ?? this.lastAccessAt,
    createdAt: createdAt,
    path: path ?? this.path,
  );
}

/// Snapshot of the whole cache health.
@immutable
final class CacheStatistics {
  const CacheStatistics({
    this.memoryEntries = 0,
    this.memoryBytes = 0,
    this.diskEntries = 0,
    this.diskBytes = 0,
    this.thumbnailEntries = 0,
    this.hits = 0,
    this.misses = 0,
    this.evictions = 0,
    this.lastCleanupAt,
  });

  final int memoryEntries;
  final int memoryBytes;
  final int diskEntries;
  final int diskBytes;
  final int thumbnailEntries;
  final int hits;
  final int misses;
  final int evictions;
  final DateTime? lastCleanupAt;

  int get totalEntries => memoryEntries + diskEntries + thumbnailEntries;
  int get totalBytes => memoryBytes + diskBytes;

  static const CacheStatistics empty = CacheStatistics();

  CacheStatistics copyWith({
    int? memoryEntries,
    int? memoryBytes,
    int? diskEntries,
    int? diskBytes,
    int? thumbnailEntries,
    int? hits,
    int? misses,
    int? evictions,
    DateTime? lastCleanupAt,
  }) => CacheStatistics(
    memoryEntries: memoryEntries ?? this.memoryEntries,
    memoryBytes: memoryBytes ?? this.memoryBytes,
    diskEntries: diskEntries ?? this.diskEntries,
    diskBytes: diskBytes ?? this.diskBytes,
    thumbnailEntries: thumbnailEntries ?? this.thumbnailEntries,
    hits: hits ?? this.hits,
    misses: misses ?? this.misses,
    evictions: evictions ?? this.evictions,
    lastCleanupAt: lastCleanupAt ?? this.lastCleanupAt,
  );
}
