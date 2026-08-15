import 'dart:math';
import 'dart:typed_data';

/// Entropy helpers backed exclusively by `Random.secure()`.
///
/// OneBit never uses `Random()` (predictable) anywhere near identity
/// material. All identity seeds, salts and UUIDs originate here.
abstract final class SecureRandomUtil {
  /// Cryptographically secure random source for the whole process.
  static final Random _random = Random.secure();

  /// Returns [length] bytes of secure random data.
  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generates a version-4 (random) UUID per RFC 4122, lowercase.
  ///
  /// Example: `f2f4a8c0-9b5e-4a3d-8c1a-2e6b0d5a7f90`.
  static String uuidV4() {
    final bytes = randomBytes(16);
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // RFC 4122 variant
    final hex = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        hex.write('-');
      }
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }
}
