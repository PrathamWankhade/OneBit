import 'dart:convert';

import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/domain/packet_version.dart';
import 'package:onebit/features/packet/serialization/packet_byte_writer.dart';

/// The parsed fixed header plus the two variable node ids.
///
/// Node ids are decoded here so the serializer itself never repeats the
/// string plumbing.
final class WireHeaderResult {
  const WireHeaderResult({
    required this.header,
    required this.source,
    required this.destination,
  });

  final PacketHeader header;
  final String source;
  final String destination;
}

/// Layout-aware encoder/decoder for the fixed 28-byte header prefix.
///
/// The prefix ends *after* the two u16 length fields ([fixedSize] bytes);
/// the serializer appends the UTF-8 node-id bytes and the payload section.
/// Decoding reads exactly [fixedSize] bytes and bounds-checks each read.
abstract final class WireHeaderCodec {
  WireHeaderCodec._();

  /// Size of the fixed header prefix in bytes.
  static const int fixedSize = 28;

  /// Encodes the fixed prefix of [header].
  static List<int> encodeFixed(PacketHeader header) {
    final writer = PacketByteWriter();
    writer.writeByte((header.version.transport << 4) & 0xF0);
    writer.writeByte(header.version.major);
    writer.writeByte(header.version.revision);
    writer.writeByte(header.compatibilityFlags);
    writer.writeByte(header.type.code);
    writer.writeByte((header.priority.code << 6) & 0xFF);
    writer.writeByte(PacketFlag.toByte(header.flags));
    writer.writeByte(header.reservedFlags);
    writer.writeByte(header.ttl);
    writer.writeByte(header.hopCount);
    writer.writeUint32(header.sequence);
    writer.writeUint32(_epochSeconds(header.createdAt));
    writer.writeUint16(header.fragmentId);
    writer.writeUint16(header.fragmentIndex);
    writer.writeUint16(header.fragmentCount);
    writer.writeUint16(_utf8Length(header.source));
    writer.writeUint16(_utf8Length(header.destination));
    return writer.toBytes();
  }

  /// Reads the fixed prefix from [reader]; [source] and [destination] are
  /// decoded from the immediately following variable bytes.
  ///
  /// Throws [RangeError] on truncated input and [FormatException] on
  /// invalid UTF-8; the serializer converts both to a typed failure.
  static WireHeaderResult decodeFixed(PacketByteReader reader) {
    final byte0 = reader.readByte();
    final transport = byte0 >> 4;
    final major = reader.readByte();
    final revision = reader.readByte();
    final compatibility = reader.readByte();
    final typeCode = reader.readByte();
    final priorityByte = reader.readByte();
    final flagsByte = reader.readByte();
    final reservedFlags = reader.readByte();
    final ttl = reader.readByte();
    final hopCount = reader.readByte();
    final sequence = reader.readUint32();
    final createdAtSeconds = reader.readUint32();
    final fragmentId = reader.readUint16();
    final fragmentIndex = reader.readUint16();
    final fragmentCount = reader.readUint16();
    final sourceLength = reader.readUint16();
    final destinationLength = reader.readUint16();

    final version = PacketVersion(
      transport: transport,
      major: major,
      revision: revision,
    );
    final source = _readUtf8(reader, sourceLength);
    final destination = _readUtf8(reader, destinationLength);

    final header = PacketHeader(
      version: version,
      compatibilityFlags: compatibility,
      type: _requireType(typeCode),
      priority: _requirePriority(priorityByte >> 6),
      flags: PacketFlag.fromByte(flagsByte),
      reservedFlags: reservedFlags,
      ttl: ttl,
      hopCount: hopCount,
      sequence: sequence,
      source: source,
      destination: destination,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtSeconds * 1000,
        isUtc: true,
      ),
      fragmentId: fragmentId,
      fragmentIndex: fragmentIndex,
      fragmentCount: fragmentCount,
    );
    return WireHeaderResult(
      header: header,
      source: source,
      destination: destination,
    );
  }

  static PacketType _requireType(int code) {
    final type = PacketType.fromCode(code);
    if (type == null) {
      throw FormatException('unknown packet type code $code');
    }
    return type;
  }

  static PacketPriority _requirePriority(int code) {
    final priority = PacketPriority.fromCode(code);
    if (priority == null) {
      throw FormatException('unknown priority code $code');
    }
    return priority;
  }

  static int _utf8Length(String value) => utf8.encode(value).length;

  static String _readUtf8(PacketByteReader reader, int length) {
    final bytes = reader.readBytes(length);
    return utf8.decode(bytes);
  }

  static int _epochSeconds(DateTime createdAt) {
    final millis = createdAt.millisecondsSinceEpoch;
    return (millis ~/ 1000) & 0xFFFFFFFF;
  }
}
