import 'package:flutter/foundation.dart';

/// A logical channel within the mesh.
///
/// Channels group messages by topic across hops (like IRC rooms on a mesh).
/// Domain value only — persistence and encryption per channel arrive in
/// later phases.
@immutable
final class MeshChannel {
  const MeshChannel({
    required this.channelId,
    required this.name,
    required this.isSubscribed,
  });

  /// Stable channel identifier.
  final String channelId;

  /// Display name.
  final String name;

  /// Whether the local node has subscribed to this channel.
  final bool isSubscribed;

  MeshChannel copyWith({bool? isSubscribed}) => MeshChannel(
    channelId: channelId,
    name: name,
    isSubscribed: isSubscribed ?? this.isSubscribed,
  );

  @override
  bool operator ==(Object other) =>
      other is MeshChannel && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;
}
