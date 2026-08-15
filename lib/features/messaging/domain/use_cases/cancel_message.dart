import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a cancellation.
final class CancelMessageParams {
  const CancelMessageParams(this.messageId);
  final String messageId;
}

/// Cancels an outbound message against the DTN layer.
final class CancelMessage extends UseCase<CancelMessageParams, void> {
  const CancelMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(CancelMessageParams params) async {
    await _engine.cancel(params.messageId);
  }
}
