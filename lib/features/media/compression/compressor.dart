import '../attachments/attachment.dart';
import 'compression_profile.dart';
import 'compression_statistics.dart';

/// The payload compression seam.
///
/// Implementations own the actual byte transform; the engine owns policy
/// (thresholds, profile dispatch, statistics). All compressors are pure
/// relative to [CompressionSource] — bytes in, bytes out.
abstract interface class Compressor {
  /// Stable identifier (zlib, nativeImage, nativeVideo, …).
  String get id;

  /// Short label for diagnostics and the developer console.
  String get label;

  /// Whether [profile] is applicable to this compressor.
  bool supports(CompressionProfile profile, MediaCategory category);

  /// Compresses [source] toward [profile]. May return the input unchanged
  /// (method `none`) when compression is pointless; never throws.
  Future<CompressionStatistics> compress(
    CompressionSource source,
    CompressionProfile profile,
  );
}

/// Byte view of one payload handed to a compressor.
///
/// The data layer backs [read] with a file stream or the inline payload —
/// compressors never see `dart:io`.
abstract interface class CompressionSource {
  String get attachmentId;
  String get fileName;
  MediaCategory get category;
  int get sizeBytes;

  /// The current payload bytes (loaded by the caller when small enough, or
  /// by the compressor for lossless entropy runs).
  Future<List<int>> readBytes();

  /// Writes [bytes] as the payload replacement; the store already staged a
  /// temporary location, so this is an in-place swap.
  Future<void> replaceBytes(List<int> bytes);
}

/// A compressor that does nothing — the "no compression" baseline and the
/// fallback for categories with no engine wired.
final class NoopCompressor implements Compressor {
  const NoopCompressor();

  @override
  String get id => 'noop';

  @override
  String get label => 'No compression';

  @override
  bool supports(CompressionProfile profile, MediaCategory category) => false;

  @override
  Future<CompressionStatistics> compress(
    CompressionSource source,
    CompressionProfile profile,
  ) async => CompressionStatistics(
    method: CompressionMethod.none,
    inputBytes: source.sizeBytes,
    outputBytes: source.sizeBytes,
    durationMs: 0,
  );
}
