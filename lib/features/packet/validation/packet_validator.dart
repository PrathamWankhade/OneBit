import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';

/// Semantic rule checks over a decoded packet.
///
/// Structural sanity (CRC, lengths, trailing bytes, version transport) is
/// the serializer's job; these rules cover *meaning* per the protocol spec
/// (rules 4, 6, 8–10, 12). Each rule failure resolves to
/// `PacketValidationFailure` carrying the rule id.
final class PacketValidator {
  const PacketValidator({this.maxFragments = 256});

  /// Upper bound for `fragmentCount` on a frame (rule `fragmentCountAllowed`).
  final int maxFragments;

  /// Returns [packet] when every rule passes, otherwise the failing rule.
  Result<Packet> validate(Packet packet) {
    final header = packet.header;

    final isBroadcast = header.isBroadcast;
    final broadcastFlag = header.flags.contains(PacketFlag.broadcastFlag);
    if (header.type == PacketType.broadcast) {
      if (!isBroadcast || !broadcastFlag) {
        return _fail('flagsConsistent');
      }
    } else if (broadcastFlag) {
      return _fail('flagsConsistent');
    }

    final isFragmented = header.flags.contains(PacketFlag.fragmented);
    if (!isFragmented && header.fragmentCount != 1) {
      return _fail('fragmentIndexCovered');
    }
    if (header.fragmentCount > maxFragments) {
      return _fail('fragmentCountAllowed');
    }

    if (packet.payload.type == PacketPayloadType.encrypted &&
        !header.flags.contains(PacketFlag.encrypted)) {
      return _fail('flagsConsistent');
    }
    if (header.flags.contains(PacketFlag.encrypted) &&
        packet.payload.type != PacketPayloadType.encrypted) {
      return _fail('flagsConsistent');
    }
    if (header.flags.contains(PacketFlag.compressed) &&
        !isFragmented &&
        packet.payload.type != PacketPayloadType.compressed) {
      return _fail('flagsConsistent');
    }

    if (packet.signature.isNotEmpty &&
        header.isFragmented &&
        header.fragmentIndex != 0) {
      return _fail('signaturePresent');
    }

    return Ok(packet);
  }

  Err<Packet> _fail(String rule) {
    return Err(
      PacketValidationFailure(
        rule: rule,
        message: 'packet failed validation rule $rule',
      ),
    );
  }
}
