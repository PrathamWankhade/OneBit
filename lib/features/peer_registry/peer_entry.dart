import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/trust/trust_state.dart';

/// A unified view of a peer combining identity, trust, and
/// connection state.
///
/// This is the core data model for the multi-peer registry.
/// Each peer is independently represented — no global peer state.
///
/// Connection and lifecycle fields are runtime-only (never persisted
/// in Drift).
class PeerEntry {
  const PeerEntry({
    required this.identityId,
    required this.peer,
    this.trustState = TrustState.unknown,
    this.isVerified = false,
    this.isAuthenticated = false,
    this.lifecycleState = PeerLifecycleState.disconnected,
    this.connectionState = BleConnectionState.disconnected,
    this.bleDeviceId,
  });

  /// Cryptographic identity ID (hex-encoded public key).
  final String identityId;

  /// Persistent peer identity from the database.
  final PeerInfo peer;

  /// Trust state for this peer.
  final TrustState trustState;

  /// Whether this peer's identity has been verified.
  final bool isVerified;

  /// Whether this peer has been cryptographically authenticated.
  final bool isAuthenticated;

  /// Runtime lifecycle state (runtime-only, not persisted).
  ///
  /// Describes the peer's connection lifecycle independently
  /// from BLE transport state and security states.
  final PeerLifecycleState lifecycleState;

  /// Current BLE connection state (runtime-only, not persisted).
  final BleConnectionState connectionState;

  /// BLE device address for this peer (runtime-only, not persisted).
  ///
  /// Null when the peer has no active BLE association.
  final String? bleDeviceId;

  /// Whether the peer is currently connected via BLE.
  bool get isConnected =>
      lifecycleState == PeerLifecycleState.connected;

  /// Whether the peer is currently connecting via BLE.
  bool get isConnecting =>
      lifecycleState == PeerLifecycleState.connecting;

  PeerEntry copyWith({
    PeerInfo? peer,
    TrustState? trustState,
    bool? isVerified,
    bool? isAuthenticated,
    PeerLifecycleState? lifecycleState,
    BleConnectionState? connectionState,
    String? bleDeviceId,
    bool clearBleDeviceId = false,
  }) {
    return PeerEntry(
      identityId: identityId,
      peer: peer ?? this.peer,
      trustState: trustState ?? this.trustState,
      isVerified: isVerified ?? this.isVerified,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      connectionState: connectionState ?? this.connectionState,
      bleDeviceId:
          clearBleDeviceId ? null : (bleDeviceId ?? this.bleDeviceId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerEntry &&
          runtimeType == other.runtimeType &&
          identityId == other.identityId &&
          trustState == other.trustState &&
          isVerified == other.isVerified &&
          isAuthenticated == other.isAuthenticated &&
          lifecycleState == other.lifecycleState &&
          connectionState == other.connectionState &&
          bleDeviceId == other.bleDeviceId;

  @override
  int get hashCode => Object.hash(
        identityId,
        trustState,
        isVerified,
        isAuthenticated,
        lifecycleState,
        connectionState,
        bleDeviceId,
      );

  @override
  String toString() =>
      'PeerEntry(id: ${identityId.substring(0, identityId.length.clamp(0, 8))}..., '
      'trust: $trustState, '
      'verified: $isVerified, auth: $isAuthenticated, '
      'lifecycle: $lifecycleState, conn: $connectionState)';
}
