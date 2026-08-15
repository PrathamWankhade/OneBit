import 'package:flutter/foundation.dart';

/// An emoji reaction attached to a message by a node.
@immutable
final class MessageReaction {
  const MessageReaction({
    required this.messageId,
    required this.node,
    required this.reaction,
    required this.createdAt,
  });

  final String messageId;

  /// The node whose user reacted.
  final String node;

  /// The reaction value (single emoji string, e.g. `+1` or `👍`).
  final String reaction;

  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is MessageReaction &&
      other.messageId == messageId &&
      other.node == node &&
      other.reaction == reaction;

  @override
  int get hashCode => Object.hash(messageId, node, reaction);
}
