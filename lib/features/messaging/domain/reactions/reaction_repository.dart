import 'package:onebit/core/result/result.dart';

import '../messages/message_reaction.dart';

/// Contract for reaction persistence.
abstract interface class ReactionRepository {
  /// Adds or updates a reaction. Idempotent per (messageId, node, reaction).
  Future<Result<void>> upsert(MessageReaction reaction);

  /// Removes a specific reaction.
  Future<Result<void>> remove(String messageId, String node, String reaction);

  /// Removes all reactions from [node] on [messageId].
  Future<Result<void>> removeAllByNode(String messageId, String node);

  /// Streams reactions for a message (real-time UI updates).
  Stream<Result<List<MessageReaction>>> watch(String messageId);

  /// Counts reactions grouped by emoji for a message.
  Future<Result<Map<String, int>>> counts(String messageId);

  /// Checks if [node] has reacted with [reaction] on [messageId].
  Future<Result<bool>> hasReacted(
    String messageId,
    String node,
    String reaction,
  );
}
