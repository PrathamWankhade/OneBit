import 'dart:collection';

/// Bounded, optional-TTL LRU cache with single-flight loads.
///
/// Read-through only: the database stays the source of truth and callers
/// (repositories) invalidate entries synchronously with every write.
final class MemoryCache<K, V> {
  MemoryCache({this.maxEntries = 128, this.ttl});

  /// Hard capacity; evicts least-recently-used entries when exceeded.
  final int maxEntries;

  /// Entry lifetime; `null` keeps entries until invalidated or evicted.
  final Duration? ttl;

  final LinkedHashMap<K, _Entry<V>> _entries = LinkedHashMap();
  final Map<K, Future<V?>> _inFlight = {};

  /// Returns the value for [key] without extending its lifetime.
  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    _entries[key] = entry;
    if (entry.isExpired(ttl)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Stores [value] under [key], refreshing its TTL.
  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = _Entry(value);
    _evictIfNeeded();
  }

  /// Returns the cached value, or loads it through [loader] and caches it.
  ///
  /// Concurrent misses for the same key share a single in-flight load so a
  /// cache-warm boot cannot stampede the database.
  Future<V?> getOrLoad(K key, Future<V?> Function() loader) {
    final cached = get(key);
    if (cached != null) {
      return Future.value(cached);
    }
    final inFlight = _inFlight[key];
    if (inFlight != null) {
      return inFlight;
    }
    final future = loader()
        .then((value) {
          if (value != null) {
            put(key, value);
          }
          return value;
        })
        .whenComplete(() {
          _inFlight.remove(key);
        });
    _inFlight[key] = future;
    return future;
  }

  /// Removes a single entry.
  void invalidate(K key) => _entries.remove(key);

  /// Removes every entry whose key satisfies [test].
  void invalidateWhere(bool Function(K key) test) {
    _entries.removeWhere((key, _) => test(key));
  }

  /// Removes all entries.
  void clear() => _entries.clear();

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

final class _Entry<V> {
  _Entry(this.value) : createdAt = DateTime.now();

  final V value;
  final DateTime createdAt;

  bool isExpired(Duration? ttl) =>
      ttl != null && DateTime.now().difference(createdAt) > ttl;
}
