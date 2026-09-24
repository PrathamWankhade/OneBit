/// I9.2 — Unique logical identifier for a OneBit message.
///
/// A [MessageId] is immutable and persists for the entire message
/// lifecycle — from creation through delivery (or failure). It is
/// independent of BLE addresses, session IDs, route IDs, or any
/// transport-specific identifier.
///
/// ## Representation
///
/// Internally stored as 16 raw bytes (UUID v4). Provides both
/// compact binary serialization and human-readable string form.
///
/// ## Identity Properties
///
/// - Universally unique (UUID v4)
/// - Immutable after creation
/// - Serializable / deserializable (binary and string)
/// - Comparable and hashable (safe for Set/Map keys)
/// - Stable across route changes and relay hops
library;

import 'dart:math';
import 'dart:typed_data';

/// Canonical size of a serialized [MessageId] in bytes.
const int messageIdByteSize = 16;

/// A unique logical identifier for a OneBit message.
///
/// Internally stores 16 raw UUID v4 bytes. Immutable and
/// value-equality based. Safe for use as Set/Map keys.
class MessageId {
  /// Create a new random [MessageId].
  ///
  /// Generates a UUID v4 internally using [Random.secure].
  MessageId() : _bytes = _generateRandomBytes();

  /// Create a [MessageId] from a UUID string.
  ///
  /// Throws [ArgumentError] if [value] is not a valid UUID v4 format.
  MessageId.fromString(String value) : _bytes = _parseUuidString(value);

  /// Create a [MessageId] from 16 raw bytes.
  ///
  /// Throws [ArgumentError] if [bytes] is not exactly 16 bytes or
  /// does not have valid version (4) and variant (10xx) bits.
  MessageId.fromBytes(Uint8List bytes) : _bytes = _validateBytes(bytes);

  /// Internal 16-byte representation.
  final Uint8List _bytes;

  /// The raw UUID bytes (16 bytes, immutable copy).
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  /// The UUID string value (hex with dashes).
  ///
  /// This is the canonical string representation used as map keys
  /// and in debug output.
  String get value => toHexString();

  /// The UUID string representation (e.g. `550e8400-e29b-41d4-a716-446655440000`).
  String toHexString() {
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    return '${hex(_bytes[0])}${hex(_bytes[1])}${hex(_bytes[2])}${hex(_bytes[3])}-'
        '${hex(_bytes[4])}${hex(_bytes[5])}-'
        '${hex(_bytes[6])}${hex(_bytes[7])}-'
        '${hex(_bytes[8])}${hex(_bytes[9])}-'
        '${hex(_bytes[10])}${hex(_bytes[11])}${hex(_bytes[12])}'
        '${hex(_bytes[13])}${hex(_bytes[14])}${hex(_bytes[15])}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageId &&
          runtimeType == other.runtimeType &&
          _bytes.length == other._bytes.length &&
          _bytes.every((b) => b == other._bytes[_bytes.indexOf(b)]);

  @override
  int get hashCode {
    var hash = 0;
    for (var i = 0; i < _bytes.length; i++) {
      hash = (hash * 31 + _bytes[i]) & 0x7FFFFFFF;
    }
    return hash;
  }

  @override
  String toString() => 'MessageId(${toHexString().substring(0, 8)}...)';
}

/// Generate 16 random bytes with UUID v4 version and variant bits.
Uint8List _generateRandomBytes() {
  final random = Random.secure();
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = random.nextInt(266);
  }
  // Set version (4) and variant (10xx) bits.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  return bytes;
}

/// Parse a UUID string into 16 bytes.
Uint8List _parseUuidString(String value) {
  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  if (!uuidRegex.hasMatch(value)) {
    throw ArgumentError('Invalid UUID v4 format: $value');
  }
  final hex = value.replaceAll('-', '');
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Validate that [bytes] is exactly 16 bytes with valid UUID v4 bits.
Uint8List _validateBytes(Uint8List bytes) {
  if (bytes.length != messageIdByteSize) {
    throw ArgumentError(
      'MessageId bytes must be exactly $messageIdByteSize bytes, '
      'got ${bytes.length}',
    );
  }
  // Check version bits (byte 6, high nibble must be 4).
  if ((bytes[6] & 0xF0) != 0x40) {
    throw ArgumentError(
      'Invalid UUID version: expected 4, got ${(bytes[6] >> 4) & 0x0F}',
    );
  }
  // Check variant bits (byte 8, high 2 bits must be 10).
  if ((bytes[8] & 0xC0) != 0x80) {
    throw ArgumentError('Invalid UUID variant bits');
  }
  return Uint8List.fromList(bytes);
}
