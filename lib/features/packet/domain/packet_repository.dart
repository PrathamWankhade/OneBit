import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';

/// What the packet layer hands to the mesh layer.
///
/// The mesh layer carries opaque bytes; the packet repository turns an
/// application message into serialized frames, sends each frame through
/// `MeshRepository.send`, and parses delivered payload bytes back into
/// [Packet]s.
abstract interface class PacketRepository {
  /// Sends [payload] to [destination] as one logical packet.
  ///
  /// The packet is built with [type]/[priority]/[ackRequested], serialized,
  /// fragmented if needed, and each frame is handed to the mesh layer.
  Future<Result<void>> send({
    required String destination,
    required List<int> payload,
    PacketType type = PacketType.message,
    PacketPriority priority = PacketPriority.normal,
    bool ackRequested = false,
    int ttl = 8,
  });

  /// Frames delivered to this node, parsed and reassembled.
  ///
  /// The stream is broadcast, `Result`-wrapped and never throws: wire
  /// errors surface as `Err` emissions so consumers degrade gracefully.
  Stream<Result<Packet>> observeDeliveredPackets();
}
