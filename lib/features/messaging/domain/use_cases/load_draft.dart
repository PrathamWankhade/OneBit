import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for loading a draft.
final class LoadDraftParams {
  const LoadDraftParams(this.channelId);
  final String channelId;
}

/// Loads the current draft of a channel (null when absent).
final class LoadDraft extends UseCase<LoadDraftParams, Result<Draft?>> {
  const LoadDraft(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<Draft?>> call(LoadDraftParams params) async {
    return _engine.loadDraft(params.channelId);
  }
}
