import '../database.dart';
import 'memory_cache.dart';

/// Short-TTL cache for route rows keyed by destination.
final class RouteCache {
  RouteCache({Duration ttl = const Duration(seconds: 30), int maxEntries = 128})
    : _cache = MemoryCache<String, RouteRow>(ttl: ttl, maxEntries: maxEntries);

  final MemoryCache<String, RouteRow> _cache;

  RouteRow? get(String destination) => _cache.get(destination);

  void put(RouteRow row) => _cache.put(row.destination, row);

  /// Cached row, or [loader] result when absent (cached on success).
  Future<RouteRow?> getOrLoad(
    String destination,
    Future<RouteRow?> Function() loader,
  ) => _cache.getOrLoad(destination, loader);

  void invalidate(String destination) => _cache.invalidate(destination);

  void clear() => _cache.clear();
}
