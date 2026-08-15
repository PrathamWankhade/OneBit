import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a retry.
final class RetryMessageParams {
  const RetryMessageParams(this.messageId);
  final String messageId;
}

/// Re-queues a failed message into the outbox.
final class RetryMessage extends UseCase<RetryMessageParams, void> {
  const RetryMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(RetryMessageParams params) async {
    await _engine.retry(params.messageId);
  }
}
