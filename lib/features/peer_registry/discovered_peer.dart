import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/trust/identity_change.dart';

/// A logical peer discovered via BLE, with aggregated discovery state.
///
/// Deduplication hierarchy: Cryptographic Identity > Logical PeerId > BLE Runtime Device.
/// Multiple BLE devices may advertise the same peer identity (e.g., multiple
/// phones for the same user). Each [DiscoveredPeer] represents one logical
/// peer identity with all associated BLE observations.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.identityId,
    required this.displayName,
    required this.status,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.devices,
    this.rssi = -100,
    this.peer,
    this.identityChange,
  });

  /// Cryptographic identity ID (hex-encoded public key).
  final String identityId;

  /// Display name — peer's local name if known, else BLE name, else "OneBit device".
  final String displayName;

  /// Resolution status against the known peer database.
  final BlePeerStatus status;

  /// When this peer was first discovered in the current scan session.
  final DateTime firstSeenAt;

  /// When this peer was most recently observed via BLE.
  final DateTime lastSeenAt;

  /// All BLE devices currently advertising this identity.
  ///
  /// Multiple devices may share the same identity (same user with
  /// multiple phones, or a BLE address change). The list is ordered
  /// by most recently seen.
  final List<DiscoveredBleDevice> devices;

  /// Best (strongest) RSSI across all devices for this peer.
  final int rssi;

  /// Resolved peer info from the known peer database, or null if unknown.
  final PeerInfo? peer;

  /// Identity change information, populated when status is
  /// [BlePeerStatus.identityChanged].
  final PeerIdentityChange? identityChange;

  /// Whether this peer is a known (trusted) peer.
  bool get isKnownPeer => status == BlePeerStatus.knownPeer;

  /// Whether this peer has an identity in its advertisement.
  bool get hasIdentity =>
      status != BlePeerStatus.noIdentity;

  /// Number of BLE devices currently advertising this identity.
  int get deviceCount => devices.length;

  /// The most recently seen BLE device for this peer.
  DiscoveredBleDevice? get primaryDevice =>
      devices.isNotEmpty ? devices.first : null;

  /// The primary device's BLE address, or null.
  String? get primaryDeviceId => primaryDevice?.deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeer &&
          runtimeType == other.runtimeType &&
          identityId == other.identityId &&
          status == other.status &&
          rssi == other.rssi &&
          lastSeenAt == other.lastSeenAt;

  @override
  int get hashCode => Object.hash(
        identityId,
        status,
        rssi,
        lastSeenAt,
      );

  @override
  String toString() =>
      'DiscoveredPeer(id: ${identityId.substring(0, identityId.length.clamp(0, 8))}..., '
      'status: $status, rssi: $rssi, devices: ${devices.length})';
}

/// A BLE device observation for a discovered peer.
class DiscoveredBleDevice {
  const DiscoveredBleDevice({
    required this.deviceId,
    required this.rssi,
    required this.lastSeenAt,
    this.firstSeenAt,
    this.name,
    this.rssiHistory = const [],
  });

  /// BLE MAC address.
  final String deviceId;

  /// Most recent RSSI reading for this device.
  final int rssi;

  /// When this device was first observed advertising this identity.
  final DateTime? firstSeenAt;

  /// When this device was most recently observed.
  final DateTime lastSeenAt;

  /// Advertised BLE local name.
  final String? name;

  /// Recent RSSI history for this device (newest first, max 10).
  final List<int> rssiHistory;

  /// Average RSSI from the history.
  int get averageRssi {
    if (rssiHistory.isEmpty) return rssi;
    return rssiHistory.reduce((a, b) => a + b) ~/ rssiHistory.length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredBleDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          rssi == other.rssi &&
          lastSeenAt == other.lastSeenAt;

  @override
  int get hashCode => Object.hash(deviceId, rssi, lastSeenAt);

  @override
  String toString() =>
      'DiscoveredBleDevice(deviceId: $deviceId, rssi: $rssi)';
}

/// Events emitted when a discovered peer's state changes.
class DiscoveryEvent {
  const DiscoveryEvent({
    required this.type,
    required this.peer,
  });

  /// The type of discovery event.
  final DiscoveryEventType type;

  /// The peer associated with this event.
  final DiscoveredPeer peer;

  @override
  String toString() =>
      'DiscoveryEvent(type: $type, peer: ${peer.identityId.substring(0, peer.identityId.length.clamp(0, 8))}...)';
}

/// Types of discovery events.
enum DiscoveryEventType {
  /// A new peer was discovered for the first time.
  appeared,

  /// An existing peer's RSSI or BLE device info was updated.
  updated,

  /// A known peer's identity changed (same BLE address, different key).
  identityChanged,

  /// A peer has not been seen for longer than the stale timeout.
  disappeared,
}
