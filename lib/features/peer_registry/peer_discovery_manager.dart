import 'dart:async';

import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/peer_registry/discovered_peer.dart';

/// Central orchestrator for peer discovery deduplication.
///
/// Deduplication hierarchy: Cryptographic Identity > Logical PeerId > BLE Runtime Device.
///
/// Builds on top of [IdentityAssociationResolver] which resolves BLE
/// discoveries against the known peer database. This manager adds:
///   - Aggregation of multiple BLE devices per peer identity
///   - Per-peer discovery metrics (first/last seen, RSSI history)
///   - Discovery event stream (appeared, updated, identityChanged, disappeared)
///   - Stale peer eviction
///
/// Never auto-trusts, auto-connects, or auto-pairs. Discovery only identifies
/// BLE advertisements — it does not establish sessions or trust.
class PeerDiscoveryManager {
  PeerDiscoveryManager({
    required Stream<ResolvedBleDevice> resolvedStream,
    this.staleTimeoutMs = 30000,
    this.maxRssiHistory = 10,
    this.maxDevicesPerPeer = 5,
  }) {
    _resolvedSub = resolvedStream.listen(_onResolved);
  }

  /// Time in ms before a peer is considered disappeared.
  final int staleTimeoutMs;

  /// Maximum RSSI readings to keep per BLE device.
  final int maxRssiHistory;

  /// Maximum BLE devices to track per peer identity.
  final int maxDevicesPerPeer;

  /// Discovered peers keyed by lowercase identityId.
  final Map<String, DiscoveredPeer> _peers = {};

  /// BLE device → identity mapping for reverse lookups.
  final Map<String, String> _deviceToIdentity = {};

  /// Stream controller for discovery events.
  final _eventController = StreamController<DiscoveryEvent>.broadcast();

  /// Stream of discovery events.
  Stream<DiscoveryEvent> get eventStream => _eventController.stream;

  /// Stream controller for peer list updates.
  final _peersController =
      StreamController<List<DiscoveredPeer>>.broadcast();

  /// Stream of all currently discovered peers.
  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;

  /// Snapshot of all currently discovered peers.
  List<DiscoveredPeer> get peers => _peers.values.toList();

  /// Number of currently discovered peers.
  int get peerCount => _peers.length;

  /// The total number of BLE devices tracked across all peers.
  int get deviceCount => _deviceToIdentity.length;

  StreamSubscription<ResolvedBleDevice>? _resolvedSub;

  /// Look up a discovered peer by identity ID.
  DiscoveredPeer? peerById(String identityId) =>
      _peers[identityId.toLowerCase()];

  /// Look up a discovered peer by BLE device ID.
  DiscoveredPeer? peerByDevice(String deviceId) {
    final identityId = _deviceToIdentity[deviceId];
    if (identityId == null) return null;
    return _peers[identityId];
  }

  /// Remove a specific peer from the discovered set.
  ///
  /// Returns true if the peer was found and removed.
  bool removePeer(String identityId) {
    final key = identityId.toLowerCase();
    final removed = _peers.remove(key);
    if (removed == null) return false;

    // Clean up device-to-identity mappings.
    for (final device in removed.devices) {
      _deviceToIdentity.remove(device.deviceId);
    }

    _emitPeers();
    return true;
  }

  /// Clear all discovered peers.
  void clear() {
    _peers.clear();
    _deviceToIdentity.clear();
    _emitPeers();
  }

  /// Evict peers that haven't been seen within the stale timeout.
  ///
  /// Returns the list of evicted peers.
  List<DiscoveredPeer> evictStale() {
    final now = DateTime.now();
    final stale = <String>[];

    for (final entry in _peers.entries) {
      final age = now.difference(entry.value.lastSeenAt).inMilliseconds;
      if (age >= staleTimeoutMs) {
        stale.add(entry.key);
      }
    }

    final evicted = <DiscoveredPeer>[];
    for (final key in stale) {
      final removed = _peers.remove(key);
      if (removed != null) {
        for (final device in removed.devices) {
          _deviceToIdentity.remove(device.deviceId);
        }
        evicted.add(removed);
        _emitEvent(DiscoveryEventType.disappeared, removed);
      }
    }

    if (evicted.isNotEmpty) {
      _emitPeers();
    }

    return evicted;
  }

  void _onResolved(ResolvedBleDevice resolved) {
    final device = resolved.device;
    final identityId = resolved.peer?.identityId ??
        resolved.peer?.publicKeyHex ??
        device.identityIdHex;

    if (identityId == null) {
      // No identity — create a placeholder keyed by BLE device ID.
      _handleNoIdentity(resolved);
      return;
    }

    final key = identityId.toLowerCase();
    final now = DateTime.fromMillisecondsSinceEpoch(device.timestamp);
    final existing = _peers[key];

    if (existing == null) {
      // New peer discovered.
      _handleNewPeer(key, identityId, resolved, now);
    } else {
      // Existing peer updated.
      _handleExistingPeer(key, identityId, resolved, existing, now);
    }
  }

