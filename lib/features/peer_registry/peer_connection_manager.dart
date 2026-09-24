import 'dart:async';

import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/peer_registry/peer_association.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';

/// Per-peer connection record mapping a logical peer identity to
/// its current BLE transport and lifecycle state.
class PeerConnectionRecord {
  const PeerConnectionRecord({
    required this.peerIdentityId,
    required this.deviceId,
    required this.lifecycleState,
    required this.connectionState,
  });

  /// Cryptographic identity ID of the peer.
  final String peerIdentityId;

  /// Current BLE device address, or null if no device is associated.
  final String? deviceId;

  /// Runtime lifecycle state for this peer.
  final PeerLifecycleState lifecycleState;

  /// BLE transport connection state for this peer.
  final BleConnectionState connectionState;

  bool get isConnected => lifecycleState == PeerLifecycleState.connected;
  bool get isConnecting => lifecycleState == PeerLifecycleState.connecting;
  bool get isDisconnected =>
      lifecycleState == PeerLifecycleState.disconnected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerConnectionRecord &&
          runtimeType == other.runtimeType &&
          peerIdentityId == other.peerIdentityId &&
          deviceId == other.deviceId &&
          lifecycleState == other.lifecycleState &&
          connectionState == other.connectionState;

  @override
  int get hashCode => Object.hash(
        peerIdentityId,
        deviceId,
        lifecycleState,
        connectionState,
      );

  @override
  String toString() =>
      'PeerConnectionRecord(peer: ${peerIdentityId.substring(0, peerIdentityId.length.clamp(0, 8))}..., '
      'device: $deviceId, lifecycle: $lifecycleState, ble: $connectionState)';
}

/// Bridges the BLE connection layer (device-keyed) with the peer
/// registry (identity-keyed), providing per-peer lifecycle and
/// connection state.
///
/// Maintains:
///   peer identity ID <-> BLE device ID <-> lifecycle state
///
/// Uses a generation counter per peer to protect against stale
/// asynchronous BLE callbacks corrupting newer connection state.
class PeerConnectionManager {
  PeerConnectionManager({
    required this._bleService,
    required this._resolver,
    required this._registry,
  });

  final BleService _bleService;
  final IdentityAssociationResolver _resolver;
  final PeerRegistryService _registry;

  /// Stream controller for connection records.
  final _controller =
      StreamController<List<PeerConnectionRecord>>.broadcast();

  /// Stream of all current peer connection records.
  Stream<List<PeerConnectionRecord>> get connectionStream =>
      _controller.stream;

  /// Current snapshot of all peer connection records.
  List<PeerConnectionRecord> get connections => _buildRecords();

  /// Internal mapping: peer identity ID -> BLE device ID.
  final Map<String, String> _peerToDevice = {};

  /// Lifecycle state per peer identity ID.
  final Map<String, PeerLifecycleState> _lifecycleState = {};

  /// Generation counter per peer to protect against stale callbacks.
  ///
  /// Each connect/disconnect call increments the counter. BLE callbacks
  /// check this counter before applying state changes.
  final Map<String, int> _generation = {};

  /// Peers that were intentionally disconnected.
  ///
  /// Prevents _syncFromBleState from re-syncing a peer that was
  /// explicitly disconnected by the application.
  final Set<String> _intentionallyDisconnected = {};

  StreamSubscription<BleState>? _bleStateSub;
  bool _initialized = false;

