import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// Creates origin packets for the local node.
///
/// Every locally-originated packet carries the local node id as its source,
/// a source-local monotonic sequence number, the local node already on its
/// path (so route learning and loop prevention see it immediately), and the
/// default TTL.
final class MeshPacketFactory {
  MeshPacketFactory({required this.localNodeId, required this.now});

  final String localNodeId;
  final DateTime Function() now;
  int _sequence = 0;

  /// A data packet addressed to [destination].
  MeshPacket originData({
    required String destination,
    List<int> payload = const [],
    int ttl = 8,
  }) => _origin(
    destination: destination,
    kind: MeshPacketKind.data,
    payload: payload,
    ttl: ttl,
  );

  /// A route-discovery request broadcast.
  MeshPacket originDiscoveryRequest({required String target, int ttl = 8}) =>
      _origin(
        destination: '',
        kind: MeshPacketKind.control,
        control: RouteDiscoveryRequest(target),
        ttl: ttl,
      );

  /// A route-discovery reply addressed to [requester].
  MeshPacket originDiscoveryReply({
    required String requester,
    required String target,
    required List<String> path,
    int ttl = 8,
  }) => _origin(
    destination: requester,
    kind: MeshPacketKind.control,
    control: RouteDiscoveryReply(target, path),
    ttl: ttl,
  );

  MeshPacket _origin({
    required String destination,
    required MeshPacketKind kind,
    MeshControl? control,
    List<int> payload = const [],
    int ttl = 8,
  }) {
    _sequence++;
    return MeshPacket(
      source: localNodeId,
      destination: destination,
      kind: kind,
      control: control,
      payload: payload,
      ttl: ttl,
      hopCount: 0,
      path: [localNodeId],
      sequence: _sequence,
      createdAt: now(),
    );
  }
}
