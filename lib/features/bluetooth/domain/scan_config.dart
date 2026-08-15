import 'package:flutter/foundation.dart';

/// How aggressively a scan runs.
enum ScanMode {
  /// Match the Android 5s/10s duty cycle (battery friendly).
  passive('passive', 5000),

  /// Request the platform's low-power scan window.
  active('active', 2000);

  const ScanMode(this.rawName, this.reportDelayMs);

  /// Stable wire name.
  final String rawName;

  /// Platform report delay hint in milliseconds.
  final int reportDelayMs;

  static ScanMode fromWire(String? raw) {
    for (final mode in values) {
      if (mode.rawName == raw) return mode;
    }
    return ScanMode.passive;
  }
}

/// Request for a scan cycle.
///
/// All fields are transport-level; filtering by peer identity/trust is a
/// higher-layer concern and never leaks in here.
@immutable
final class ScanConfig {
  const ScanConfig({
    this.mode = ScanMode.passive,
    this.serviceUuids = const [],
    this.adaptive = true,
    this.duplicateFilter = true,
    this.timeout,
    this.rssiReportInterval,
    this.background = false,
  });

  /// Passive (default) or active scanning.
  final ScanMode mode;

  /// Optional service UUIDs to filter on (empty = discover all).
  final List<String> serviceUuids;

  /// When true, the native side shortens windows while the app is in the
  /// foreground and lengthens them in the background / battery saver.
  final bool adaptive;

  /// When true, the native side suppresses repeated advertisements of the
  /// same device within the scan window.
  final bool duplicateFilter;

  /// Hard scan deadline; `null` means the scan runs until stopped.
  final Duration? timeout;

  /// Desired RSSI callback cadence while scanning (default 2 s).
  final Duration? rssiReportInterval;

  /// Marks a scan started for background discovery; the foreground
  /// service keeps it alive across screen-off.
  final bool background;

  ScanConfig copyWith({ScanMode? mode}) =>
      mode == null ? this : ScanConfig(mode: mode, adaptive: adaptive);
}
