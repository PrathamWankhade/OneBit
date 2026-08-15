import 'package:flutter/foundation.dart';

import 'channel_settings.dart';
import 'channel_type.dart';
import 'conversation_summary.dart';

/// A logical channel: the top-level grouping of a conversation.
///
/// The row-level summary is embedded; settings are mutable only through the
/// repository. Immutable by construction.
@immutable
final class Channel {
  const Channel({
    required this.channelId,
    required this.type,
    required this.title,
    required this.settings,
    required this.summary,
    this.peer,
    this.createdAt,
  });

  final String channelId;
  final ChannelType type;

  /// Display title (defaults to the peer's display name for private
  /// channels).
  final String title;

  /// Peer node id (private channels only).
  final String? peer;

  final DateTime? createdAt;
  final ChannelSettings settings;
  final ConversationSummary summary;

  Channel copyWith({
    String? title,
    ChannelSettings? settings,
    ConversationSummary? summary,
  }) => Channel(
    channelId: channelId,
    type: type,
    title: title ?? this.title,
    peer: peer,
    createdAt: createdAt,
    settings: settings ?? this.settings,
    summary: summary ?? this.summary,
  );

  @override
  bool operator ==(Object other) =>
      other is Channel && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;
}
