import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/domain/messages/message_reaction.dart';

/// Maps [MessageReactionRow] ↔ [MessageReaction].
abstract final class ReactionMapper {
  const ReactionMapper._();

  static MessageReaction toDomain(MessageReactionRow row) => MessageReaction(
    messageId: row.messageId,
    node: row.node,
    reaction: row.reaction,
    createdAt: row.createdAt,
  );

  static MessageReactionRow toRow(MessageReaction reaction) =>
      MessageReactionRow(
        messageId: reaction.messageId,
        node: reaction.node,
        reaction: reaction.reaction,
        createdAt: reaction.createdAt,
      );
}
