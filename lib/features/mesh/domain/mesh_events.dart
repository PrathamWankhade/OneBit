import 'mesh_engine_state.dart';
import 'mesh_route.dart';

/// Neighbor-lifecycle event emitted by the discovery engine.
sealed class MeshNeighborEvent {
  const MeshNeighborEvent(this.nodeId);

  final String nodeId;
}

/// A neighbor appeared or refreshed its advertisement.
final class MeshNeighborSeen extends MeshNeighborEvent {
  const MeshNeighborSeen(super.nodeId, this.isNew);

  final bool isNew;
}

/// A neighbor expired or was explicitly removed.
final class MeshNeighborLeft extends MeshNeighborEvent {
  const MeshNeighborLeft(super.nodeId);
}

/// A neighbor's connection state changed.
final class MeshNeighborLinkChanged extends MeshNeighborEvent {
  const MeshNeighborLinkChanged(super.nodeId, this.state);

  final MeshLinkState state;
}

/// Why the routing engine touched [destination]'s primary route.
enum MeshRouteChangeKind {
  /// A route was learned or improved.
  learned,

  /// The primary rotated (adaptive switch or demotion).
  switched,

  /// The route was dissolved because its next hop vanished.
  dissolved,

  /// A route expired.
  expired,
}

/// Route-table change event.
final class MeshRouteChangedEvent {
  const MeshRouteChangedEvent({
    required this.kind,
    required this.destination,
    this.route,
    this.reason,
  });

  final MeshRouteChangeKind kind;
  final String destination;

  /// The route involved (primary after the change), when applicable.
  final MeshRoute? route;

  final String? reason;
}

/// A relay decision was made for an ingested packet.
final class MeshRelayEvent {
  const MeshRelayEvent({
    required this.kind,
    required this.source,
    required this.destination,
    required this.sequence,
    required this.hopCount,
    required this.ttl,
    required this.at,
    this.nextHop,
    this.dropReason,
  });

  final MeshRelayEventKind kind;
  final String source;
  final String destination;
  final int sequence;
  final int hopCount;
  final int ttl;
  final DateTime at;
  final String? nextHop;
  final String? dropReason;
}

enum MeshRelayEventKind { forwarded, deliveredUp, dropped }

/// A topology graph changed.
final class MeshTopologyEvent {
  const MeshTopologyEvent({required this.changedAt});

  final DateTime changedAt;
}
