import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/nodes/domain/mesh_node.dart';

/// Repository contract for the node registry.
///
/// The registry persists known nodes locally (Drift) and accretes entries
/// from nearby-peer observations. Phase 1 declares the shape only.
abstract interface class NodeRegistryRepository {
  /// Emits the known nodes, from oldest to newest.
  Stream<Result<List<MeshNode>>> watchNodes();

  /// Marks [node] as seen, updating its `lastSeen` (upsert).
  Future<Result<void>> upsert(MeshNode node);

  /// Forgets [nodeId].
  Future<Result<void>> forgetNode(String nodeId);
}
