/// OneBit BLE protocol constants.
///
/// The service UUID uniquely identifies a OneBit-capable device in BLE
/// advertisements and GATT services. It is stable across launches and
/// must never be generated randomly.
///
/// Format: Bluetooth SIG base UUID with a custom 16-bit prefix.
class BleUuids {
  BleUuids._();

  /// OneBit BLE service UUID.
  ///
  /// This is the primary identifier that other OneBit devices use to
  /// recognize a OneBit-capable endpoint during scanning.
  static const oneBitService = 'D1A00000-0000-1000-8000-00805F9B34FB';

  /// 16-bit short form of [oneBitService] for compact representations.
  static const oneBitServiceShort = 'D1A0';

  /// Communication characteristic UUID.
  ///
  /// Bidirectional write+notify characteristic on [oneBitService]
  /// for exchanging raw byte payloads between connected OneBit devices.
  static const communicationCharacteristic =
      'D1A00001-0000-1000-8000-00805F9B34FB';
}

/// Identity advertisement protocol constants for BLE.
///
/// These define the format of identity data embedded in BLE manufacturer
/// data advertisements. The payload is compact (33 bytes) to fit within
/// standard BLE advertisement size constraints.
class BleIdentityProtocol {
  BleIdentityProtocol._();

  /// OneBit manufacturer company ID (placeholder — replace with actual
  /// Bluetooth SIG company ID if registered, otherwise use 0xFFFF).
  static const int companyId = 0xFFFF;

  /// Identity advertisement protocol version.
  static const int protocolVersion = 1;

  /// Length of the Ed25519 public key in bytes.
  static const int publicKeyLength = 32;

  /// Total length of the identity payload: 1 (version) + 32 (public key).
  static const int payloadLength = protocolVersion + publicKeyLength;

  /// Build an identity advertisement payload.
  ///
  /// Returns a byte list: `[protocolVersion] [publicKey(32 bytes)]`.
  /// Returns null if [publicKeyBytes] is null or wrong length.
  static List<int>? buildPayload(List<int>? publicKeyBytes) {
    if (publicKeyBytes == null || publicKeyBytes.length != publicKeyLength) {
      return null;
    }
    return [protocolVersion, ...publicKeyBytes];
  }

  /// Parse an identity advertisement payload from raw bytes.
  ///
  /// Returns the public key bytes (32 bytes) if valid, null otherwise.
  /// Validates: length, version, and non-zero key.
  static List<int>? parsePayload(List<int> data) {
    if (data.length != payloadLength) return null;
    if (data[0] != protocolVersion) return null;
    final publicKey = data.sublist(1);
    if (publicKey.every((b) => b == 0)) return null;
    return publicKey;
  }
}

/// BLE advertising modes matching the Kotlin `AdvertiserManager` parameters.
enum BleAdvertiseMode {
  /// Balanced between latency and power.
  balanced,

  /// Low power, higher latency.
  lowPower,

  /// Low latency, higher power.
  lowLatency,
}

/// Current advertising session state.
enum BleAdvertisingState {
  /// No advertising is active.
  idle,

  /// Advertising is being started.
  starting,

  /// Actively advertising.
  advertising,

  /// Advertising is being stopped.
  stopping,

  /// Advertising encountered an error.
  error,
}

/// Configuration for a BLE advertising session.
class BleAdvertiseConfig {
  const BleAdvertiseConfig({
    this.serviceUuid = BleUuids.oneBitService,
    this.mode = BleAdvertiseMode.balanced,
    this.localName,
    this.identityPublicKeyBytes,
  });

  /// The service UUID to advertise.
  final String serviceUuid;

  /// Advertising power mode.
  final BleAdvertiseMode mode;

  /// Optional local name to include in manufacturer data.
  final String? localName;

  /// Optional 32-byte Ed25519 public key to embed in manufacturer data
  /// as a OneBit identity advertisement.
  final List<int>? identityPublicKeyBytes;
}
