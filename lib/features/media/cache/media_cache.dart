import 'package:flutter/foundation.dart';

/// The byte-cache seam — implemented in pure Dart for memory ([MemoryCache])
/// and by the data layer for disk.
abstract interface class BlobCache {
  /// Reads a cached value (bumping its recency), or null.
  Future<Uint8List?> get(String key);

  /// Stores [bytes] under [key], honoring the capacity policy.
  Future<void> put(String key, Uint8List bytes);

  /// Removes one entry.
  Future<void> evict(String key);

  /// Drops everything (clears catalog + bytes).
  Future<void> clear();

  /// Current size (bytes) of the managed payloads.
  int get byteSize;

  /// Number of managed payloads.
  int get entryCount;
}

/// Capacity policy of an in-memory cache.
@immutable
final class CachePolicy {
  const CachePolicy({this.maxBytes = 32 * 1024 * 1024, this.maxEntries = 512});

  final int maxBytes;
  final int maxEntries;
}

/// Bounded LRU byte cache in memory.
///
/// Evicts least-recently-used entries when [CachePolicy.maxBytes] or
/// [CachePolicy.maxEntries] is exceeded. Pure Dart — no I/O.
final class MemoryCache implements BlobCache {
  MemoryCache({this._policy = const CachePolicy()});

  final CachePolicy _policy;

  /// Doubly-linked LRU entries.
  final Map<String, _Entry> _entries = <String, _Entry>{};
  _Entry? _head;
  _Entry? _tail;
  int _bytes = 0;
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  @override
  int get byteSize => _bytes;

  @override
  int get entryCount => _entries.length;

  int get hits => _hits;
  int get misses => _misses;
  int get evictions => _evictions;

  @override
  Future<Uint8List?> get(String key) async {
    final entry = _entries[key];
    if (entry == null) {
      _misses++;
      return null;
    }
    _hits++;
    _touch(entry);
    return entry.bytes;
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    final existing = _entries[key];
    if (existing != null) {
      existing.bytes = bytes;
      _bytes += bytes.length - existing.byteSize;
      _touch(existing);
    } else {
      final entry = _Entry(key, bytes);
      _entries[key] = entry;
      _bytes += bytes.length;
      _linkHead(entry);
    }
    _enforcePolicy();
  }

  @override
  Future<void> evict(String key) async {
    final entry = _entries.remove(key);
    if (entry != null) {
      _bytes -= entry.byteSize;
      _unlink(entry);
      _evictions++;
    }
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _head = null;
    _tail = null;
    _bytes = 0;
  }

  /// Whether [key] is cached (does not bump recency).
  bool contains(String key) => _entries.containsKey(key);

  void _enforcePolicy() {
    while (_bytes > _policy.maxBytes || _entries.length > _policy.maxEntries) {
      final oldest = _tail;
      if (oldest == null) break;
      _entries.remove(oldest.key);
      _bytes -= oldest.byteSize;
      _unlink(oldest);
      _evictions++;
    }
  }

  void _touch(_Entry entry) {
    _unlink(entry);
    _linkHead(entry);
  }

  void _linkHead(_Entry entry) {
    entry.next = _head;
    entry.prev = null;
    if (_head != null) {
      _head!.prev = entry;
    } else {
      _tail = entry;
    }
    _head = entry;
  }

  void _unlink(_Entry entry) {
    final prev = entry.prev;
    final next = entry.next;
    if (prev != null) {
      prev.next = next;
    } else if (_head == entry) {
      _head = next;
    }
    if (next != null) {
      next.prev = prev;
    } else if (_tail == entry) {
      _tail = prev;
    }
    entry.prev = null;
    entry.next = null;
  }
}

final class _Entry {
  _Entry(this.key, this.bytes);

  final String key;
  Uint8List bytes;

  /// Payload length snapshot (bytes can be replaced in place).
  int get byteSize => bytes.length;

  _Entry? prev;
  _Entry? next;
}
