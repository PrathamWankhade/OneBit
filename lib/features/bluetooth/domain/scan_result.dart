import 'package:flutter/foundation.dart';

import 'advertisement.dart';
import 'bluetooth_device.dart';

/// One observed advertisement of a peer during a scan.
@immutable
final class ScanResult {
  const ScanResult({
    required this.device,
    required this.rssiDb,
    required this.timestamp,
    this.advertisement = const Advertisement(),
    this.connectable = false,
  });

  /// The advertising peer.
  final BluetoothDevice device;

  /// Signal strength of this observation in dBm.
  final int rssiDb;

  /// When this advertisement was received (device clock).
  final DateTime timestamp;

  /// Parsed payload of this advertisement.
  final Advertisement advertisement;

  /// Whether the peer accepted connections in this advertisement.
  final bool connectable;

  @override
  String toString() =>
      'ScanResult(${device.id}, $rssiDb dBm, ${timestamp.toIso8601String()})';
}
