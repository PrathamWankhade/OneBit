import 'package:onebit/features/ble/ble_uuids.dart';

/// Model for a BLE device discovered during scanning.
///
/// Mirrors the `scanResult` event payload emitted by the Kotlin
/// `ScannerManager`. The `deviceId` is the BLE MAC address (public or random).
///
/// Parsing is deliberately tolerant. Event payloads arrive through
/// `StandardMessageCodec`, which decodes *every* nested map as
/// `Map<Object?, Object?>` irrespective of what it contains, so a plain
/// `as Map<String, dynamic>` cast on `device`, `advertisement` or
/// `manufacturerData` throws a `TypeError` on every real advertisement.
/// Because those throws happen inside the event-stream listener they are
/// neither a stream error nor caught anywhere: the discovery stream simply
/// never emits and the Nearby list stays empty while the native scan looks
/// perfectly healthy. Nothing in this class may throw.
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
    this.identityFingerprint,
    this.oneBitAdvertisement = false,
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
  ///
  /// Empty for current peers: a 128-bit service UUID (18 bytes) cannot be
  /// fitted alongside the identity payload in a 31-byte packet, so the
  /// advertisement carries identity only and the UUID is served over GATT.
  final List<String> serviceUuids;

  /// Whether the device is connectable.
  final bool connectable;

  /// Full 32-byte Ed25519 public key, when the peer sent a v1 payload or
  /// the key has since been exchanged over GATT. Null for v2 peers seen
  /// at a distance — use [identityFingerprint] to identify them.
  final List<int>? identityPublicKeyBytes;

  /// 16-byte identity fingerprint broadcast in the advertisement.
  ///
  /// Always populated for a parseable OneBit identity, whether it was
  /// advertised directly (v2) or derived from the public key (v1).
  final List<int>? identityFingerprint;

  /// Whether the advertisement carried OneBit manufacturer data at all.
  ///
  /// Separate from a successful parse: a device claiming the OneBit
  /// company id with a malformed payload is still OneBit traffic and
  /// should not be dropped, it just has no usable identity.
  final bool oneBitAdvertisement;

  /// Whether this device presents as OneBit.
  ///
  /// True when the advertisement carried the OneBit company id or the
  /// OneBit service UUID (peers that predate the sizing fix, or a device
  /// that only advertises the GATT service).
  bool get isOneBit =>
      oneBitAdvertisement ||
      serviceUuids.any((u) => u.toUpperCase().contains(BleUuids.oneBitServiceShort));

  /// Whether this device carries any usable identity.
  bool get hasIdentity =>
      identityPublicKeyBytes != null || identityFingerprint != null;

  /// The hex-encoded identity public key, or null when only a fingerprint
  /// was advertised.
  String? get identityIdHex {
    final key = identityPublicKeyBytes;
    if (key == null) return null;
    return bytesToHex(key);
  }

  /// The hex-encoded identity fingerprint, or null.
  String? get identityFingerprintHex {
    final fingerprint = identityFingerprint;
    if (fingerprint == null) return null;
    return bytesToHex(fingerprint);
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
      identityFingerprint: identityFingerprint,
      oneBitAdvertisement: oneBitAdvertisement,
    );
  }

  /// Parse from a `scanResult` event map emitted by Kotlin.
  ///
  /// Never throws: malformed or foreign payloads degrade to a device with
  /// no identity rather than killing the discovery stream.
  factory DiscoveredOneBitDevice.fromScanResult(Map<String, dynamic> data) {
    final device = _stringKeyedMap(data['device']);
    final advertisement = _stringKeyedMap(data['advertisement']);

    List<int>? publicKey;
    List<int>? fingerprint;
    var oneBitAdvertisement = false;

    // Read the manufacturer map directly rather than through
    // _stringKeyedMap: Kotlin keys it with `SparseArray.keyAt(i).toString()`
    // today, but nothing forces that map to be string-keyed and silently
    // dropping a non-string key would drop the peer's identity with it.
    final rawIdentity =
        _oneBitManufacturerBytes(advertisement['manufacturerData']);
    if (rawIdentity != null) {
      oneBitAdvertisement = true;
      final identity = _decodeIdentityPayload(rawIdentity);
      publicKey = identity.publicKey;
      fingerprint = identity.fingerprint;
    }

    // A peer that still advertises the GATT service UUID is OneBit even if
    // its manufacturer payload did not parse.
    final serviceUuids = _stringList(advertisement['serviceUuids']);
    if (!oneBitAdvertisement &&
        serviceUuids.any((u) => u.toUpperCase().contains(BleUuids.oneBitServiceShort))) {
      oneBitAdvertisement = true;
    }

    return DiscoveredOneBitDevice(
      deviceId: _asString(device['id']) ?? 'unknown',
      rssi: _asInt(data['rssiDb']) ?? 0,
      timestamp: _asInt(data['timestamp']) ?? 0,
      name: _asString(advertisement['localName']),
      addressType: _asString(device['addressType']),
      serviceUuids: serviceUuids,
      connectable: _asBool(data['connectable']) ?? true,
      identityPublicKeyBytes: publicKey,
      identityFingerprint: fingerprint,
      oneBitAdvertisement: oneBitAdvertisement,
    );
  }

  /// Locate the OneBit entry in a manufacturer-data map and return its bytes.
  ///
  /// The Kotlin side keys the map with `SparseArray.keyAt(i).toString()`,
  /// which yields the decimal company id (`"65535"`), while Dart has
  /// historically read lowercase hex (`"0xffff"`). Accept every spelling
  /// the platform or a test might produce: an integer, decimal, and hex
  /// with or without the `0x` prefix and in either case.
  static List<int>? _oneBitManufacturerBytes(Object? value) {
    if (value is! Map) return null;
    for (final entry in value.entries) {
      if (_companyIdOf(entry.key) != BleIdentityProtocol.companyId) continue;
      final bytes = entry.value;
      // The company id alone marks this as OneBit traffic. Return an empty
      // list when the payload has the wrong shape so the caller reports the
      // device without inventing an identity for it, rather than dropping
      // the peer entirely.
      return bytes is List ? _intsFrom(bytes) : const <int>[];
    }
    return null;
  }

  /// Interpret a manufacturer-data map key as a Bluetooth company id.
  static int? _companyIdOf(Object? key) {
    if (key is int) return key;
    if (key is! String) return null;
    final text = key.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('0x') || text.startsWith('0X')) {
      return int.tryParse(text.substring(2), radix: 16);
    }
    // Kotlin writes decimal, but bare hex has appeared in test fixtures.
    return int.tryParse(text) ?? int.tryParse(text, radix: 16);
  }

  /// Decode a v1 (33-byte key) or v2 (17-byte fingerprint) identity payload.
  static ({List<int>? publicKey, List<int>? fingerprint}) _decodeIdentityPayload(
    List<int> bytes,
  ) {
    final v1Key = BleIdentityProtocol.parsePayload(bytes);
    if (v1Key != null) {
      return (
        publicKey: v1Key,
        fingerprint: BleIdentityProtocol.fingerprintBytes(v1Key),
      );
    }
    final v2Fingerprint = BleIdentityProtocol.parseAdvertPayload(bytes);
    if (v2Fingerprint != null) {
      return (publicKey: null, fingerprint: v2Fingerprint);
    }
    return (publicKey: null, fingerprint: null);
  }

  /// Lowercase hex of [bytes].
  static String bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

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
      'name: $name, isOneBit: $isOneBit, hasIdentity: $hasIdentity, '
      'fingerprint: ${identityFingerprintHex ?? 'none'})';
}

/// Rebuild [value] as a `Map<String, dynamic>`, tolerating the
/// `Map<Object?, Object?>` that `StandardMessageCodec` produces and
/// skipping any non-string key rather than throwing.
Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  value.forEach((key, entry) {
    if (key is String) out[key] = entry;
  });
  return out;
}

/// Coerce a codec-decoded list of numbers into `List<int>`.
List<int> _intsFrom(List<dynamic> source) {
  final out = <int>[];
  for (final value in source) {
    if (value is int) {
      out.add(value);
    } else if (value is num) {
      out.add(value.toInt());
    }
  }
  return out;
}

/// Read [value] as an `int`, accepting any numeric form.
int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Read [value] as a `String`, returning null for anything else.
String? _asString(Object? value) => value is String ? value : null;

/// Read [value] as a `bool`, returning null for anything else.
bool? _asBool(Object? value) => value is bool ? value : null;

/// Read [value] as a list of strings.
List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((e) => e.toString()).toList();
}
