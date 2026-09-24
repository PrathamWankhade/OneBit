import 'package:onebit/features/ble/ble_state.dart';

/// Runtime lifecycle state for a peer's connection.
///
/// This is a separate dimension from BLE transport state
/// ([BleConnectionState]) and from security states (trust, verification,
/// authentication). A peer's lifecycle state describes only its
/// connection lifecycle — whether it is discovered, connecting,
/// connected, or disconnected.
///
/// Lifecycle states are **runtime-only** — never persisted in Drift.
enum PeerLifecycleState {
  /// No usable runtime observation currently exists.
  ///
  /// This should not normally be the long-term state of a known peer.
  /// It indicates the peer has not been discovered or connected yet.
  unknown,

  /// A BLE observation exists for the peer, but no active connection.
  ///
  /// This state must not imply identity verification or trust.
  discovered,

  /// A connection attempt is currently in progress.
  connecting,

  /// The BLE transport connection is currently established.
  ///
  /// This means transport connectivity only. It does NOT imply
  /// verified, authenticated, trusted, or paired.
  connected,

  /// An intentional disconnection is being performed.
  disconnecting,

  /// No active BLE connection currently exists.
  ///
  /// A peer can remain known in the registry while disconnected.
  disconnected,
}

/// Whether this lifecycle state represents an active BLE connection.
extension PeerLifecycleStateX on PeerLifecycleState {
  bool get isActive =>
      this == PeerLifecycleState.connected ||
      this == PeerLifecycleState.connecting ||
      this == PeerLifecycleState.disconnecting;

  bool get isConnected => this == PeerLifecycleState.connected;
  bool get isConnecting => this == PeerLifecycleState.connecting;
  bool get isDisconnecting => this == PeerLifecycleState.disconnecting;
  bool get isDisconnected => this == PeerLifecycleState.disconnected;
  bool get isDiscovered => this == PeerLifecycleState.discovered;
  bool get isUnknown => this == PeerLifecycleState.unknown;
}

/// Maps a BLE transport connection state to a peer lifecycle state.
///
/// The BLE state is transport-level; the lifecycle state is
/// application-level. Error states map to [PeerLifecycleState.disconnected]
/// because the lifecycle does not persist failure — it reflects the
/// current observable connection status.
PeerLifecycleState lifecycleFromBleState(BleConnectionState bleState) {
  switch (bleState) {
    case BleConnectionState.disconnected:
      return PeerLifecycleState.disconnected;
    case BleConnectionState.connecting:
      return PeerLifecycleState.connecting;
    case BleConnectionState.connected:
      return PeerLifecycleState.connected;
    case BleConnectionState.disconnecting:
      return PeerLifecycleState.disconnecting;
    case BleConnectionState.error:
      return PeerLifecycleState.disconnected;
  }
}
