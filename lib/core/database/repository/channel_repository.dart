import 'package:onebit/core/database/cache/channel_cache.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for channels and typing indicators.
///
/// Channel rows are cached for 30 s; every write invalidates the touched
/// channel synchronously so caches never outlive the database.
final class ChannelRepository {
  ChannelRepository({
    required this._dao,
    required this._cache,
    required this._logger,
  });

  final ChannelDao _dao;
  final ChannelCache _cache;
  final AppLogger _logger;

  static const _tag = 'channel.dao';

  /// Channel row for [channelId], cached for 30 s.
  Future<Result<ChannelRow?>> getChannel(String channelId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.getChannel',
        () => _cache.getOrLoad(channelId, () => _dao.getChannel(channelId)),
      );

  Future<Result<List<ChannelRow>>> listChannels({
    bool includeArchived = false,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.listChannels',
    () => _dao.listChannels(includeArchived: includeArchived),
  );

  Stream<Result<List<ChannelRow>>> watchChannels({
    bool includeArchived = false,
  }) => ResultGuards.guardWatch(
    _logger,
    '$_tag.watchChannels',
    _dao.watchChannels(includeArchived: includeArchived),
  );

  Future<Result<int>> upsertChannel(ChannelRow row) =>
      ResultGuards.guard(_logger, '$_tag.upsertChannel', () async {
        final written = await _dao.upsertChannel(row);
        _cache.put(row);
        return written;
      });

  Future<Result<int>> deleteChannel(String channelId) =>
      ResultGuards.guard(_logger, '$_tag.deleteChannel', () async {
        final written = await _dao.deleteChannel(channelId);
        _cache.invalidate(channelId);
        return written;
      });

  Future<Result<int>> setUnreadCount(String channelId, int count) =>
      ResultGuards.guard(_logger, '$_tag.setUnreadCount', () async {
        final written = await _dao.setUnreadCount(channelId, count);
        _cache.invalidate(channelId);
        return written;
      });

  Future<Result<int>> setArchived(String channelId, bool archived) =>
      ResultGuards.guard(_logger, '$_tag.setArchived', () async {
        final written = await _dao.setArchived(channelId, archived);
        _cache.invalidate(channelId);
        return written;
      });

  Future<Result<int>> setPinned(String channelId, bool pinned) =>
      ResultGuards.guard(_logger, '$_tag.setPinned', () async {
        final written = await _dao.setPinned(channelId, pinned);
        _cache.invalidate(channelId);
        return written;
      });

  Future<Result<int>> setMuted(
    String channelId, {
    required bool muted,
    DateTime? until,
  }) => ResultGuards.guard(_logger, '$_tag.setMuted', () async {
    final written = await _dao.setMuted(channelId, muted: muted, until: until);
    _cache.invalidate(channelId);
    return written;
  });

  /// Advances the channel tail; invalidates the cached row.
  Future<Result<int>> touchChannel(
    String channelId, {
    required String lastMessageId,
    required DateTime lastMessageAt,
    required int unreadDelta,
  }) => ResultGuards.guard(_logger, '$_tag.touchChannel', () async {
    final written = await _dao.touchChannel(
      channelId,
      lastMessageId: lastMessageId,
      lastMessageAt: lastMessageAt,
      unreadDelta: unreadDelta,
    );
    _cache.invalidate(channelId);
    return written;
  });

  // ---- Typing events ----------------------------------------------------------

  Future<Result<int>> insertTypingEvent(TypingEventsCompanion event) =>
      ResultGuards.guard(
        _logger,
        '$_tag.insertTypingEvent',
        () => _dao.insertTypingEvent(event),
      );

  Future<Result<int>> endTypingEvents(String channelId, String node) =>
      ResultGuards.guard(
        _logger,
        '$_tag.endTypingEvents',
        () => _dao.endTypingEvents(channelId, node),
      );

  Future<Result<List<TypingEventRow>>> activeTyping({int limit = 50}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.activeTyping',
        () => _dao.activeTyping(limit: limit),
      );
}
