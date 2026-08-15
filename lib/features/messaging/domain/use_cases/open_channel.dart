import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for opening a channel with a peer.
final class OpenChannelParams {
  const OpenChannelParams({required this.peer, this.title});

  /// Peer node id (private channel).
  final String peer;

  /// Optional display title.
  final String? title;
}

/// Opens (and lazily creates, idempotently) the private channel with a
/// peer. Returns the channel or the storage failure.
final class OpenChannel extends UseCase<OpenChannelParams, Result<Channel>> {
  const OpenChannel(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<Channel>> call(OpenChannelParams params) {
    return _engine.channels.create(
      CreateChannelParams(
        type: ChannelType.private,
        peer: params.peer,
        title: params.title,
      ),
    );
  }
}
