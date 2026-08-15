import 'dart:typed_data';

import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// Minimal on-air framing for [MeshPacket].
///
/// This is the transport seam between the mesh engine and the Bluetooth
/// characteristic bytes. The packet-protocol phase may replace it with a
/// richer codec; the layout stays internal to the mesh data layer.
///
/// Layout (big-endian):
/// ```
/// byte 0   : version (4 bits) | kind (4 bits)
/// byte 1   : ttl
/// byte 2   : hopCount
/// bytes 3-6: sequence (u32)
/// src      : u16 len + UTF-8
/// dst      : u16 len + UTF-8
/// path     : u8 count, then u16 len + UTF-8 per hop
/// data     : u16 payloadLen + payload bytes
/// control  : u8 controlType + u16 len + UTF-8 target
/// ```
final class MeshPacketCodec {
  const MeshPacketCodec({this.version = 0});

  static const int _kindData = 0;
  static const int _kindDiscoveryRequest = 1;
  static const int _kindDiscoveryReply = 2;

  final int version;

  /// Encodes [packet] into bytes.
  List<int> encode(MeshPacket packet) {
    final writer = _BytesWriter();
    writer.writeByte((version << 4) | _kindOf(packet));
    writer.writeByte(packet.ttl);
    writer.writeByte(packet.hopCount);
    writer.writeUint32(packet.sequence);
    writer.writeString(packet.source);
    writer.writeString(packet.destination);
    writer.writeByte(packet.path.length);
    for (final hop in packet.path) {
      writer.writeString(hop);
    }
    final control = packet.control;
    if (control == null) {
      writer.writeUint16(packet.payload.length);
      writer.writeBytes(packet.payload);
    } else {
      final target = switch (control) {
        RouteDiscoveryRequest(:final target) => target,
        RouteDiscoveryReply(:final target) => target,
      };
      writer.writeByte(_controlTypeOf(control));
      writer.writeString(target);
    }
    return writer.bytes;
  }

  /// Decodes [bytes] into a packet, or `null` when malformed.
  MeshPacket? decode(List<int> bytes) {
    try {
      final reader = _BytesReader(bytes);
      final header = reader.readByte();
      final wireVersion = header >> 4;
      final kind = header & 0x0F;
      if (wireVersion != version || kind > _kindDiscoveryReply) return null;
      final ttl = reader.readByte();
      final hopCount = reader.readByte();
      final sequence = reader.readUint32();
      final source = reader.readString();
      final destination = reader.readString();
      final pathLength = reader.readByte();
      final path = <String>[];
      for (var i = 0; i < pathLength; i++) {
        path.add(reader.readString());
      }
      MeshPacket packet;
      switch (kind) {
        case _kindData:
          final payloadLength = reader.readUint16();
          final payload = List<int>.unmodifiable(
            reader.readBytes(payloadLength),
          );
          packet = MeshPacket(
            source: source,
            destination: destination,
            kind: MeshPacketKind.data,
            payload: payload,
            ttl: ttl,
            hopCount: hopCount,
            path: path,
            sequence: sequence,
          );
        case _kindDiscoveryRequest:
          if (reader.readByte() != _kindDiscoveryRequest) return null;
          final target = reader.readString();
          packet = MeshPacket(
            source: source,
            destination: destination,
            kind: MeshPacketKind.control,
            control: RouteDiscoveryRequest(target),
            ttl: ttl,
            hopCount: hopCount,
            path: path,
            sequence: sequence,
          );
        case _kindDiscoveryReply:
          if (reader.readByte() != _kindDiscoveryReply) return null;
          final target = reader.readString();
          packet = MeshPacket(
            source: source,
            destination: destination,
            kind: MeshPacketKind.control,
            control: RouteDiscoveryReply(target, path),
            ttl: ttl,
            hopCount: hopCount,
            path: path,
            sequence: sequence,
          );
        default:
          return null;
      }
      if (!reader.exhausted) return null;
      return packet;
    } on RangeError {
      return null;
    } on _MalformedException {
      return null;
    }
  }

  int _kindOf(MeshPacket packet) {
    if (packet.kind == MeshPacketKind.data) return _kindData;
    return switch (packet.control!) {
      RouteDiscoveryRequest() => _kindDiscoveryRequest,
      RouteDiscoveryReply() => _kindDiscoveryReply,
    };
  }

  int _controlTypeOf(MeshControl control) {
    return switch (control) {
      RouteDiscoveryRequest() => _kindDiscoveryRequest,
      RouteDiscoveryReply() => _kindDiscoveryReply,
    };
  }
}

class _MalformedException implements Exception {
  const _MalformedException();
}

final class _BytesWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  List<int> get bytes => _builder.toBytes();

  void writeByte(int value) {
    _builder.addByte(value & 0xFF);
  }

  void writeUint16(int value) {
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte(value & 0xFF);
  }

  void writeUint32(int value) {
    _builder.addByte((value >> 24) & 0xFF);
    _builder.addByte((value >> 16) & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte(value & 0xFF);
  }

  void writeString(String value) {
    final encoded = value.codeUnits;
    writeUint16(encoded.length);
    for (final unit in encoded) {
      writeUint16(unit);
    }
  }

  void writeBytes(List<int> value) {
    _builder.add(value);
  }
}

final class _BytesReader {
  _BytesReader(List<int> bytes) : _bytes = bytes;

  final List<int> _bytes;
  int _offset = 0;

  bool get exhausted => _offset >= _bytes.length;

  int readByte() {
    if (_offset >= _bytes.length) throw const _MalformedException();
    return _bytes[_offset++];
  }

  int readUint16() {
    final high = readByte();
    final low = readByte();
    return (high << 8) | low;
  }

  int readUint32() {
    final a = readByte();
    final b = readByte();
    final c = readByte();
    final d = readByte();
    return (a << 24) | (b << 16) | (c << 8) | d;
  }

  String readString() {
    final length = readUint16();
    if (_offset + length * 2 > _bytes.length) {
      throw const _MalformedException();
    }
    final units = <int>[];
    for (var i = 0; i < length; i++) {
      units.add(readUint16());
    }
    return String.fromCharCodes(units);
  }

  List<int> readBytes(int length) {
    if (_offset + length > _bytes.length) {
      throw const _MalformedException();
    }
    final chunk = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return chunk;
  }
}
