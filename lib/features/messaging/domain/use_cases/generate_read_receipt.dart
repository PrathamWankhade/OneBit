import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for emitting read receipts of a channel.
final class GenerateReadReceiptParams {
  const GenerateReadReceiptParams(this.channelId);

  final String channelId;
}

/// Marks every message of the channel read through the newest one and emits
/// ONE batched read-cursor envelope back to the peer (a whole thread never
/// produces per-message receipt packets). Returns the number of messages
/// marked read.
final class GenerateReadReceipt
    extends UseCase<GenerateReadReceiptParams, Result<int>> {
  const GenerateReadReceipt(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<int>> call(GenerateReadReceiptParams params) {
    return _engine.markChannelRead(params.channelId);
  }
}
