import 'package:flutter/foundation.dart';

/// How a payload was (or was not) compressed.
enum CompressionMethod {
  /// The compressor decided the gain was below threshold.
  none,

  /// Entropy compression (zlib deflate) — documents and archives.
  zlib,

  /// Native image encoder (FFI land in a later phase; interface reserved).
  nativeImage,

  /// Native video encoder (later phase; interface reserved).
  nativeVideo;

  String get wireName => name;
}

/// Result of one compression run.
@immutable
final class CompressionStatistics {
  const CompressionStatistics({
    required this.method,
    required this.inputBytes,
    required this.outputBytes,
    required this.durationMs,
    this.applied = false,
  });

  final CompressionMethod method;
  final int inputBytes;
  final int outputBytes;
  final int durationMs;

  /// True when the compressed output actually replaced the original.
  final bool applied;

  /// `output/input`; > 1 when compression grew the file.
  double get ratio => inputBytes == 0 ? 0 : outputBytes / inputBytes;

  /// Relative byte savings (0..1); negative when compression grew.
  double get gain => 1 - ratio;

  bool get isCompressed => method != CompressionMethod.none && applied;

  static const CompressionStatistics skipped = CompressionStatistics(
    method: CompressionMethod.none,
    inputBytes: 0,
    outputBytes: 0,
    durationMs: 0,
  );
}
