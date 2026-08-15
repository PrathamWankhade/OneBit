import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for a user-initiated send.
final class SendMessageParams {
  const SendMessageParams({
    required this.channelId,
    required this.body,
    this.type = MessageType.text,
    this.priority = MessagePriority.normal,
    this.replyTo,
    this.clientId,
  });

  final String channelId;
  final String body;
  final MessageType type;
  final MessagePriority priority;

  /// Id of the message being replied to, when this send is a reply.
  final String? replyTo;

  /// Client-side idempotency key (the send reuses the same message id).
  final String? clientId;
}

/// Composes and enqueues one message through [MessagingEngine.send].
final class SendMessage extends UseCase<SendMessageParams, void> {
  const SendMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<void> call(SendMessageParams params) async {
    await _engine.send(
      params.channelId,
      params.body,
      type: params.type,
      priority: params.priority,
      replyTo: params.replyTo,
      clientId: params.clientId,
    );
  }
}
