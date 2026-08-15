import 'dart:convert';

/// Declared representation of a payload.
///
/// The type is a wire byte (see `payload_codec`) so a receiver knows how to
/// interpret bytes without guessing. [compressed] describes the *current*
/// representation (it pairs with the `compressed` flag); [encrypted] and
/// [attachmentMetadata] are profiles reserved for later phases.
enum PacketPayloadType {
  /// Opaque bytes; no interpretation implied.
  binary(0),

  /// UTF-8 text.
  utf8(1),

  /// UTF-8 JSON document.
  json(2),

  /// Ciphertext; framing only, never interpreted.
  encrypted(3),

  /// Compressed bytes (matching the `compressed` flag).
  compressed(4),

  /// Metadata pointing at an attachment (future media phase).
  attachmentMetadata(5);

  const PacketPayloadType(this.code);

  /// The on-wire byte value.
  final int code;

  /// Resolves [code], or `null` when unknown.
  static PacketPayloadType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Immutable payload bytes plus their declared [type].
final class PacketPayload {
  const PacketPayload({
    required this.type,
    required this.bytes,
    this.uncompressedSize,
  });

  /// UTF-8 payload convenience constructor.
  factory PacketPayload.utf8(String text) =>
      PacketPayload(type: PacketPayloadType.utf8, bytes: utf8.encode(text));

  /// JSON payload convenience constructor.
  factory PacketPayload.json(String json) =>
      PacketPayload(type: PacketPayloadType.json, bytes: utf8.encode(json));

  /// Opaque binary payload convenience constructor.
  factory PacketPayload.binary(List<int> bytes) =>
      PacketPayload(type: PacketPayloadType.binary, bytes: bytes);

  final PacketPayloadType type;

  /// The bytes themselves; unmodifiable.
  final List<int> bytes;

  /// Original size before compression, present when [type] is compressed.
  final int? uncompressedSize;

  /// The UTF-8 text, valid when [type] is [PacketPayloadType.utf8] or
  /// [PacketPayloadType.json].
  String? get utf8Text {
    if (type == PacketPayloadType.utf8 || type == PacketPayloadType.json) {
      try {
        return utf8.decode(bytes);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// A copy with different bytes (used by the compression pipeline).
  PacketPayload withBytes(List<int> newBytes, {PacketPayloadType? newType}) {
    return PacketPayload(
      type: newType ?? type,
      bytes: newBytes,
      uncompressedSize: uncompressedSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! PacketPayload || other.type != type) return false;
    final a = other.bytes;
    final b = bytes;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return other.uncompressedSize == uncompressedSize;
  }

  @override
  int get hashCode =>
      Object.hash(type, Object.hashAll(bytes), uncompressedSize);

  @override
  String toString() => 'PacketPayload($type, ${bytes.length} bytes)';
}
