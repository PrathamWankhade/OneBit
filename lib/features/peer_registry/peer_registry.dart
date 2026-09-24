import 'dart:async';

import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/trust/trust_state.dart';

/// In-memory registry of all known peers keyed by cryptographic identity.
///
/// Maintains a reactive stream of peer entries. Each peer is
/// independently represented — no global peer state.
///
/// Registry key = cryptographic identity ID (hex-encoded public key).
/// Never uses BLE address or device name as key.
class PeerRegistryService {
  final Map<String, PeerEntry> _peers = {};

  /// Stream controller for peer updates.
  final _controller = StreamController<List<PeerEntry>>.broadcast();

  /// Reactive stream of all known peers.
  ///
  /// Emits the current peer list whenever any peer's state changes.
  Stream<List<PeerEntry>> get peerStream => _controller.stream;

  /// Look up a peer by identity ID.
  PeerEntry? get(String identityId) => _peers[identityId];

  /// Whether a peer with the given identity ID is registered.
  bool contains(String identityId) => _peers.containsKey(identityId);

  /// Snapshot of all registered peers.
  List<PeerEntry> getAll() => _peers.values.toList();

  /// Current number of registered peers.
  int get count => _peers.length;

  /// Add or update a peer entry.
  ///
  /// If a peer with the same identity ID already exists, only the [PeerInfo]
  /// is updated — trust fields are preserved from the existing entry.
  /// Otherwise a new entry is created with all fields from [entry].
  void upsert(PeerEntry entry) {
    final existing = _peers[entry.identityId];
    if (existing != null) {
      _peers[entry.identityId] = existing.copyWith(peer: entry.peer);
    } else {
      _peers[entry.identityId] = entry;
    }
    _emit();
  }

  /// Remove a peer from the registry.
  ///
  /// Does NOT remove persistent identity records from the database.
  void remove(String identityId) {
    _peers.remove(identityId);
    _emit();
  }

  /// Sync from database identity list.
  ///
  /// Creates new entries for unknown peers and updates existing ones.
  /// Does not remove peers that have been deleted from the database.
  void updateFromIdentities(List<PeerInfo> idList) {
    for (final peer in idList) {
      final identityId = peer.identityId ?? peer.publicKeyHex;
      if (identityId == null || identityId.isEmpty) continue;

      final existing = _peers[identityId];
      if (existing != null) {
        _peers[identityId] = existing.copyWith(peer: peer);
      } else {
        _peers[identityId] = PeerEntry(
          identityId: identityId,
          peer: peer,
        );
      }
    }
    _emit();
  }

  /// Update BLE connection state for a peer.
  ///
  /// Updates the runtime-only connection fields on the peer entry.
  /// The peer must already be registered via [upsert] or [updateFromIdentities].
  void updateConnection(
    String identityId, {
    required BleConnectionState connectionState,
    String? bleDeviceId,
  }) {
    final existing = _peers[identityId];
    if (existing != null) {
      _peers[identityId] = existing.copyWith(
        connectionState: connectionState,
        bleDeviceId: bleDeviceId,
        clearBleDeviceId: bleDeviceId == null,
      );
      _emit();
    }
  }

  /// Update lifecycle state for a peer.
  ///
  /// Updates the runtime-only lifecycle field on the peer entry.
  /// The peer must already be registered via [upsert] or [updateFromIdentities].
  void updateLifecycle(
    String identityId, {
    required PeerLifecycleState lifecycleState,
  }) {
    final existing = _peers[identityId];
    if (existing != null) {
      _peers[identityId] = existing.copyWith(
        lifecycleState: lifecycleState,
      );
      _emit();
    }
  }

  /// Update trust state for a peer.
  void updateTrust(
    String identityId, {
    required TrustState trustState,
    bool isVerified = false,
    bool isAuthenticated = false,
  }) {
    final existing = _peers[identityId];
    if (existing != null) {
      _peers[identityId] = existing.copyWith(
        trustState: trustState,
        isVerified: isVerified,
        isAuthenticated: isAuthenticated,
      );
      _emit();
    }
  }

  /// Clear all entries.
  void clear() {
    _peers.clear();
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(getAll());
    }
  }

  /// Dispose resources.
  void dispose() {
    _controller.close();
  }
}
