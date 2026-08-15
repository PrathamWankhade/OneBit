import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for (re)generating a delivery receipt.
final class GenerateReceiptParams {
  const GenerateReceiptParams(this.messageId);

  /// The inbound message to acknowledge back to its sender.
  final String messageId;
}

/// Mints (or re-mints) the delivery receipt for [GenerateReceiptParams]
/// and queues its envelope back to the sender, then persists the receipt
/// row. Idempotent per (messageId, node) pair.
final class GenerateReceipt
    extends UseCase<GenerateReceiptParams, Result<GenerateReceiptResult>> {
  const GenerateReceipt(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<GenerateReceiptResult>> call(GenerateReceiptParams params) {
    return _engine.generateReceipt(params.messageId);
  }
}