  /// Initialize the manager by subscribing to BLE state changes.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _bleStateSub = _bleService.stateStream.listen(_onBleStateChange);
    _syncFromBleState(_bleService.current);
  }

  /// Connect to a peer by identity ID.
  ///
  /// Transitions the peer to [PeerLifecycleState.connecting] immediately.
  /// On BLE success, transitions to [PeerLifecycleState.connected].
  /// On failure, transitions to [PeerLifecycleState.disconnected].
  ///
  /// Returns the BLE device ID if connection was initiated, or null
  /// if no device is available.
  Future<String?> connectToPeer(String peerIdentityId) async {
    // Idempotent: already connecting or connected.
    final current = _lifecycleState[peerIdentityId];
    if (current == PeerLifecycleState.connecting ||
        current == PeerLifecycleState.connected) {
      return _peerToDevice[peerIdentityId];
    }

    // If currently disconnecting, wait for disconnect to complete
    // before allowing a new connect attempt.
    if (current == PeerLifecycleState.disconnecting) {
      return null;
    }

    // Resolve the BLE device for this peer.
    final deviceId = _findDeviceForPeer(peerIdentityId);
    if (deviceId == null) return null;

    // Set up state before async gap.
    _peerToDevice[peerIdentityId] = deviceId;
    _intentionallyDisconnected.remove(peerIdentityId);
    final gen = _incrementGeneration(peerIdentityId);

    // Transition to CONNECTING.
    _setLifecycle(peerIdentityId, PeerLifecycleState.connecting);

    try {
      await _bleService.connect(deviceId);

      // Check generation: only apply if this is still the current attempt.
      if (_generation[peerIdentityId] == gen) {
        _setLifecycle(peerIdentityId, PeerLifecycleState.connected);
      }
      return deviceId;
    } catch (e) {
      // Check generation: only apply if this is still the current attempt.
      if (_generation[peerIdentityId] == gen) {
        _setLifecycle(peerIdentityId, PeerLifecycleState.disconnected);
        _peerToDevice.remove(peerIdentityId);
      }
      rethrow;
    }
  }

  /// Disconnect from a peer by identity ID.
  ///
  /// Transitions the peer to [PeerLifecycleState.disconnecting],
  /// then to [PeerLifecycleState.disconnected] on completion.
  ///
  /// Safe to call when not connected or already disconnecting — does not throw.
  /// Does not affect other peer connections.
  ///
  /// Cleanup is guaranteed even if the BLE disconnect call fails —
  /// local state is always cleaned up in the `finally` block.
  Future<void> disconnectFromPeer(String peerIdentityId) async {
    final deviceId = _peerToDevice[peerIdentityId];
    if (deviceId == null) return;

    // Guard against concurrent disconnect calls for the same peer.
    if (_lifecycleState[peerIdentityId] == PeerLifecycleState.disconnecting) {
      return;
    }

    final gen = _incrementGeneration(peerIdentityId);

    // Mark as intentionally disconnected so _syncFromBleState
    // does not re-process this peer.
    _intentionallyDisconnected.add(peerIdentityId);

    // Transition to DISCONNECTING.
    _setLifecycle(peerIdentityId, PeerLifecycleState.disconnecting);

    try {
      await _bleService.disconnect(deviceId);
    } catch (_) {
      // BLE disconnect may fail (device already gone, etc.).
      // Continue with local cleanup — the connection is effectively
      // dead from the application's perspective.
    } finally {
      // Only apply if this disconnect is still the current operation.
      if (_generation[peerIdentityId] == gen) {
        _setLifecycle(peerIdentityId, PeerLifecycleState.disconnected);
        _peerToDevice.remove(peerIdentityId);
        // I7.4: Remove the association when explicitly disconnecting.
        _resolver.removeAssociation(deviceId);
      }
    }
  }

  /// Get the current lifecycle state for a specific peer.
  PeerLifecycleState lifecycleStateFor(String peerIdentityId) =>
      _lifecycleState[peerIdentityId] ?? PeerLifecycleState.disconnected;

  /// Get the current BLE device ID for a peer, if any.
  String? deviceForPeer(String peerIdentityId) =>
      _peerToDevice[peerIdentityId];

  /// Whether a specific peer is currently connected.
  bool isPeerConnected(String peerIdentityId) =>
      lifecycleStateFor(peerIdentityId) == PeerLifecycleState.connected;

  /// Number of currently connected peers.
  int get connectedPeerCount =>
      _lifecycleState.values.where((s) => s == PeerLifecycleState.connected).length;

  /// Whether any peer is currently connected or connecting.
  bool get hasActiveConnections => _lifecycleState.values.any(
        (s) =>
            s == PeerLifecycleState.connected ||
            s == PeerLifecycleState.connecting,
      );

  /// I7.4: Get the current associations from the resolver.
  List<PeerAssociation> get currentAssociations =>
      _resolver.associations;

  /// Find the BLE device address for a peer identity ID from the
  /// identity association resolver's mapping.
  ///
  /// First checks the resolver's association-aware reverse lookup,
  /// then falls back to the device-to-peer map.
  String? _findDeviceForPeer(String peerIdentityId) {
    // I7.4: Use the resolver's association-aware reverse lookup first.
    final device = _resolver.resolveDevice(peerIdentityId);
    if (device != null) return device;

    // Fallback: scan the device-to-peer map.
    final target = peerIdentityId.toLowerCase();
    for (final entry in _resolver.deviceToPeerId.entries) {
      if (entry.value == target) {
        return entry.key;
      }
    }
    return null;
  }

  /// Increment and return the generation counter for a peer.
  int _incrementGeneration(String peerIdentityId) {
    final current = _generation[peerIdentityId] ?? 0;
    final next = current + 1;
    _generation[peerIdentityId] = next;
    return next;
  }

  /// Set the lifecycle state for a peer and push to registry.
  void _setLifecycle(String peerIdentityId, PeerLifecycleState state) {
    final previous = _lifecycleState[peerIdentityId];
    if (previous == state) return;

    _lifecycleState[peerIdentityId] = state;

    // Push to peer registry.
    _registry.updateLifecycle(peerIdentityId, lifecycleState: state);

    // Also push BLE connection state for backward compatibility.
    final deviceId = _peerToDevice[peerIdentityId];
    if (deviceId != null) {
      final bleInfo = _bleService.current.connectionFor(deviceId);
      _registry.updateConnection(
        peerIdentityId,
        connectionState: bleInfo?.state ?? BleConnectionState.disconnected,
        bleDeviceId: deviceId,
      );
    } else {
      _registry.updateConnection(
        peerIdentityId,
        connectionState: BleConnectionState.disconnected,
      );
    }

    _emit();
  }

  void _onBleStateChange(BleState bleState) {
    _syncFromBleState(bleState);
  }

  /// Sync lifecycle from BLE state changes.
  ///
  /// Adds new peers from the resolver's device-to-peer mapping when
  /// they appear in the BLE state, and updates lifecycle states for
  /// all tracked peers based on actual BLE connection state.
  void _syncFromBleState(BleState bleState) {
    final deviceToPeer = _resolver.deviceToPeerId;

    // Add new entries from the resolver for devices in BLE state.
    for (final deviceId in bleState.connections.keys) {
      final peerId = deviceToPeer[deviceId];
      if (peerId != null && !_peerToDevice.containsKey(peerId)) {
        _peerToDevice[peerId] = deviceId;
        // Set initial lifecycle from BLE state.
        final bleInfo = bleState.connectionFor(deviceId);
        final lifecycle = lifecycleFromBleState(
          bleInfo?.state ?? BleConnectionState.disconnected,
        );
        _setLifecycle(peerId, lifecycle);
      }
    }

    // Update lifecycle for all tracked peers.
    for (final entry in Map<String, String>.from(_peerToDevice).entries) {
      final peerId = entry.key;
      final deviceId = entry.value;

      // Skip peers that were intentionally disconnected.
      if (_intentionallyDisconnected.contains(peerId)) continue;

      final bleInfo = bleState.connectionFor(deviceId);
      final bleStateValue = bleInfo?.state ?? BleConnectionState.disconnected;
      final newLifecycle = lifecycleFromBleState(bleStateValue);

      final currentLifecycle = _lifecycleState[peerId];
      if (currentLifecycle == null) {
        // No lifecycle set yet — initialize from BLE state.
        _setLifecycle(peerId, newLifecycle);
        continue;
      }

      // Only update if the BLE state actually changed.
      if (newLifecycle != currentLifecycle) {
        if (_isValidTransition(currentLifecycle, newLifecycle)) {
          _setLifecycle(peerId, newLifecycle);
        }
      }
    }
  }

  /// Validate a lifecycle state transition.
  ///
  /// Returns true if the transition is valid or should be applied.
  /// Returns false if the transition should be rejected.
  bool _isValidTransition(PeerLifecycleState from, PeerLifecycleState to) {
    // All transitions from unknown are valid.
    if (from == PeerLifecycleState.unknown) return true;

    switch (from) {
      case PeerLifecycleState.discovered:
        // Discovered -> connecting, disconnected, connected are valid.
        return to == PeerLifecycleState.connecting ||
            to == PeerLifecycleState.disconnected ||
            to == PeerLifecycleState.connected;

      case PeerLifecycleState.connecting:
        // Connecting -> connected, disconnected are valid.
        return to == PeerLifecycleState.connected ||
            to == PeerLifecycleState.disconnected;

      case PeerLifecycleState.connected:
        // Connected -> disconnecting, disconnected are valid.
        return to == PeerLifecycleState.disconnecting ||
            to == PeerLifecycleState.disconnected;

      case PeerLifecycleState.disconnecting:
        // Disconnecting -> disconnected is valid.
        return to == PeerLifecycleState.disconnected;

      case PeerLifecycleState.disconnected:
        // Disconnected -> connecting, discovered are valid.
        return to == PeerLifecycleState.connecting ||
            to == PeerLifecycleState.discovered;

      case PeerLifecycleState.unknown:
        return true;
    }
  }

  List<PeerConnectionRecord> _buildRecords() {
    final bleState = _bleService.current;
    final records = <PeerConnectionRecord>[];

    for (final entry in _peerToDevice.entries) {
      final peerId = entry.key;
      final deviceId = entry.value;
      final bleInfo = bleState.connectionFor(deviceId);
      records.add(PeerConnectionRecord(
        peerIdentityId: peerId,
        deviceId: deviceId,
        lifecycleState: _lifecycleState[peerId] ?? PeerLifecycleState.disconnected,
        connectionState: bleInfo?.state ?? BleConnectionState.disconnected,
      ));
    }

    return records;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(connections);
    }
  }

  /// Disconnect all connected peers and release resources.
  ///
  /// Each peer is disconnected independently — failures for one peer
  /// do not prevent cleanup of others.
  Future<void> disconnectAll() async {
    final peerIds = _peerToDevice.keys.toList();
    for (final peerId in peerIds) {
      try {
        await disconnectFromPeer(peerId);
      } catch (_) {
        // Best-effort: continue cleaning up remaining peers.
      }
    }
  }

  /// Number of tracked peers (connected, connecting, or otherwise known).
  int get trackedPeerCount => _peerToDevice.length;

  /// Dispose resources.
  ///
  /// Intentionally does NOT disconnect peers — callers who need
  /// active disconnection should call [disconnectAll] first.
  /// This method ensures internal state is fully released.
  void dispose() {
    _bleStateSub?.cancel();
    _peerToDevice.clear();
    _lifecycleState.clear();
    _generation.clear();
    _intentionallyDisconnected.clear();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
