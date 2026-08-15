import '../database.dart';
import 'memory_cache.dart';

/// Cache for the single local identity row (tiny, no TTL).
final class IdentityCache {
  IdentityCache({int maxEntries = 4})
    : _cache = MemoryCache<String, IdentityRow>(maxEntries: maxEntries);

  static const _key = 'identity';

  final MemoryCache<String, IdentityRow> _cache;

  IdentityRow? getIdentity() => _cache.get(_key);

  void putIdentity(IdentityRow row) => _cache.put(_key, row);

  /// Cached identity, or [loader] result when absent (cached on success).
  Future<IdentityRow?> getOrLoadIdentity(
    Future<IdentityRow?> Function() loader,
  ) => _cache.getOrLoad(_key, loader);

  /// Drops the cached row; the next read re-loads from the database.
  void invalidate() => _cache.clear();
}
