import '../database.dart';
import 'memory_cache.dart';

/// Short-TTL cache for channel rows.
final class ChannelCache {
  ChannelCache({
    Duration ttl = const Duration(seconds: 30),
    int maxEntries = 128,
  }) : _cache = MemoryCache<String, ChannelRow>(
         ttl: ttl,
         maxEntries: maxEntries,
       );

  final MemoryCache<String, ChannelRow> _cache;

  ChannelRow? get(String channelId) => _cache.get(channelId);

  void put(ChannelRow row) => _cache.put(row.channelId, row);

  /// Cached row, or [loader] result when absent (cached on success).
  Future<ChannelRow?> getOrLoad(
    String channelId,
    Future<ChannelRow?> Function() loader,
  ) => _cache.getOrLoad(channelId, loader);

  void invalidate(String channelId) => _cache.invalidate(channelId);

  void invalidateAll(List<String> channelIds) =>
      _cache.invalidateWhere(channelIds.toSet().contains);

  void clear() => _cache.clear();
}
