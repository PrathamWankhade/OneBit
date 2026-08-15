import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/features/messaging/domain/messages/message_search_result.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a message search.
final class SearchMessagesParams {
  const SearchMessagesParams({
    this.terms = '',
    this.channelId,
    this.sender,
    this.from,
    this.to,
    this.offset = 0,
    this.limit = 50,
  });

  final String terms;
  final String? channelId;
  final String? sender;
  final DateTime? from;
  final DateTime? to;
  final int offset;
  final int limit;
}

/// Searches the local message store (FTS-backed).
final class SearchMessages
    extends
        UseCase<SearchMessagesParams, Result<SearchPage<MessageSearchResult>>> {
  const SearchMessages(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<SearchPage<MessageSearchResult>>> call(
    SearchMessagesParams params,
  ) async {
    return _engine.searchMessages(
      MessageSearchQuery(
        terms: params.terms,
        channelId: params.channelId,
        sender: params.sender,
        from: params.from,
        to: params.to,
      ),
      offset: params.offset,
      limit: params.limit,
    );
  }
}
