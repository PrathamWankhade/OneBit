import 'package:cryptography/cryptography.dart';

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
/// Identity travels in the manufacturer-data AD element of the advertising
/// packet. Two payload formats exist:
///
///  * **v1** — `[version=1][public key(32)]` = 33 bytes. This does **not**
///    fit a legacy advertising packet: the platform adds a 3-byte flags AD
///    and the manufacturer AD header costs a further 4 bytes (length, type,
///    2-byte company id), so 33 usable bytes would need a 40-byte packet
///    against a 31-byte maximum. On hardware without extended advertising
///    the platform rejects it with `ADVERTISE_FAILED_DATA_TOO_LARGE` and
///    the phone becomes invisible to everyone. Kept only so that a peer
///    still running v1 can be understood.
///
///  * **v2** — `[version=2][fingerprint(16)]` = 17 bytes. Fits with room
///    to spare. The full public key is handed to the peer over GATT once a
///    connection exists, where MTU limits do not apply.
///
/// The trade is deliberate: [maxAdvertPayloadLength] bytes is a hard
/// platform limit, a 32-byte key can never fit inside it, so the
/// advertisement carries a stable lookup handle and authentication moves
/// to the connection phase.
class BleIdentityProtocol {
  BleIdentityProtocol._();

  /// OneBit manufacturer company ID (placeholder — replace with actual
  /// Bluetooth SIG company ID if registered, otherwise use 0xFFFF).
  static const int companyId = 0xFFFF;

  /// Version byte written by [buildAdvertPayload].
  static const int advertVersion = 2;

  /// Original (pre-sizing-fix) protocol version and public key length.
  ///
  /// [protocolVersion] is both the version byte and — confusingly — the
  /// length of that byte, which is why [payloadLength] reads as
  /// `protocolVersion + publicKeyLength` rather than `1 + 32`.
  static const int protocolVersion = 1;

  /// Length of the Ed25519 public key in bytes.
  static const int publicKeyLength = 32;

  /// Total length of the v1 identity payload: 1 (version) + 32 (public key).
  static const int payloadLength = protocolVersion + publicKeyLength;

  /// Number of fingerprint bytes broadcast in a v2 advertisement.
  static const int fingerprintLength = 16;

  /// Total length of the v2 identity payload: 1 (version) + 16 (fingerprint).
  static const int advertPayloadLength = 1 + fingerprintLength;

  /// Largest payload that fits a legacy advertising packet.
  ///
  /// 31 bytes of advertising data, minus the 3-byte flags AD the stack
  /// prepends, minus the 4-byte manufacturer AD header (length, type,
  /// 2-byte company id).
  static const int maxAdvertPayloadLength = 24;

  /// Build the v2 advertisement payload: `[advertVersion][fingerprint(16)]`.
  ///
  /// Returns null if [publicKeyBytes] is null or not a full Ed25519 key.
  static List<int>? buildAdvertPayload(List<int>? publicKeyBytes) {
    if (publicKeyBytes == null ||
        publicKeyBytes.length != publicKeyLength) {
      return null;
    }
    return [advertVersion, ...fingerprintBytes(publicKeyBytes)];
  }

  /// Build the v1 advertisement payload: `[protocolVersion][publicKey(32)]`.
  ///
  /// Superseded by [buildAdvertPayload] — 33 bytes does not fit a legacy
  /// advertising packet. Retained for tests and for peer compatibility.
  static List<int>? buildPayload(List<int>? publicKeyBytes) {
    if (publicKeyBytes == null || publicKeyBytes.length != publicKeyLength) {
      return null;
    }
    return [protocolVersion, ...publicKeyBytes];
  }

  /// SHA-256 of [publicKeyBytes], truncated to [fingerprintLength] bytes.
  ///
  /// This is a lookup handle for the advertisement, not a display
  /// fingerprint — see `computeFingerprint` in
  /// `features/identity/identity_fingerprint.dart` for the human-readable
  /// form. It is one-way, so broadcasting it reveals nothing that is not
  /// already public, while still giving every peer a stable identifier
  /// before the full key is exchanged over GATT.
  static List<int> fingerprintBytes(List<int> publicKeyBytes) {
    final digest = Sha256().toSync().hashSync(publicKeyBytes);
    return digest.bytes.take(fingerprintLength).toList();
  }

  /// Parse a v2 advertisement payload and return the 16-byte fingerprint.
  ///
  /// Returns null if the data is not a well-formed v2 payload.
  static List<int>? parseAdvertPayload(List<int> data) {
    if (data.length != advertPayloadLength) return null;
    if (data[0] != advertVersion) return null;
    final fingerprint = data.sublist(1);
    if (fingerprint.every((b) => b == 0)) return null;
    return fingerprint;
  }

  /// Parse a v1 advertisement payload and return the 32-byte public key.
  ///
  /// Returns null if the data is not a well-formed v1 payload.
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

  /// The GATT service UUID this device serves while advertising.
  ///
  /// It is registered with the GATT server so a peer can connect and read
  /// the identity over the wire. It is deliberately **not** written into
  /// the advertising packet alongside a manufacturer identity payload —
  /// the two together exceed the 31-byte legacy advertising budget, and a
  /// phone nobody can see can never connect. The UUID only becomes
  /// relevant once a link exists, where it arrives through service
  /// discovery.
  final String serviceUuid;

  /// Advertising power mode.
  final BleAdvertiseMode mode;

  /// Optional local name to include in manufacturer data.
  final String? localName;

  /// Optional 32-byte Ed25519 public key to embed in manufacturer data
  /// as a OneBit identity advertisement.
  final List<int>? identityPublicKeyBytes;
}