  void _handleNoIdentity(ResolvedBleDevice resolved) {
    final device = resolved.device;
    final deviceId = device.deviceId;

    // Only track if we haven't already mapped this device.
    if (_deviceToIdentity.containsKey(deviceId)) return;

    // Create a virtual peer keyed by BLE device ID.
    final now = DateTime.fromMillisecondsSinceEpoch(device.timestamp);
    final key = 'no-identity-$deviceId';

    final bleDevice = DiscoveredBleDevice(
      deviceId: deviceId,
      rssi: device.rssi,
      lastSeenAt: now,
      firstSeenAt: now,
      name: device.name,
      rssiHistory: [device.rssi],
    );

    final peer = DiscoveredPeer(
      identityId: key,
      displayName: device.name ?? 'OneBit device',
      status: BlePeerStatus.noIdentity,
      firstSeenAt: now,
      lastSeenAt: now,
      devices: [bleDevice],
      rssi: device.rssi,
    );

    _peers[key] = peer;
    _deviceToIdentity[deviceId] = key;

    _emitEvent(DiscoveryEventType.appeared, peer);
    _emitPeers();
  }

  void _handleNewPeer(
    String key,
    String identityId,
    ResolvedBleDevice resolved,
    DateTime now,
  ) {
    final device = resolved.device;

    final bleDevice = DiscoveredBleDevice(
      deviceId: device.deviceId,
      rssi: device.rssi,
      lastSeenAt: now,
      firstSeenAt: now,
      name: device.name,
      rssiHistory: [device.rssi],
    );

    final peer = DiscoveredPeer(
      identityId: identityId,
      displayName: resolved.displayName,
      status: resolved.status,
      firstSeenAt: now,
      lastSeenAt: now,
      devices: [bleDevice],
      rssi: device.rssi,
      peer: resolved.peer,
      identityChange: resolved.identityChange,
    );

    _peers[key] = peer;
    _deviceToIdentity[device.deviceId] = key;

    final eventType = resolved.status == BlePeerStatus.identityChanged
        ? DiscoveryEventType.identityChanged
        : DiscoveryEventType.appeared;

    _emitEvent(eventType, peer);
    _emitPeers();
  }

  void _handleExistingPeer(
    String key,
    String identityId,
    ResolvedBleDevice resolved,
    DiscoveredPeer existing,
    DateTime now,
  ) {
    final device = resolved.device;
    final deviceId = device.deviceId;

    // Check if this is the same BLE device or a new one.
    final existingDeviceIndex = existing.devices
        .indexWhere((d) => d.deviceId == deviceId);

    List<DiscoveredBleDevice> updatedDevices;
    if (existingDeviceIndex >= 0) {
      // Same device — update RSSI and timestamp.
      updatedDevices = List<DiscoveredBleDevice>.from(existing.devices);
      final old = updatedDevices[existingDeviceIndex];
      final newHistory = [
        device.rssi,
        ...old.rssiHistory,
      ].take(maxRssiHistory).toList();

      updatedDevices[existingDeviceIndex] = DiscoveredBleDevice(
        deviceId: deviceId,
        rssi: device.rssi,
        lastSeenAt: now,
        firstSeenAt: old.firstSeenAt,
        name: device.name ?? old.name,
        rssiHistory: newHistory,
      );
    } else {
      // New BLE device for this identity.
      final newDevice = DiscoveredBleDevice(
        deviceId: deviceId,
        rssi: device.rssi,
        lastSeenAt: now,
        firstSeenAt: now,
        name: device.name,
        rssiHistory: [device.rssi],
      );

      updatedDevices = [newDevice, ...existing.devices];
      if (updatedDevices.length > maxDevicesPerPeer) {
        updatedDevices = updatedDevices.sublist(0, maxDevicesPerPeer);
      }

      _deviceToIdentity[deviceId] = key;
    }

    // Sort devices by most recently seen.
    updatedDevices.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    // Compute best RSSI across all devices.
    int bestRssi = -100;
    for (final d in updatedDevices) {
      if (d.rssi > bestRssi) bestRssi = d.rssi;
    }

    final updated = DiscoveredPeer(
      identityId: identityId,
      displayName: resolved.displayName,
      status: resolved.status,
      firstSeenAt: existing.firstSeenAt,
      lastSeenAt: now,
      devices: updatedDevices,
      rssi: bestRssi,
      peer: resolved.peer,
      identityChange: resolved.identityChange,
    );

    _peers[key] = updated;

    final eventType = resolved.status == BlePeerStatus.identityChanged
        ? DiscoveryEventType.identityChanged
        : DiscoveryEventType.updated;

    _emitEvent(eventType, updated);
    _emitPeers();
  }

  void _emitEvent(DiscoveryEventType type, DiscoveredPeer peer) {
    if (!_eventController.isClosed) {
      _eventController.add(DiscoveryEvent(type: type, peer: peer));
    }
  }

  void _emitPeers() {
    if (!_peersController.isClosed) {
      _peersController.add(peers);
    }
  }

  /// Dispose resources.
  void dispose() {
    _resolvedSub?.cancel();
    _eventController.close();
    _peersController.close();
  }
}
