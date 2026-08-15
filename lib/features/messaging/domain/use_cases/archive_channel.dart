import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for archiving / restoring a channel.
final class ArchiveChannelParams {
  const ArchiveChannelParams(this.channelId, {this.archived = true});

  final String channelId;

  /// True hides the channel from the active list; false restores it.
  final bool archived;
}

/// Soft-hides a channel from the active conversation list (or restores it).
final class ArchiveChannel extends UseCase<ArchiveChannelParams, Result<void>> {
  const ArchiveChannel(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<void>> call(ArchiveChannelParams params) {
    return _engine.channels.archive(
      params.channelId,
      archived: params.archived,
    );
  }
}
