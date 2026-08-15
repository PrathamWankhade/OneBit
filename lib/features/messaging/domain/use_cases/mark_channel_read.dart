import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for marking a channel fully read (+ read receipts).
final class MarkChannelReadParams {
  const MarkChannelReadParams(this.channelId);
  final String channelId;
}

/// Marks a channel read through the newest message and emits read receipts
/// for unread outbound messages. Returns the number of receipts emitted.
final class MarkChannelRead
    extends UseCase<MarkChannelReadParams, Result<int>> {
  const MarkChannelRead(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<int>> call(MarkChannelReadParams params) async {
    return _engine.markChannelRead(params.channelId);
  }
}
