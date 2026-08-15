import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a reply.
final class ReplyMessageParams {
  const ReplyMessageParams({
    required this.channelId,
    required this.body,
    required this.replyTo,
  });

  final String channelId;
  final String body;

  /// Message being replied to.
  final String replyTo;
}

/// Sends a reply inside the same thread.
final class ReplyMessage extends UseCase<ReplyMessageParams, void> {
  const ReplyMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(ReplyMessageParams params) async {
    await _engine.reply(params.channelId, params.body, params.replyTo);
  }
}
