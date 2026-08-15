import 'dart:async';

import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';

import 'compression_profile.dart';
import 'compression_statistics.dart';
import 'compressor.dart';

/// Compression policy engine: dispatch, thresholds, statistics.
///
/// Pure domain — byte work happens inside [Compressor] implementations,
/// persisted state goes through the caller. A run whose relative gain is
/// below the profile's `minGainPercent` keeps the original file.
final class CompressionEngine {
  CompressionEngine({
    required List<Compressor> compressors,
    required this.profileFor,
    required this.logger,
  }) : _compressors = List.unmodifiable(compressors);

  /// Compressors, tried in this order (first `supports` wins).
  final List<Compressor> _compressors;

  /// Resolves which profile applies to [attachmentId] (caller: repository
  /// or a built-in map); the [CompressionProfile] contract stays out of the
  /// engine so storage concerns never leak in.
  final CompressionProfile? Function(String attachmentId)? profileFor;

  final AppLogger logger;

  static const _tag = LogTags.media;

  /// Compresses [source] toward [profile].
  ///
  /// Returns `CompressionStatistics` with `applied: false` when the gain
  /// stayed below the profile threshold or no compressor matched.
  Future<Result<CompressionStatistics>> compress(
    CompressionSource source,
    CompressionProfile profile,
  ) async {
    if (!profile.enabled) {
      logger.trace(
        'compress(${source.attachmentId}): profile disabled',
        tag: _tag,
      );
      return const Ok(CompressionStatistics.skipped);
    }
    if (source.sizeBytes < _minimumBytesForCompression) {
      logger.trace(
        'compress(${source.attachmentId}): under minimum size',
        tag: _tag,
      );
      return const Ok(CompressionStatistics.skipped);
    }
    Compressor? chosen;
    for (final compressor in _compressors) {
      if (compressor.supports(profile, source.category)) {
        chosen = compressor;
        break;
      }
    }
    if (chosen == null) {
      return const Ok(CompressionStatistics.skipped);
    }
    final started = DateTime.now();
    final statistics = await chosen.compress(source, profile);
    final durationMs = DateTime.now().difference(started).inMilliseconds;
    if (!statistics.isCompressed) {
      return Ok(
        CompressionStatistics(
          method: statistics.method,
          inputBytes: statistics.inputBytes,
          outputBytes: statistics.outputBytes,
          durationMs: durationMs,
        ),
      );
    }
    final gainPercent = (statistics.gain * 100).round();
    if (gainPercent < profile.minGainPercent) {
      logger.trace(
        'compress(${source.attachmentId}): gain $gainPercent% below '
        '${profile.minGainPercent}% — keeping original',
        tag: _tag,
      );
      return Ok(
        CompressionStatistics(
          method: statistics.method,
          inputBytes: statistics.inputBytes,
          outputBytes: statistics.outputBytes,
          durationMs: durationMs,
        ),
      );
    }
    return Ok(
      CompressionStatistics(
        method: statistics.method,
        inputBytes: statistics.inputBytes,
        outputBytes: statistics.outputBytes,
        durationMs: durationMs,
        applied: true,
      ),
    );
  }

  /// Payloads smaller than this are never worth the transform.
  static const int _minimumBytesForCompression = 1 * 1024;
}
