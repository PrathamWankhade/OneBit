import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/features/packet/domain/packet.dart';

/// Outcome of decoding one wire frame.
sealed class PacketDecodeOutcome {
  const PacketDecodeOutcome();
}

/// The frame was a complete packet (or a run that just completed) and
/// [packet] is ready for delivery.
final class PacketDelivered extends PacketDecodeOutcome {
  const PacketDelivered(this.packet);

  final Packet packet;
}

/// The frame was accepted as a fragment; [fragmentsPresent] of
/// [fragmentCount] are buffered so far.
final class PacketFragmentBuffered extends PacketDecodeOutcome {
  const PacketFragmentBuffered({
    required this.fragmentsPresent,
    required this.fragmentCount,
  });

  final int fragmentsPresent;
  final int fragmentCount;
}

/// The frame was rejected with a typed [failure].
final class PacketRejected extends PacketDecodeOutcome {
  const PacketRejected(this.failure);

  final Failure failure;
}
