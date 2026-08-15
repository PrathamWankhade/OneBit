import 'package:onebit/core/result/result.dart';

import '../channels/conversation_summary.dart';
import '../messages/message_search_result.dart';

/// Contract for local search.
///
/// The FTS index lives on-device and is written through by the engine at
/// every message mutation; search never touches the network.
abstract interface class SearchRepository {
  /// Full-text search over the local message store.
  Future<Result<SearchPage<MessageSearchResult>>> searchMessages(
    MessageSearchQuery query, {
    int offset = 0,
    int limit = 50,
  });

  /// Plain indexed search over channels (titles and peer node ids). When the
  /// implementation knows the local node id it also resolves peer *display
  /// names* through node profiles.
  Future<Result<List<ConversationSummary>>> searchChannels(
    String terms, {
    int limit = 25,
  });

  /// Channel lookup by peer display name / node id through node profiles.
  Future<Result<List<ConversationSummary>>> searchChannelsByNodeName(
    String terms, {
    int limit = 25,
  });

  /// Rebuilds the index from the message table (repair/startup path).
  /// Returns the number of indexed rows.
  Future<Result<int>> rebuildIndex();

  /// Re-indexes one message (insert/update path).
  Future<Result<void>> indexMessage({
    required String messageId,
    required String channelId,
    required String body,
    required String sender,
    required String nodeName,
    required String type,
    required int timestampMs,
  });

  Future<Result<void>> removeFromIndex(String messageId);
}
