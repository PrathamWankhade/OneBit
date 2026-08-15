import '../database.dart';
import 'memory_cache.dart';

/// Very short-TTL cache for volatile neighbor presence rows.
final class NeighborCache {
  NeighborCache({
    Duration ttl = const Duration(seconds: 10),
    int maxEntries = 128,
  }) : _cache = MemoryCache<String, NeighborRow>(
         ttl: ttl,
         maxEntries: maxEntries,
       );

  final MemoryCache<String, NeighborRow> _cache;

  NeighborRow? get(String node) => _cache.get(node);

  void put(NeighborRow row) => _cache.put(row.node, row);

  /// Cached row, or [loader] result when absent (cached on success).
  Future<NeighborRow?> getOrLoad(
    String node,
    Future<NeighborRow?> Function() loader,
  ) => _cache.getOrLoad(node, loader);

  void invalidate(String node) => _cache.invalidate(node);

  void clear() => _cache.clear();
}
