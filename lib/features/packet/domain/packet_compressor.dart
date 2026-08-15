/// Outcome of a [PacketCompressor.compress] call.
///
/// `null` from [PacketCompressor.compress] means "do not compress" — the
/// caller keeps the payload as-is and clears the `compressed` flag.
final class PacketCompressionResult {
  const PacketCompressionResult({
    required this.bytes,
    required this.originalSize,
  });

  /// The compressed bytes.
  final List<int> bytes;

  /// Original byte count, so the decompressor can pre-allocate.
  final int originalSize;
}

/// Strategy boundary for payload compression.
///
/// Compression is an injectable transformer between the packet payload and
/// the wire bytes. `compressed` flags are set only when a compressor
/// actually produced shorter bytes.
abstract interface class PacketCompressor {
  /// Compresses [payload], or returns `null` to keep the payload as-is.
  PacketCompressionResult? compress(List<int> payload);

  /// Reverses a compression produced by [compress]. Throwing is allowed
  /// here only for structurally corrupt inputs; the engine converts the
  /// throw into a typed failure.
  List<int> decompress(List<int> data, {required int originalSize});
}

/// The default strategy: never compresses, never decompresses.
///
/// Ships with the phase so the whole pipeline is testable without a codec;
/// a real codec (e.g. zlib) slots in later without a format change.
final class NoopCompressor implements PacketCompressor {
  const NoopCompressor();

  @override
  PacketCompressionResult? compress(List<int> payload) => null;

  @override
  List<int> decompress(List<int> data, {required int originalSize}) => data;
}
