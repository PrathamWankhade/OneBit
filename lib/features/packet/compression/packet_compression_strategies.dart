import 'package:onebit/features/packet/domain/packet_compressor.dart';

/// Policy that decides *whether* a payload is worth compressing.
///
/// The threshold rule: payloads at or under [threshold] bytes are never
/// compressed (spec `compressionThreshold`). The strategy itself is the
/// injected [PacketCompressor] — `none` by default, `future` codecs slot
/// in without a format change.
final class PacketCompressionPolicy {
  const PacketCompressionPolicy({
    this.compressor = const NoopCompressor(),
    this.threshold = 64,
  });

  /// The active compression strategy.
  final PacketCompressor compressor;

  /// Minimum payload length before compression is attempted.
  final int threshold;

  /// True when a non-trivial codec is installed.
  bool get enabled => compressor is! NoopCompressor;

  /// Compresses [payload] when beneficial, otherwise `null`.
  PacketCompressionResult? maybeCompress(List<int> payload) {
    if (payload.length <= threshold) return null;
    final result = compressor.compress(payload);
    if (result == null || result.bytes.length >= payload.length) return null;
    return result;
  }
}
