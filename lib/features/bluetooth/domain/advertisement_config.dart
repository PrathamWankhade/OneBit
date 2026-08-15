import 'package:flutter/foundation.dart';

/// Connectivity tuning for the embedded advertisement of one serving peer.
enum AdvertisingPowerMode {
  /// Prolong battery: longest interval this platform allows for the set
  /// txPower; usable over a few meters.
  lowPower('lowPower', -4),

  /// Default trade-off between discovery latency and battery.
  balanced('balanced', 0),

  /// Shortest interval and highest power floor; discovery in seconds.
  lowLatency('lowLatency', 2);

  const AdvertisingPowerMode(this.rawName, this.txPowerBoost);

  /// Stable wire name.
  final String rawName;

  /// Suggested txPower floor offset (dB) applied on top of the adapter's
  /// default transmit power for each mode.
  final int txPowerBoost;

  static AdvertisingPowerMode fromWire(String? raw) {
    for (final mode in values) {
      if (mode.rawName == raw) return mode;
    }
    return AdvertisingPowerMode.balanced;
  }
}

/// Advertisement payload and cadence for this device.
@immutable
final class AdvertisementConfig {
  const AdvertisementConfig({
    this.mode = AdvertisingPowerMode.balanced,
    this.serviceUuid,
    this.manufacturerId,
    this.manufacturerData = const [],
    this.localName,
    this.txPower = 0,
    this.background = false,
    this.rotationCount = 0,
  });

  /// Power/latency profile.
  final AdvertisingPowerMode mode;

  /// Primary service UUID, if the payload should expose one.
  final String? serviceUuid;

  /// 16-bit company id for manufacturer data.
  final int? manufacturerId;

  /// Bytes attached as manufacturer data (empty = no manufacturer data).
  final List<int> manufacturerData;

  /// Friendly name attached to the advertisement, if any.
  final String? localName;

  /// Advertised tx power in dBm singed value.
  final int txPower;

  /// When true, advertising continues while the app bg / screen off via
  /// the foreground service.
  final bool background;

  /// Rotate up to this many payload variants to survive scan-frequency
  /// filtering by peers (0 = no rotation).
  final int rotationCount;

  String get identitySeed =>
      '${serviceUuid ?? ''}|${manufacturerId ?? ''}|${localName ?? ''}';
}
