import 'package:flutter/foundation.dart';

/// Normalized waveform amplitudes of a voice recording.
///
/// [buckets] holds `0..1` amplitudes, immutable and capped at
/// [WaveformData.maxBuckets] regardless of the sample count.
@immutable
final class WaveformData {
  WaveformData._(List<double> buckets)
    : buckets = List<double>.unmodifiable(buckets);

  /// Builds a waveform from raw samples, resampled into [bucketCount]
  /// buckets (peak per bucket — preserves the loudest instant).
  factory WaveformData.fromSamples(
    List<double> samples, {
    int bucketCount = 128,
  }) {
    if (bucketCount < 2) {
      throw ArgumentError.value(bucketCount, 'bucketCount', 'must be >= 2');
    }
    if (samples.isEmpty) {
      return WaveformData._(List<double>.filled(bucketCount, 0));
    }
    final clamped = bucketCount > WaveformData.maxBuckets
        ? WaveformData.maxBuckets
        : bucketCount;
    final buckets = List<double>.filled(clamped, 0);
    final perBucket = samples.length / clamped;
    for (var i = 0; i < samples.length; i++) {
      final index = (i / perBucket).floor().clamp(0, clamped - 1);
      final value = samples[i].clamp(0.0, 1.0);
      if (value > buckets[index]) buckets[index] = value;
    }
    return WaveformData._(buckets);
  }

  /// Restores a stored waveform from JSON.
  static WaveformData? fromJson(List<Object?>? values) {
    if (values == null) return null;
    final buckets = <double>[
      for (final value in values)
        if (value is num) value.toDouble().clamp(0.0, 1.0),
    ];
    if (buckets.isEmpty) return null;
    return WaveformData._(buckets);
  }

  static const int maxBuckets = 256;

  /// The resampled amplitudes (0..1).
  final List<double> buckets;

  int get bucketCount => buckets.length;

  /// JSON serialization (numbers only).
  List<double> toJson() => buckets;

  @override
  bool operator ==(Object other) =>
      other is WaveformData &&
      other.bucketCount == bucketCount &&
      _listEquals(buckets, other.buckets);

  @override
  int get hashCode => Object.hashAll(buckets);

  static bool _listEquals(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'WaveformData($bucketCount buckets)';
}
