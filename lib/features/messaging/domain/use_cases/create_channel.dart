import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart'
    as repository;
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for explicitly creating a channel.
final class CreateChannelParams {
  const CreateChannelParams({
    required this.type,
    this.title,
    this.peer,
    this.autoDeleteAfter,
  });

  final ChannelType type;

  /// Display title (defaults to the peer's name for private channels).
  final String? title;

  /// The other participant (private channels only).
  final String? peer;

  /// Optional local retention window.
  final Duration? autoDeleteAfter;
}

/// Creates a channel, or returns the existing one for the same
/// `(type, peer/title)` key (idempotent).
final class CreateChannel
    extends UseCase<CreateChannelParams, Result<Channel>> {
  const CreateChannel(this._engine);

  final MessagingEngine _engine;

  @override
  Future<Result<Channel>> call(CreateChannelParams params) {
    return _engine.channels.create(
      repository.CreateChannelParams(
        type: params.type,
        title: params.title,
        peer: params.peer,
        autoDeleteAfter: params.autoDeleteAfter,
      ),
    );
  }
}
