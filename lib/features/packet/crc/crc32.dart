import 'dart:typed_data';

/// CRC-32/IEEE with polynomial lookup tables.
///
/// Matches the common `crc32()` used by archive formats: reflected
/// polynomial `0xEDB88320`, initial value `0xFFFFFFFF`, final XOR
/// `0xFFFFFFFF`. A single function, no mutable state — safe to share.
abstract final class Crc32 {
  Crc32._();

  static final Uint32List _table = _buildTable();

  static Uint32List _buildTable() {
    const polynomial = 0xEDB88320;
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var value = i;
      for (var bit = 0; bit < 8; bit++) {
        value = (value & 1) != 0 ? (value >> 1) ^ polynomial : value >> 1;
      }
      table[i] = value;
    }
    return table;
  }

  /// Computes the CRC-32/IEEE checksum of [bytes].
  static int compute(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = (crc >> 8) ^ _table[(crc ^ byte) & 0xFF];
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
