import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for watching the conversation list.
final class WatchSummariesParams {
  const WatchSummariesParams({this.includeArchived = false});
  final bool includeArchived;
}

/// Streams the conversation list (UI contract: lazy subscriptions only).
final class WatchSummaries
    extends
        UseCase<
          WatchSummariesParams,
          Stream<Result<List<ConversationSummary>>>
        > {
  const WatchSummaries(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Stream<Result<List<ConversationSummary>>>> call(
    WatchSummariesParams params,
  ) async {
    return _engine.watchSummaries(includeArchived: params.includeArchived);
  }
}
