import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// TTL bookkeeping: every forward decrements, zero kills the packet.
///
/// TTL bounds flood diameter (route discovery) and guarantees that no
/// packet can relay forever, independently of loop prevention.
final class TTLManager {
  const TTLManager({this.defaultTtl = 8});

  /// TTL applied to locally-originated packets.
  final int defaultTtl;

  /// True when [packet] has no life left and must be dropped.
  bool isExpired(MeshPacket packet) => packet.ttl <= 0;

  /// The decremented copy, or `null` when the packet would reach zero.
  MeshPacket? next(MeshPacket packet) => packet.decrementTtl();
}
