import 'package:onebit/features/packet/domain/packet_payload.dart';

/// Maps [PacketPayloadType] to/from its single wire byte.
///
/// The type byte sits between the node ids and the payload length so a
/// receiver can always tell how to interpret the payload that follows.
abstract final class PayloadCodec {
  PayloadCodec._();

  /// Resolves a wire code into a [PacketPayloadType].
  static PacketPayloadType? fromCode(int code) =>
      PacketPayloadType.fromCode(code);

  /// The wire code of [type].
  static int codeOf(PacketPayloadType type) => type.code;
}
