import 'package:flutter/foundation.dart';

/// Notification policy of a channel.
enum ChannelNotificationPreference {
  /// Every inbound message notifies.
  all,

  /// Only mentions and system events notify.
  mentionsOnly,

  /// Nothing notifies (muted).
  none,
}

/// User-modifiable settings of a channel.
@immutable
final class ChannelSettings {
  const ChannelSettings({
    this.muted = false,
    this.mutedUntil,
    this.pinned = false,
    this.notificationPreference = ChannelNotificationPreference.all,
    this.autoDeleteAfter,
    this.description,
  });

  /// Whether the channel is muted.
  final bool muted;

  /// Optional expiry of the mute window; null = muted forever.
  final DateTime? mutedUntil;

  /// Whether the channel is pinned to the top of the conversation list.
  final bool pinned;

  final ChannelNotificationPreference notificationPreference;

  /// Optional local retention: messages auto-delete after this period.
  final Duration? autoDeleteAfter;

  /// Local description/notes about the channel.
  final String? description;

  bool get isEffectivelyMuted {
    if (!muted) return false;
    final until = mutedUntil;
    return until == null || until.isAfter(DateTime.now());
  }

  ChannelSettings copyWith({
    bool? muted,
    DateTime? mutedUntil,
    bool? pinned,
    ChannelNotificationPreference? notificationPreference,
    Duration? autoDeleteAfter,
    String? description,
  }) => ChannelSettings(
    muted: muted ?? this.muted,
    mutedUntil: mutedUntil ?? this.mutedUntil,
    pinned: pinned ?? this.pinned,
    notificationPreference:
        notificationPreference ?? this.notificationPreference,
    autoDeleteAfter: autoDeleteAfter ?? this.autoDeleteAfter,
    description: description ?? this.description,
  );
}
