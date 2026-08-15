import 'package:onebit/core/result/result.dart';

import 'cache_entry.dart';

/// Contract for the durable cache catalogue.
abstract interface class CacheRepository {
  Future<Result<void>> recordHit(String key);

  Future<Result<void>> recordMiss(String key);

  Future<Result<void>> upsertEntry(MediaCacheEntry entry);

  Future<Result<void>> deleteEntry(String key);

  Future<Result<List<MediaCacheEntry>>> entries({CacheKind? kind});

  /// Builds the aggregate cache health snapshot.
  Future<Result<CacheStatistics>> statistics();

  Future<Result<void>> clear();
}
