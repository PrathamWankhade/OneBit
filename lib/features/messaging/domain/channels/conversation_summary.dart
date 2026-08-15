import 'package:flutter/foundation.dart';

import 'channel_type.dart';

/// The listing card of a conversation: everything the conversation list
/// needs without touching the message table.
///
/// Derived from the persisted `Channels` row — it is the object streamed to
/// the future UI.
@immutable
final class ConversationSummary {
  const ConversationSummary({
    required this.channelId,
    required this.type,
    required this.title,
    this.peerNode,
    this.unreadCount = 0,
    this.lastMessageId,
    this.lastMessageAt,
    this.lastActivityAt,
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    this.updatedAt,
  });

  final String channelId;
  final ChannelType type;
  final String title;

  /// The other participant (private channels).
  final String? peerNode;

  /// Unread message count.
  final int unreadCount;

  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final DateTime? lastActivityAt;

  final bool pinned;
  final bool muted;
  final bool archived;
  final DateTime? updatedAt;

  /// Emits a stable preview for list rendering (subject to change later).
  String get preview => lastMessageId ?? '';

  ConversationSummary copyWith({
    String? title,
    String? peerNode,
    int? unreadCount,
    String? lastMessageId,
    DateTime? lastMessageAt,
    DateTime? lastActivityAt,
    bool? pinned,
    bool? muted,
    bool? archived,
    DateTime? updatedAt,
  }) => ConversationSummary(
    channelId: channelId,
    type: type,
    title: title ?? this.title,
    peerNode: peerNode ?? this.peerNode,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessageId: lastMessageId ?? this.lastMessageId,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    pinned: pinned ?? this.pinned,
    muted: muted ?? this.muted,
    archived: archived ?? this.archived,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ConversationSummary && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;
}
