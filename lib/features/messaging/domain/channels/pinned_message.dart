import 'package:flutter/foundation.dart';

/// A message pinned to a channel heading.
@immutable
final class PinnedMessage {
  const PinnedMessage({
    required this.channelId,
    required this.messageId,
    required this.pinnedBy,
    required this.pinnedAt,
  });

  final String channelId;
  final String messageId;

  /// The node that pinned the message.
  final String pinnedBy;

  final DateTime pinnedAt;

  @override
  bool operator ==(Object other) =>
      other is PinnedMessage &&
      other.channelId == channelId &&
      other.messageId == messageId;

  @override
  int get hashCode => Object.hash(channelId, messageId);
}
