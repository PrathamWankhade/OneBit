import 'package:onebit/features/ble/ble_uuids.dart';

/// Model for a BLE device discovered during scanning.
///
/// Mirrors the `scanResult` event payload emitted by the Kotlin
/// `ScannerManager`. The `deviceId` is the BLE MAC address (public or random).
class DiscoveredOneBitDevice {
  const DiscoveredOneBitDevice({
    required this.deviceId,
    required this.rssi,
    required this.timestamp,
    this.name,
    this.addressType,
    this.serviceUuids = const [],
    this.connectable = true,
    this.identityPublicKeyBytes,
  });

  /// BLE MAC address.
  final String deviceId;

  /// Signal strength in dBm.
  final int rssi;

  /// Timestamp in milliseconds since epoch.
  final int timestamp;

  /// Advertised local name (may be null if not present).
  final String? name;

  /// `public` or `random`.
  final String? addressType;

  /// Service UUIDs found in the advertisement.
  final List<String> serviceUuids;

  /// Whether the device is connectable.
  final bool connectable;

  /// Public key bytes extracted from the BLE manufacturer data.
  ///
  /// 32-byte Ed25519 public key, or null if the advertisement did not
  /// contain a valid OneBit identity payload.
  final List<int>? identityPublicKeyBytes;

  /// Whether this device advertises the OneBit service UUID.
  bool get isOneBit => serviceUuids
      .any((u) => u.toUpperCase().contains(BleUuids.oneBitServiceShort));

  /// Whether this device includes a valid OneBit identity in its advertisement.
  bool get hasIdentity => identityPublicKeyBytes != null;

  /// The hex-encoded identity public key, or null.
  String? get identityIdHex {
    final key = identityPublicKeyBytes;
    if (key == null) return null;
    return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Create a copy with an updated RSSI and timestamp.
  DiscoveredOneBitDevice withUpdatedRssi(int newRssi, int newTimestamp) {
    return DiscoveredOneBitDevice(
      deviceId: deviceId,
      rssi: newRssi,
      timestamp: newTimestamp,
      name: name,
      addressType: addressType,
      serviceUuids: serviceUuids,
      connectable: connectable,
      identityPublicKeyBytes: identityPublicKeyBytes,
    );
  }

  /// Parse from a `scanResult` event map emitted by Kotlin.
  factory DiscoveredOneBitDevice.fromScanResult(Map<String, dynamic> data) {
    final device = data['device'] as Map<String, dynamic>? ?? {};
    final advertisement =
        data['advertisement'] as Map<String, dynamic>? ?? {};

    // Parse identity from manufacturer data.
    List<int>? identityKey;
    final manufacturerData =
        advertisement['manufacturerData'] as Map<String, dynamic>?;
    if (manufacturerData != null) {
      identityKey = _parseIdentityFromManufacturerData(manufacturerData);
    }

    return DiscoveredOneBitDevice(
      deviceId: device['id'] as String? ?? 'unknown',
      rssi: data['rssiDb'] as int? ?? 0,
      timestamp: data['timestamp'] as int? ?? 0,
      name: advertisement['localName'] as String?,
      addressType: device['addressType'] as String?,
      serviceUuids: (advertisement['serviceUuids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      connectable: data['connectable'] as bool? ?? true,
      identityPublicKeyBytes: identityKey,
    );
  }

  /// Extract OneBit identity public key from manufacturer data.
  ///
  /// Only parses manufacturer data tagged with the known OneBit company ID.
  /// Does NOT fall back to other company IDs to prevent cross-vendor
  /// misinterpretation of unrelated BLE advertisements.
  static List<int>? _parseIdentityFromManufacturerData(
    Map<String, dynamic> manufacturerData,
  ) {
    final oneBitKey = '0x${BleIdentityProtocol.companyId.toRadixString(16)}';
    final rawBytes = manufacturerData[oneBitKey];
    if (rawBytes is List) {
      // Safe conversion: cast each element individually
      final bytes = rawBytes.map((e) => e as int).toList();
      return BleIdentityProtocol.parsePayload(bytes);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredOneBitDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          rssi == other.rssi &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(deviceId, rssi, timestamp);

  @override
  String toString() =>
      'DiscoveredOneBitDevice(deviceId: $deviceId, rssi: $rssi, '
      'name: $name, isOneBit: $isOneBit, hasIdentity: $hasIdentity)';
}
