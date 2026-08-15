import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_settings.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/channels/pinned_message.dart';

/// Maps `ChannelRow` ↔ [Channel] / [ConversationSummary].
abstract final class ChannelMapper {
  const ChannelMapper._();

  /// Stable channel id for a private 1:1 conversation. Both node ids are
  /// sorted so both peers derive the same id (`private:x:y`).
  static String privateChannelId(String nodeA, String nodeB) {
    final sorted = [nodeA, nodeB]..sort();
    return 'private:${sorted[0]}:${sorted[1]}';
  }

  /// The peer of [ownNode] inside a private channel id.
  static String? peerOf(String channelId, String ownNode) {
    const prefix = 'private:';
    if (!channelId.startsWith(prefix)) return null;
    final parts = channelId.substring(prefix.length).split(':');
    if (parts.length != 2) return null;
    return parts[0] == ownNode ? parts[1] : parts[0];
  }

  /// Persisted core enum for a domain channel type. Private channels are
  /// persisted as the legacy `direct` value (v2 rows already use it).
  static core.ChannelType toCore(ChannelType type) =>
      core.ChannelType.values.firstWhere(
        (t) => t.name == (type == ChannelType.private ? 'direct' : type.name),
        orElse: () => core.ChannelType.direct,
      );

  static ChannelType fromCore(core.ChannelType type) => switch (type.name) {
    'private' || 'direct' => ChannelType.private,
    'group' => ChannelType.group,
    'broadcast' => ChannelType.broadcast,
    'emergency' => ChannelType.emergency,
    'developer' => ChannelType.developer,
    _ => ChannelType.private,
  };

  static ChannelRow toRow(Channel channel, {int sequence = 0}) => ChannelRow(
    channelId: channel.channelId,
    type: toCore(channel.type),
    title: channel.title,
    createdAt: channel.createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
    unreadCount: channel.summary.unreadCount.clamp(0, 1 << 30).toInt(),
    lastMessageId: channel.summary.lastMessageId,
    lastMessageAt: channel.summary.lastMessageAt,
    archived: channel.summary.archived,
    pinned: channel.settings.pinned,
    muted: channel.settings.muted,
    mutedUntil: channel.settings.mutedUntil,
    lastSequence: sequence,
    notificationPreference: channel.settings.notificationPreference.name,
    autoDeleteAfter: _secondsOrNull(channel.settings.autoDeleteAfter),
  );

  static Channel toDomain(ChannelRow row) {
    final type = fromCore(row.type);
    final settings = ChannelSettings(
      muted: row.muted,
      mutedUntil: row.mutedUntil,
      pinned: row.pinned,
      notificationPreference:
          ChannelNotificationPreference.values
              .where((p) => p.name == row.notificationPreference)
              .firstOrNull ??
          ChannelNotificationPreference.all,
      autoDeleteAfter: _toDuration(row.autoDeleteAfter),
    );
    return Channel(
      channelId: row.channelId,
      type: type,
      title: row.title ?? '',
      createdAt: row.createdAt,
      settings: settings,
      summary: _summaryFrom(row),
    );
  }

  static ConversationSummary toSummary(ChannelRow row) => _summaryFrom(row);

  static PinnedMessage toPinnedMessage(PinnedMessageRow row) => PinnedMessage(
    channelId: row.channelId,
    messageId: row.messageId,
    pinnedBy: row.pinnedBy,
    pinnedAt: row.pinnedAt,
  );

  static ConversationSummary _summaryFrom(ChannelRow row) =>
      ConversationSummary(
        channelId: row.channelId,
        type: fromCore(row.type),
        title: row.title ?? '',
        unreadCount: row.unreadCount,
        lastMessageId: row.lastMessageId,
        lastMessageAt: row.lastMessageAt,
        lastActivityAt: row.updatedAt,
        pinned: row.pinned,
        muted: row.muted,
        archived: row.archived,
        updatedAt: row.updatedAt,
      );

  static int? _secondsOrNull(Duration? duration) => duration?.inSeconds;

  static Duration? _toDuration(int? seconds) =>
      seconds == null ? null : Duration(seconds: seconds);
}
