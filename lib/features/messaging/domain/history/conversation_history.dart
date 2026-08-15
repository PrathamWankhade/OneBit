import 'package:onebit/core/result/result.dart';

import '../messages/message.dart';
import '../messages/message_ordering.dart';

/// Contract for lazy timeline history loading.
///
/// The UI calls `page(channelId, cursor: null)` for the newest page and
/// then pages backward with the returned cursor — O(log n) per fetch,
/// stable under concurrent writes.
abstract interface class ConversationHistory {
  Future<Result<MessagePage>> loadNewest(String channelId, {int limit = 50});

  Future<Result<MessagePage>> loadOlder(
    String channelId, {
    required TimelineCursor cursor,
    int limit = 50,
  });

  /// Jumps to a specific message (search result / pinned / reply target)
  /// and returns the page containing it plus the anchor.
  Future<Result<MessagePage>> loadAround(
    String channelId, {
    required String anchorMessageId,
    int window = 25,
  });

  /// Number of messages in the channel (used for "scroll to bottom" math).
  Future<Result<int>> count(String channelId);

  /// The newest message of the channel, if any.
  Future<Result<Message?>> newest(String channelId);
}
