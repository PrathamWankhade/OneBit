import 'dart:io';

import 'package:onebit/features/packet/domain/packet_compressor.dart';

/// The `fast` compression strategy of the protocol spec.
///
/// A single-pass deflate at a fixed level tuned for phone-size payloads: it
/// wins on repetitive text and fails fast (`null`) when deflate would not
/// shrink the payload, so the engine never pays for a bigger frame. The
/// stream is zlib-wrapped (RFC 1950) so any decoder can reverse it when the
/// `compressed` flag is set.
final class ZlibFastCompressor implements PacketCompressor {
  ZlibFastCompressor({this.level = 4}) : _codec = ZLibCodec(level: level);

  /// Deflate compression level (0..9). Level 4 balances speed and ratio for
  /// BLE-sized payloads on mobile CPUs.
  final int level;

  final ZLibCodec _codec;

  @override
  PacketCompressionResult? compress(List<int> payload) {
    final compressed = _codec.encode(payload);
    if (compressed.length >= payload.length) return null;
    return PacketCompressionResult(
      bytes: compressed,
      originalSize: payload.length,
    );
  }

  @override
  List<int> decompress(List<int> data, {required int originalSize}) {
    return _codec.decode(data);
  }
}
