import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';

/// Stateless puzzle: joins a complete fragmented run back into one logical
/// packet.
///
/// Merging uses fragment 0's header (cleared of the fragmented flag) and
/// signature; fragment 0 is the only fragment that carries the parent
/// signature on the wire.
final class PacketReassembler {
  const PacketReassembler();

  /// Produces the reassembled packet from [firstFragment] (the index-0
  /// fragment) and the ordered [fullPayload].
  Packet reassemble(Packet firstFragment, List<int> fullPayload) {
    final header = firstFragment.header.copyWith(
      flags: _withoutFragmentFlag(firstFragment.header.flags),
      fragmentIndex: 0,
      fragmentCount: 1,
    );
    return Packet(
      header: header,
      payload: firstFragment.payload.withBytes(fullPayload),
      signature: firstFragment.signature,
    );
  }

  Set<PacketFlag> _withoutFragmentFlag(Set<PacketFlag> flags) {
    return flags.where((flag) => flag != PacketFlag.fragmented).toSet();
  }
}
