import 'memory_cache.dart';

/// Cache for settings key → value pairs (key-value, no TTL).
final class SettingsCache {
  SettingsCache({int maxEntries = 64})
    : _cache = MemoryCache<String, String>(maxEntries: maxEntries);

  final MemoryCache<String, String> _cache;

  String? get(String key) => _cache.get(key);

  void put(String key, String value) => _cache.put(key, value);

  /// Cached value, or [loader] result when absent (cached on success).
  Future<String?> getOrLoad(String key, Future<String?> Function() loader) =>
      _cache.getOrLoad(key, loader);

  void invalidate(String key) => _cache.invalidate(key);

  void clear() => _cache.clear();
}
