import 'dart:io';

import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/compression/compression_profile.dart';
import 'package:onebit/features/media/compression/compression_statistics.dart';
import 'package:onebit/features/media/compression/compressor.dart';

/// Pure-Dart DEFLATE compressor for lossless families (documents,
/// archives). Never throws; a run that does not shrink the payload keeps
/// the original bytes (method `none`).
final class DeflateCompressor implements Compressor {
  const DeflateCompressor();

  @override
  String get id => 'zlib';

  @override
  String get label => 'DEFLATE (zlib)';

  @override
  bool supports(CompressionProfile profile, MediaCategory category) =>
      profile.lossless &&
      (category == MediaCategory.document || category == MediaCategory.archive);

  @override
  Future<CompressionStatistics> compress(
    CompressionSource source,
    CompressionProfile profile,
  ) async {
    final started = DateTime.now();
    try {
      final input = await source.readBytes();
      final output = gzip.encode(input);
      final durationMs = DateTime.now().difference(started).inMilliseconds;
      final applied = output.length < input.length;
      return CompressionStatistics(
        method: applied ? CompressionMethod.zlib : CompressionMethod.none,
        inputBytes: input.length,
        outputBytes: applied ? output.length : input.length,
        durationMs: durationMs,
        applied: applied,
      );
    } catch (_) {
      return CompressionStatistics(
        method: CompressionMethod.none,
        inputBytes: source.sizeBytes,
        outputBytes: source.sizeBytes,
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }
}
