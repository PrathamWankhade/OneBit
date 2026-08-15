import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import 'cache_entry.dart';
import 'cache_repository.dart';
import 'thumbnail_cache.dart';

/// Tunables of one cleanup pass.
final class CacheCleanupPolicy {
  const CacheCleanupPolicy({
    this.maxAge = const Duration(days: 30),
    this.maxDiskBytes = 512 * 1024 * 1024,
    this.cleanBatch = 100,
  });

  /// Entries untouched for longer than this are stale.
  final Duration maxAge;

  /// Combined disk+thumbnail budget; overflow is reclaimed oldest-first.
  final int maxDiskBytes;

  /// Max victims per run (runs are re-entrant, next sweep continues).
  final int cleanBatch;
}

/// Result of one cleanup pass.
@immutable
final class CacheCleanupReport {
  const CacheCleanupReport({
    required this.removedEntries,
    required this.reclaimedBytes,
    required this.sweptAt,
  });

  final int removedEntries;
  final int reclaimedBytes;
  final DateTime sweptAt;

  /// An empty pass (nothing to clean / overlapping run skipped).
  static final CacheCleanupReport empty = CacheCleanupReport(
    removedEntries: 0,
    reclaimedBytes: 0,
    sweptAt: DateTime(1970),
  );
}

/// The scheduled cache cleaner: enforces the disk budget and the age cap,
/// oldest-first, bounded per run.
///
/// Pure domain — the byte tiers (memory/disk) are injected, the catalogue
/// is the [CacheRepository]. Runs are idempotent and re-entrant.
final class CacheCleaner {
  CacheCleaner({
    required this.cache,
    required this.repository,
    required this.logger,
    this._policy = const CacheCleanupPolicy(),
  });

  final ThumbnailCache cache;
  final CacheRepository repository;
  final AppLogger logger;
  final CacheCleanupPolicy _policy;

  static const _tag = LogTags.media;

  bool _running = false;

  /// True while a run is in progress (callers skip overlapping runs).
  bool get isRunning => _running;

  /// One bounded cleanup pass.
  Future<Result<CacheCleanupReport>> clean() async {
    if (_running) {
      return Ok(
        CacheCleanupReport(
          removedEntries: 0,
          reclaimedBytes: 0,
          sweptAt: DateTime.now(),
        ),
      );
    }
    _running = true;
    try {
      final entries = (await repository.entries()).value ?? const [];
      if (entries.isEmpty) {
        return Ok(CacheCleanupReport.empty);
      }
      final now = DateTime.now();
      final stale = entries.where(
        (e) => now.difference(e.lastAccessAt) > _policy.maxAge,
      );
      final budgetOver = _overBudgetEntries(entries);
      final victims = <MediaCacheEntry>{};
      for (final entry in stale.take(_policy.cleanBatch)) {
        victims.add(entry);
      }
      for (final entry in budgetOver.take(_policy.cleanBatch)) {
        victims.add(entry);
      }
      return await _evict(
        victims.toList()
          ..sort((a, b) => a.lastAccessAt.compareTo(b.lastAccessAt)),
      );
    } finally {
      _running = false;
    }
  }

  /// Entries exceeding the disk budget, oldest first (only the overflow).
  List<MediaCacheEntry> _overBudgetEntries(List<MediaCacheEntry> entries) {
    final diskEntries =
        entries
            .where(
              (e) => e.kind == CacheKind.disk || e.kind == CacheKind.thumbnail,
            )
            .toList()
          ..sort((a, b) => a.lastAccessAt.compareTo(b.lastAccessAt));
    var total = 0;
    for (final entry in diskEntries) {
      total += entry.sizeBytes;
    }
    if (total <= _policy.maxDiskBytes) return const [];
    final overflow = total - _policy.maxDiskBytes;
    final victims = <MediaCacheEntry>[];
    var reclaimed = 0;
    for (final entry in diskEntries) {
      if (reclaimed >= overflow) break;
      victims.add(entry);
      reclaimed += entry.sizeBytes;
    }
    return victims;
  }

  Future<Result<CacheCleanupReport>> _evict(
    List<MediaCacheEntry> victims,
  ) async {
    var reclaimedBytes = 0;
    for (final entry in victims) {
      await cache.evict(entry.key);
      reclaimedBytes += entry.sizeBytes;
    }
    logger.debug(
      'cache cleaner: removed ${victims.length} entries '
      '($reclaimedBytes bytes)',
      tag: _tag,
    );
    return Ok(
      CacheCleanupReport(
        removedEntries: victims.length,
        reclaimedBytes: reclaimedBytes,
        sweptAt: DateTime.now(),
      ),
    );
  }
}
