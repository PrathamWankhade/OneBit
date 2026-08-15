import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for an edit.
final class EditMessageParams {
  const EditMessageParams({
    required this.messageId,
    required this.body,
    this.rebroadcast = true,
  });

  final String messageId;
  final String body;

  /// Whether the edit is re-broadcast to peers over the wire.
  final bool rebroadcast;
}

/// Edits a message body (local + optional wire resend).
final class EditMessage extends UseCase<EditMessageParams, void> {
  const EditMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(EditMessageParams params) async {
    await _engine.edit(
      params.messageId,
      params.body,
      rebroadcast: params.rebroadcast,
    );
  }
}
