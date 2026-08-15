import '../database.dart';
import 'memory_cache.dart';

/// Short-TTL cache for trusted-node rows.
final class TrustCache {
  TrustCache({Duration ttl = const Duration(seconds: 30), int maxEntries = 128})
    : _cache = MemoryCache<String, TrustedNodeRow>(
        ttl: ttl,
        maxEntries: maxEntries,
      );

  final MemoryCache<String, TrustedNodeRow> _cache;

  TrustedNodeRow? get(String nodeId) => _cache.get(nodeId);

  void put(TrustedNodeRow row) => _cache.put(row.nodeId, row);

  /// Cached row, or [loader] result when absent (cached on success).
  Future<TrustedNodeRow?> getOrLoad(
    String nodeId,
    Future<TrustedNodeRow?> Function() loader,
  ) => _cache.getOrLoad(nodeId, loader);

  void invalidate(String nodeId) => _cache.invalidate(nodeId);

  void invalidateAll() => _cache.clear();
}
