import 'packet.dart';
import 'packet_id.dart';

/// Result of feeding one fragment (or complete packet) into reassembly.
sealed class ReassemblyOutcome {
  const ReassemblyOutcome();
}

/// The run is still incomplete; the fragment was buffered.
final class ReassemblyWaiting extends ReassemblyOutcome {
  const ReassemblyWaiting({
    required this.fragmentsPresent,
    required this.fragmentCount,
  });

  final int fragmentsPresent;
  final int fragmentCount;
}

/// The run completed: [packet] is the reassembled logical packet.
final class ReassemblyComplete extends ReassemblyOutcome {
  const ReassemblyComplete(this.packet);

  final Packet packet;
}

/// The run was abandoned: [fragmentsPresent] of [fragmentCount] arrived but
/// the session expired (or a limit forced eviction).
final class ReassemblyExpired extends ReassemblyOutcome {
  const ReassemblyExpired({
    required this.packetId,
    required this.fragmentsPresent,
    required this.fragmentCount,
  });

  final PacketId packetId;
  final int fragmentsPresent;
  final int fragmentCount;
}
