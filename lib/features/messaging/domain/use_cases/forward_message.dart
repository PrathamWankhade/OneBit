import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a forward.
final class ForwardMessageParams {
  const ForwardMessageParams({
    required this.messageId,
    required this.toChannelId,
  });

  final String messageId;
  final String toChannelId;
}

/// Forwards an existing message into another thread.
final class ForwardMessage extends UseCase<ForwardMessageParams, void> {
  const ForwardMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(ForwardMessageParams params) async {
    await _engine.forward(params.messageId, params.toChannelId);
  }
}
