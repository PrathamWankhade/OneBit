import 'package:flutter/foundation.dart';

/// A node in the local registry (peers we know about).
///
/// Pure domain value; persistence and BLE advertisement mapping arrive in
/// later phases.
@immutable
final class MeshNode {
  const MeshNode({
    required this.nodeId,
    required this.alias,
    required this.lastSeen,
  });

  /// Stable identifier of the node (future: derived identity hash).
  final String nodeId;

  /// Optional human-assigned alias.
  final String? alias;

  /// When this node was last seen in range.
  final DateTime lastSeen;

  @override
  bool operator ==(Object other) => other is MeshNode && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}
