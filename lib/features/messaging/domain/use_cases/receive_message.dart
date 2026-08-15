import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for an inbound wire payload.
final class ReceiveMessageParams {
  const ReceiveMessageParams({
    required this.payload,
    this.packetId,
    this.source,
  });

  /// Raw wire bytes of one app-level envelope.
  final List<int> payload;

  /// The DTN packet id that carried the envelope (metadata on the stored
  /// message).
  final String? packetId;

  /// Origin node id (fallback when the envelope does not carry one).
  final String? source;
}

/// Decodes, dedupes, persists and confirms one inbound wire payload.
///
/// The receive path is the counterpart of [SendMessage]: duplicates are
/// dropped, unread counters and search are raised, notifications are
/// emitted and a delivery receipt is generated back to the sender when the
/// envelope addressed this node.
final class ReceiveMessage
    extends UseCase<ReceiveMessageParams, Result<ReceiveResult>> {
  const ReceiveMessage(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<ReceiveResult>> call(ReceiveMessageParams params) {
    return _engine.handleInboundPayload(
      params.payload,
      packetId: params.packetId,
      source: params.source,
    );
  }
}
