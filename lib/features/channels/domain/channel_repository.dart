import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/channels/domain/mesh_channel.dart';

/// Repository contract for channels.
abstract interface class ChannelRepository {
  /// Emits the full channel list with subscription flags.
  Stream<Result<List<MeshChannel>>> watchChannels();

  /// Subscribes the local node to [channel].
  Future<Result<void>> subscribe(MeshChannel channel);

  /// Unsubscribes from [channel].
  Future<Result<void>> unsubscribe(String channelId);
}
