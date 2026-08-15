import 'dart:convert';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/crc/crc32.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/header/wire_header_codec.dart';
import 'package:onebit/features/packet/payload/payload_codec.dart';
import 'package:onebit/features/packet/serialization/packet_byte_writer.dart';

/// Whole-frame encoder/decoder for the packet protocol.
///
/// The frame is `fixedHeader + source + destination + payloadType +
/// payloadLength + payload + signatureLength + signature + crc32` (see
/// `docs/packet/04-binary-format.md`). Both directions are strict:
/// malformed bytes resolve to a typed `Err`, never a partial object.
final class PacketSerializer {
  const PacketSerializer({this.maxPayloadLength = 65536});

  /// Upper bound for `payloadLength` on the wire (rule `payloadLengthBounds`).
  final int maxPayloadLength;

  /// Serializes [packet] into a complete frame, CRC included.
  ///
  /// Returns `Err(PacketValidationFailure)` when a header field cannot be
  /// encoded (e.g. node id longer than 65535 bytes).
  Result<List<int>> encode(Packet packet) {
    try {
      return Ok(_encodeBytes(packet, includeSignature: true, includeCrc: true));
    } on RangeError {
      return Err(_validationFailure('encode.range'));
    } on ArgumentError catch (error) {
      return Err(
        PacketValidationFailure(
          rule: 'headerField',
          message: error.toString(),
          cause: error,
        ),
      );
    }
  }

  /// The canonical bytes a signer must bind (header through payload; no
  /// signature length, signature or CRC).
  ///
  /// Deterministic per packet: the same packet always produces the same
  /// canonical bytes, so signatures are stable across relays.
  Result<List<int>> canonicalBytes(Packet packet) {
    try {
      return Ok(
        _encodeBytes(packet, includeSignature: false, includeCrc: false),
      );
    } on ArgumentError catch (error) {
      return Err(
        PacketValidationFailure(
          rule: 'headerField',
          message: error.toString(),
          cause: error,
        ),
      );
    }
  }

  /// Decodes a complete frame back into a [Packet].
  ///
  /// Structural checks run here (CRC, lengths, trailing bytes); semantic
  /// rules are the `PacketValidator`'s job.
  Result<Packet> decode(List<int> bytes) {
    try {
      final reader = PacketByteReader(bytes);
      final wire = WireHeaderCodec.decodeFixed(reader);

      final payloadTypeCode = reader.readByte();
      final payloadType = PayloadCodec.fromCode(payloadTypeCode);
      if (payloadType == null) {
        return Err(_validationFailure('payloadTypeKnown'));
      }
      final payloadLength = reader.readUint32();
      if (payloadLength > maxPayloadLength) {
        return Err(_validationFailure('payloadLengthBounds'));
      }
      if (!reader.hasBytes(payloadLength)) {
        return Err(_validationFailure('payloadLengthTruncated'));
      }
      final payloadBytes = reader.readBytes(payloadLength);

      final signatureLength = reader.readUint16();
      if (!reader.hasBytes(signatureLength + 4)) {
        return Err(_validationFailure('signatureTruncated'));
      }
      final signature = reader.readBytes(signatureLength);
      final carriedCrc = reader.readUint32();
      if (!reader.isExhausted) {
        return Err(_validationFailure('headerTrailingByte'));
      }

      final computedCrc = Crc32.compute(bytes.sublist(0, bytes.length - 4));
      if (computedCrc != carriedCrc) {
        return Err(_validationFailure('crc32Valid'));
      }

      final payload = PacketPayload(
        type: payloadType,
        bytes: List<int>.unmodifiable(payloadBytes),
      );
      return Ok(
        Packet(header: wire.header, payload: payload, signature: signature),
      );
    } on RangeError {
      return Err(_validationFailure('malformed'));
    } on FormatException {
      return Err(_validationFailure('malformed'));
    }
  }

  /// Length of the fixed part of a frame (header + ids + section).
  int fixedOverhead({required int sourceBytes, required int destinationBytes}) {
    return WireHeaderCodec.fixedSize +
        sourceBytes +
        destinationBytes +
        1 +
        4 +
        2 +
        4;
  }

  List<int> _encodeBytes(
    Packet packet, {
    required bool includeSignature,
    required bool includeCrc,
  }) {
    final writer = PacketByteWriter();
    writer.writeBytes(WireHeaderCodec.encodeFixed(packet.header));
    writer.writeBytes(utf8.encode(packet.header.source));
    writer.writeBytes(utf8.encode(packet.header.destination));
    writer.writeByte(PayloadCodec.codeOf(packet.payload.type));
    writer.writeUint32(packet.payload.bytes.length);
    writer.writeBytes(packet.payload.bytes);
    if (includeSignature) {
      writer.writeUint16(packet.signature.length);
      writer.writeBytes(packet.signature);
    }
    final bytes = writer.toBytes();
    if (includeCrc) {
      final builder = PacketByteWriter();
      builder.writeBytes(bytes);
      builder.writeUint32(Crc32.compute(bytes));
      return builder.toBytes();
    }
    return bytes;
  }

  PacketValidationFailure _validationFailure(String rule) {
    return PacketValidationFailure(
      rule: rule,
      message: 'malformed packet frame ($rule)',
    );
  }
}
