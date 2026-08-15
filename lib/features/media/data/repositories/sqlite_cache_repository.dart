import 'package:drift/drift.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/cache/cache_entry.dart';
import 'package:onebit/features/media/cache/cache_repository.dart';

/// Durable (SQLite) half of the media cache catalogue + the aggregate
/// health snapshot. The byte tier itself lives in [MediaCache].
final class SqliteCacheRepository implements CacheRepository {
  SqliteCacheRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  static const String hitKey = 'cacheHits';
  static const String missKey = 'cacheMisses';
  static const String evictionKey = 'cacheEvictions';
  static const String lastCleanupKey = 'cacheLastCleanupAt';

  @override
  Future<Result<void>> recordHit(String key) =>
      ResultGuards.guard(logger, 'cache.recordHit', () async {
        final row = await dao.cacheEntryRow(key);
        if (row != null) {
          await dao.upsertCacheEntry(
            row
                .toCompanion(true)
                .copyWith(
                  accessCount: Value(row.accessCount + 1),
                  lastAccessAt: Value(DateTime.now()),
                ),
          );
        }
        await _bump(hitKey);
      });

  @override
  Future<Result<void>> recordMiss(String key) =>
      ResultGuards.guard(logger, 'cache.recordMiss', () async {
        await _bump(missKey);
      });

  @override
  Future<Result<void>> upsertEntry(MediaCacheEntry entry) =>
      ResultGuards.guard(logger, 'cache.upsertEntry', () async {
        await dao.upsertCacheEntry(_toRow(entry));
      });

  @override
  Future<Result<void>> deleteEntry(String key) =>
      ResultGuards.guard(logger, 'cache.deleteEntry', () async {
        await dao.deleteCacheEntry(key);
      });

  @override
  Future<Result<List<MediaCacheEntry>>> entries({CacheKind? kind}) =>
      ResultGuards.guard(logger, 'cache.entries', () async {
        final rows = await dao.cacheEntryRows(
          kind: kind == null ? null : core.CacheKind.values.byName(kind.name),
        );
        return rows.map(_fromRow).toList();
      });

  @override
  Future<Result<CacheStatistics>> statistics() =>
      ResultGuards.guard(logger, 'cache.statistics', () async {
        final entries = await dao.cacheEntryRows();
        var memoryBytes = 0;
        var diskBytes = 0;
        var memory = 0;
        var disk = 0;
        var thumbnails = 0;
        for (final row in entries) {
          switch (row.kind) {
            case core.CacheKind.memory:
              memory++;
              memoryBytes += row.sizeBytes;
            case core.CacheKind.disk:
              disk++;
              diskBytes += row.sizeBytes;
            case core.CacheKind.thumbnail:
              thumbnails++;
            case core.CacheKind.attachment:
              disk++;
              diskBytes += row.sizeBytes;
          }
        }
        final lastCleanupMillis = await dao.statisticValue(lastCleanupKey);
        return CacheStatistics(
          memoryEntries: memory,
          memoryBytes: memoryBytes,
          diskEntries: disk,
          diskBytes: diskBytes,
          thumbnailEntries: thumbnails,
          hits: await dao.statisticValue(hitKey) ?? 0,
          misses: await dao.statisticValue(missKey) ?? 0,
          evictions: await dao.statisticValue(evictionKey) ?? 0,
          lastCleanupAt: lastCleanupMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastCleanupMillis),
        );
      });

  @override
  Future<Result<void>> clear() =>
      ResultGuards.guard(logger, 'cache.clear', () async {
        await dao.clearCacheEntries();
        await dao.upsertStatistic(hitKey, 0);
        await dao.upsertStatistic(missKey, 0);
        await dao.upsertStatistic(evictionKey, 0);
      });

  Future<void> _bump(String key) async {
    await dao.upsertStatistic(key, (await dao.statisticValue(key) ?? 0) + 1);
  }

  static MediaCacheEntry _fromRow(CacheEntryRow row) => MediaCacheEntry(
    key: row.key,
    kind: CacheKind.values.byName(row.kind.name),
    sizeBytes: row.sizeBytes,
    accessCount: row.accessCount,
    lastAccessAt: row.lastAccessAt,
    createdAt: row.createdAt,
    path: row.path,
  );

  static CacheEntriesCompanion _toRow(MediaCacheEntry entry) =>
      CacheEntriesCompanion.insert(
        key: entry.key,
        kind: core.CacheKind.values.byName(entry.kind.name),
        sizeBytes: Value(entry.sizeBytes),
        accessCount: Value(entry.accessCount),
        lastAccessAt: entry.lastAccessAt,
        createdAt: entry.createdAt,
        path: Value(entry.path),
      );
}
