import 'dart:typed_data';

/// Dense big-endian writer used by the packet codec.
///
/// All multi-byte integers serialize big-endian per the binary format
/// (`docs/packet/04-binary-format.md`). The writer is intentionally tiny
/// and allocation-light; it is owned by the serializer, never exported.
final class PacketByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

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

  void writeBytes(List<int> value) {
    _builder.add(value);
  }

  List<int> toBytes() => _builder.toBytes();
}

/// Big-endian reader with bounds checks before every read.
///
/// Reads throw [RangeError] when the buffer runs out; the serializer
/// converts that into a typed `PacketValidationFailure` so no raw error
/// escapes the feature boundary.
final class PacketByteReader {
  PacketByteReader(List<int> bytes) : _bytes = bytes, _offset = 0;

  final List<int> _bytes;
  int _offset;

  /// Bytes left to read.
  int get remaining => _bytes.length - _offset;

  /// True when everything has been consumed.
  bool get isExhausted => remaining == 0;

  bool hasBytes(int count) => remaining >= count;

  int readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError.range(_offset, 0, _bytes.length);
    }
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

  List<int> readBytes(int count) {
    if (_offset + count > _bytes.length) {
      throw RangeError.range(count, 0, _bytes.length - _offset, 'count');
    }
    final chunk = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return chunk;
  }
}
