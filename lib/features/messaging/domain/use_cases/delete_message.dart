import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a delete (soft tombstone).
final class DeleteMessageParams {
  const DeleteMessageParams(this.messageId);
  final String messageId;
}

/// Soft-deletes a message everywhere (local tombstone + index eviction).
final class DeleteMessage extends UseCase<DeleteMessageParams, void> {
  const DeleteMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(DeleteMessageParams params) async {
    await _engine.delete(params.messageId);
  }
}
