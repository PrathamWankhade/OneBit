import 'package:flutter/foundation.dart';

/// Link-quality categories derived from smoothed RSSI.
///
/// Produced by the transport for the future routing layer: neighbors can
/// be ranked by [LinkQuality] without re-deriving it.
enum LinkQuality { excellent, good, fair, poor, unknown }

/// RSSI observation with smoothing context.
@immutable
final class RssiReading {
  const RssiReading({
    required this.deviceId,
    required this.rssiDb,
    required this.smoothedDb,
    required this.timestamp,
  });

  /// Device this reading belongs to.
  final String deviceId;

  /// Raw reading in dBm.
  final int rssiDb;

  /// Exponentially smoothed reading in dBm.
  final double smoothedDb;

  /// When the reading was taken (device clock).
  final DateTime timestamp;

  /// Link quality derived from [smoothedDb].
  LinkQuality get quality {
    final rssi = smoothedDb;
    if (rssi >= -55) return LinkQuality.excellent;
    if (rssi >= -67) return LinkQuality.good;
    if (rssi >= -80) return LinkQuality.fair;
    if (rssi >= -90) return LinkQuality.poor;
    return LinkQuality.unknown;
  }
}
