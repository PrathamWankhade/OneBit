/// What a [MeshPacket] carries.
enum MeshPacketKind {
  /// Opaque bytes for a higher layer (messaging, etc.). The engine never
  /// inspects the payload; serialization lands with the packet-protocol codec.
  data,

  /// A routing/control message understood by the engine itself.
  control,
}

/// Discriminator for [MeshControl] carriers.
enum MeshControlType {
  /// Asks the mesh to discover a route to [RouteDiscoveryRequest.target].
  routeDiscoveryRequest,

  /// Answers a discovery request with the reverse path to the target.
  routeDiscoveryReply,
}

/// Control-plane metadata carried by a control [MeshPacket].
sealed class MeshControl {
  const MeshControl(this.type);

  final MeshControlType type;
}

/// Broadcast request: "whoever can reach [target], please answer".
final class RouteDiscoveryRequest extends MeshControl {
  const RouteDiscoveryRequest(this.target)
    : super(MeshControlType.routeDiscoveryRequest);

  final String target;
}

/// Unicast answer along the reverse path, carrying the observed [path].
final class RouteDiscoveryReply extends MeshControl {
  const RouteDiscoveryReply(this.target, this.path)
    : super(MeshControlType.routeDiscoveryReply);

  final String target;
  final List<String> path;
}

/// An immutable packet traversing the mesh.
///
/// The header carries everything the routing/relay engines need: a unique
/// per-source sequence id, source/destination, TTL, hop count, the precise
/// traversal [path] (used for loop prevention and reverse-route learning),
/// and an opaque [payload] for higher layers. Packet *serialization* is a
/// later phase; the engine only ever handles this value object.
final class MeshPacket {
  MeshPacket({
    required this.source,
    required this.destination,
    required this.kind,
    required this.ttl,
    required this.sequence,
    this.control,
    List<int> payload = const [],
    this.hopCount = 0,
    List<String> path = const [],
    DateTime? createdAt,
  }) : payload = List.unmodifiable(payload),
       path = List.unmodifiable(path),
       createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Source node id.
  final String source;

  /// Destination node id, or empty for a broadcast.
  final String destination;

  /// Data vs control plane.
  final MeshPacketKind kind;

  /// Present only for control packets.
  final MeshControl? control;

  /// Opaque bytes; not interpreted by this phase.
  final List<int> payload;

  /// Remaining relay hops; reaching zero kills the packet.
  final int ttl;

  /// Number of relays applied so far.
  final int hopCount;

  /// Node ids this packet has traversed, in order. Prevents loops and
  /// teaches reverse routes.
  final List<String> path;

  /// Source-local monotonic sequence number.
  final int sequence;

  /// When the packet was created (origin clock of the source; informational).
  final DateTime createdAt;

  /// True when this packet targets every node (`destination` empty).
  bool get isBroadcast => destination.isEmpty;

  /// Globally distinguishing id used by duplicate detection.
  String get packetId => '$source:$sequence';

  /// A copy with TTL decremented and, when TTL reaches zero, `null` result
  /// — callers drop the packet.
  MeshPacket? decrementTtl() {
    if (ttl <= 0) return null;
    return _copy(ttl: ttl - 1);
  }

  /// A copy as relayed by [nodeId]: hop count grows and the node joins the
  /// path (skipped when it already closed the path, e.g. the origin).
  MeshPacket relayedBy(String nodeId) {
    return _copy(
      hopCount: hopCount + 1,
      path: path.isNotEmpty && path.last == nodeId ? path : [...path, nodeId],
    );
  }

  MeshPacket _copy({int? ttl, int? hopCount, List<String>? path}) {
    return MeshPacket(
      source: source,
      destination: destination,
      kind: kind,
      control: control,
      payload: payload,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      path: path ?? this.path,
      sequence: sequence,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeshPacket && other.packetId == packetId;

  @override
  int get hashCode => packetId.hashCode;

  @override
  String toString() =>
      'MeshPacket($packetId → $destination, ttl $ttl, '
      'hops $hopCount, path $path)';
}
