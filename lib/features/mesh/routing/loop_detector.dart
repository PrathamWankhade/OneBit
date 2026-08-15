import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// Pure path-validation helpers that keep forwarding a DAG.
///
/// The rule set: a packet must never re-enter a node already on its path,
/// and no forward may aim at a node already on the path (or the source).
/// Combined with duplicate detection this gives loop-free forwarding and
/// bounded floods.
final class LoopDetector {
  const LoopDetector();

  /// True when [nodeId] already contributed a relay in [packet.path]
  /// — forwarding [packet] through [nodeId] again would re-enter a loop.
  bool wouldReenter(MeshPacket packet, String nodeId) =>
      packet.path.contains(nodeId);

  /// True when routing toward [nextHop] would bounce the packet back into
  /// its own trail (a loop).
  bool wouldCreateLoop(MeshPacket packet, String nextHop) =>
      nextHop == packet.source || packet.path.contains(nextHop);

  /// Whether the traversal emitted so far is valid (no duplicated node).
  bool pathIsValid(MeshPacket packet) =>
      packet.path.toSet().length == packet.path.length;
}
