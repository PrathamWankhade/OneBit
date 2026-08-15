import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for saving a draft.
final class SaveDraftParams {
  const SaveDraftParams({required this.channelId, required this.body});
  final String channelId;
  final String body;
}

/// Upserts the draft of a channel.
final class SaveDraft extends UseCase<SaveDraftParams, Result<void>> {
  const SaveDraft(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<void>> call(SaveDraftParams params) async {
    return _engine.saveDraft(params.channelId, params.body);
  }
}
