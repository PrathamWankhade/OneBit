import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for watching a channel timeline.
final class WatchTimelineParams {
  const WatchTimelineParams({required this.channelId, this.limit = 100});
  final String channelId;
  final int limit;
}

/// Streams a channel timeline (newest-last).
final class WatchTimeline
    extends UseCase<WatchTimelineParams, Stream<Result<List<Message>>>> {
  const WatchTimeline(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Stream<Result<List<Message>>>> call(WatchTimelineParams params) async {
    return _engine.watchChannel(params.channelId, limit: params.limit);
  }
}
