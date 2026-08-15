/// An immutable snapshot of the local topology.
///
/// The topology is always *local*: the local node, its live neighbors and
/// the links the engine can observe. [partitions] is the number of
/// connected components reachable from the local node (neighbor links plus
/// learned routes), a lightweight "am I split off?" indicator.
final class TopologySnapshot {
  const TopologySnapshot({
    required this.nodes,
    required this.links,
    required this.partitions,
    required this.observedAt,
  });

  final List<TopologyNode> nodes;
  final List<TopologyLink> links;

  /// Connected components from the local node's perspective.
  final int partitions;

  final DateTime? observedAt;

  static const TopologySnapshot empty = TopologySnapshot(
    nodes: [],
    links: [],
    partitions: 0,
    observedAt: null,
  );

  @override
  String toString() =>
      'TopologySnapshot(${nodes.length} nodes, '
      '${links.length} links, $partitions partitions)';
}

/// A node in the local topology view.
final class TopologyNode {
  const TopologyNode({
    required this.nodeId,
    required this.isLocal,
    this.rssiDb,
    this.hopCount,
  });

  final String nodeId;
  final bool isLocal;
  final int? rssiDb;
  final int? hopCount;
}

/// An observed link between two nodes in the local view.
final class TopologyLink {
  const TopologyLink({
    required this.nodeA,
    required this.nodeB,
    required this.quality,
  });

  final String nodeA;
  final String nodeB;

  /// Link quality 0..1.
  final double quality;
}
