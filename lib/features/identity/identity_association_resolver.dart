import 'dart:async';

import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_association.dart';
import 'package:onebit/features/trust/identity_change.dart';
import 'package:onebit/features/trust/identity_change_service.dart';

/// A BLE device resolved against the known peer database.
///
/// Contains the original BLE discovery information plus the resolved
/// peer identity (if the advertised identity is a known peer).
class ResolvedBleDevice {
  const ResolvedBleDevice({
    required this.device,
    this.peer,
    required this.status,
    this.identityChange,
  });

  /// The original BLE discovery information.
  final DiscoveredOneBitDevice device;

  /// The resolved peer, or null if unknown / no identity in advertisement.
  final PeerInfo? peer;

  /// The resolution status.
  final BlePeerStatus status;

  /// Identity change information, populated when status is
  /// [BlePeerStatus.identityChanged].
  final PeerIdentityChange? identityChange;

  /// Display name to show in the UI.
  ///
  /// Uses the peer's local display name if known, falls back to the
  /// BLE device name, then to "OneBit device".
  String get displayName {
    if (peer != null) return peer!.displayName;
    return device.name ?? 'OneBit device';
  }
}

/// Status of a BLE device's identity resolution.
enum BlePeerStatus {
  /// The device has no identity in its advertisement.
  noIdentity,

  /// The advertised identity is the local device's own identity.
  selfIdentity,

  /// The advertised identity matches a known peer.
  knownPeer,

  /// The advertised identity is from an unknown OneBit device.
  unknownIdentity,

  /// The BLE device is presenting a different cryptographic identity
  /// than the one previously associated with this BLE address.
  identityChanged,
}

/// Lightweight adapter that resolves BLE discoveries against the known
/// peer database.
///
/// Maintains an in-memory cache of known peers (public key hex → PeerInfo)
/// updated reactively from the database. Resolves each BLE discovery
/// against this cache without touching the database on every advertisement.
///
/// Deduplicates repeated discoveries of the same device within a
/// configurable time window to prevent UI thrashing and unnecessary
/// processing.
///
/// Does NOT create peers from BLE discoveries — only looks up existing ones.
/// Unknown identities are reported but never persisted.
class IdentityAssociationResolver {
  IdentityAssociationResolver({
    required Stream<DiscoveredOneBitDevice> discoveryStream,
    required Stream<List<PeerInfo>> peerStream,
    this._localPublicKeyHex,
    this._identityChangeService,
  }) {
    _peerSub = peerStream.listen(_onPeerUpdate);
    _discoverySub = discoveryStream.listen(_onDiscovery);
  }

  String? _localPublicKeyHex;
  final IdentityChangeService? _identityChangeService;

  /// In-memory cache: lowercase hex public key → PeerInfo.
  final Map<String, PeerInfo> _peerCache = {};

  /// Deduplication: deviceId → last emission timestamp (ms).
  final Map<String, int> _lastEmission = {};

  /// Deduplication window in milliseconds.
  static const int _deduplicationWindowMs = 3000;

  /// Stream controller for resolved devices.
  final _resolvedController =
      StreamController<ResolvedBleDevice>.broadcast();

  /// Stream of resolved BLE devices.
  ///
  /// Emits a [ResolvedBleDevice] each time a BLE device is discovered
  /// and resolved against the known peer database.
  Stream<ResolvedBleDevice> get resolvedStream => _resolvedController.stream;

  StreamSubscription<List<PeerInfo>>? _peerSub;
  StreamSubscription<DiscoveredOneBitDevice>? _discoverySub;

  /// Set the local identity public key (hex).
  ///
  /// Call this after the local identity is initialized to enable
  /// self-identity detection.
  void setLocalIdentity(String? publicKeyHex) {
    _localPublicKeyHex = publicKeyHex;
  }

  /// Current number of known peers in the cache.
  int get knownPeerCount => _peerCache.length;

  /// Look up a peer by public key hex from the in-memory cache.
  PeerInfo? lookupPeer(String publicKeyHex) {
    return _peerCache[publicKeyHex.toLowerCase()];
  }

  /// Mapping of BLE device IDs to peer identity IDs (hex public key).
  ///
  /// Updated as devices are resolved. Used by the peer registry
  /// to associate BLE connection state with peer identities.
  Map<String, String> get deviceToPeerId => Map.unmodifiable(_deviceIdToPeerId);

  /// Internal mapping: BLE device ID → peer identity ID (lowercase hex).
  final Map<String, String> _deviceIdToPeerId = {};

  // ── I7.4 Association Management ─────────────────────────────

  /// Active associations keyed by BLE device ID.
  final Map<String, PeerAssociation> _associations = {};

  /// Generation counter per BLE device for stale-event protection.
  final Map<String, int> _deviceGeneration = {};

  /// Stream controller for association changes.
  final _associationController =
      StreamController<List<PeerAssociation>>.broadcast();

  /// Stream of all current peer associations.
  ///
  /// Emits the full association list whenever any association changes.
  Stream<List<PeerAssociation>> get associationStream =>
      _associationController.stream;

  /// Snapshot of all current associations.
  List<PeerAssociation> get associations => _associations.values.toList();

  /// Number of active associations.
  int get associationCount => _associations.length;

  /// Resolve which BLE device is associated with a given peer identity.
  ///
  /// Returns the BLE device ID, or null if no device is associated
  /// with this peer. Uses the most recent association when multiple
  /// devices share the same identity (though only one active
  /// association per identity is supported).
  String? resolveDevice(String peerIdentityId) {
    final target = peerIdentityId.toLowerCase();
    for (final entry in _deviceIdToPeerId.entries) {
      if (entry.value == target) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if a BLE device is already associated with a different
  /// peer identity than the one requested.
  ///
  /// Returns an [AssociationConflict] if the device is associated
  /// with a different identity. Returns null if no conflict exists.
  AssociationConflict? checkConflict(
    String bleDeviceId,
    String requestedIdentityId,
  ) {
    final target = requestedIdentityId.toLowerCase();

    // Check if the device already has an association with a different identity.
    final existing = _associations[bleDeviceId];
    if (existing != null &&
        existing.peerIdentityId.toLowerCase() != target) {
      return AssociationConflict(
        identityId: requestedIdentityId,
        existingDeviceId: bleDeviceId,
        requestedDeviceId: bleDeviceId,
      );
    }

    // Check if this identity is already associated with a different device.
    for (final entry in _deviceIdToPeerId.entries) {
      if (entry.value == target && entry.key != bleDeviceId) {
        return AssociationConflict(
          identityId: requestedIdentityId,
          existingDeviceId: entry.key,
          requestedDeviceId: bleDeviceId,
        );
      }
    }

    return null;
  }

  /// Remove the association for a specific BLE device.
  ///
  /// Does not delete the underlying peer or identity — only
  /// removes the runtime BLE ↔ peer mapping.
  bool removeAssociation(String bleDeviceId) {
    final removed = _associations.remove(bleDeviceId);
    if (removed != null) {
      _deviceIdToPeerId.remove(bleDeviceId);
      _deviceGeneration.remove(bleDeviceId);
      _emitAssociations();
      return true;
    }
    return false;
  }

  /// Remove the association for a specific peer identity.
  ///
  /// Finds and removes whichever device is associated with this peer.
  bool removeAssociationForPeer(String peerIdentityId) {
    final target = peerIdentityId.toLowerCase();
    String? foundDevice;
    for (final entry in _deviceIdToPeerId.entries) {
      if (entry.value == target) {
        foundDevice = entry.key;
        break;
      }
    }
    if (foundDevice != null) {
      return removeAssociation(foundDevice);
    }
    return false;
  }

  /// Clear all associations.
  void clearAssociations() {
    _associations.clear();
    _deviceIdToPeerId.clear();
    _deviceGeneration.clear();
    _emitAssociations();
  }

  /// Get the current generation for a BLE device.
  ///
  /// Returns 0 if no association exists for the device.
  int generationFor(String bleDeviceId) =>
      _deviceGeneration[bleDeviceId] ?? 0;

  /// Increment and return the generation counter for a BLE device.
  int _incrementGeneration(String bleDeviceId) {
    final current = _deviceGeneration[bleDeviceId] ?? 0;
    final next = current + 1;
    _deviceGeneration[bleDeviceId] = next;
    return next;
  }

  void _emitAssociations() {
    if (!_associationController.isClosed) {
      _associationController.add(associations);
    }
  }

  /// Track a BLE device → peer identity association.
  ///
  /// Updates the device-to-peer mapping and creates a PeerAssociation
  /// record. Emits on the association stream if the association changed.
  void _trackAssociation(String deviceId, String identityIdHex) {
    final lowerId = identityIdHex.toLowerCase();

    // Update device-to-peer mapping.
    _deviceIdToPeerId[deviceId] = lowerId;

    // Check if existing association is the same.
    final existing = _associations[deviceId];
    if (existing != null && existing.peerIdentityId == lowerId) {
      return; // No change — same association.
    }

    // Create new association.
    final gen = _incrementGeneration(deviceId);
    _associations[deviceId] = PeerAssociation(
      bleDeviceId: deviceId,
      peerIdentityId: lowerId,
      generation: gen,
      createdAt: DateTime.now(),
    );
    _emitAssociations();
  }

  void _onPeerUpdate(List<PeerInfo> peers) {
    _peerCache.clear();
    for (final peer in peers) {
      final key = peer.identityId?.toLowerCase() ??
          peer.publicKeyHex?.toLowerCase();
      if (key != null) {
        _peerCache[key] = peer;
      }
    }
  }

  void _onDiscovery(DiscoveredOneBitDevice device) {
    // Deduplicate: suppress repeated discoveries within the window
    final now = device.timestamp;
    final lastSeen = _lastEmission[device.deviceId];
    if (lastSeen != null && (now - lastSeen) < _deduplicationWindowMs) {
      return;
    }
    _lastEmission[device.deviceId] = now;

    // Evict old entries to prevent unbounded growth
    if (_lastEmission.length > 200) {
      _lastEmission.removeWhere((_, ts) => (now - ts) > 30000);
    }

    final resolved = resolve(device);

    // Track device-to-identity mapping for peer registry.
    final identityId = resolved.peer?.identityId ??
        resolved.peer?.publicKeyHex;
    if (identityId != null) {
      // I7.4: Track association (handled by resolve() via _trackAssociation).
      // This also updates _deviceIdToPeerId.
    }

    if (!_resolvedController.isClosed) {
      _resolvedController.add(resolved);
    }
  }

  /// Resolve a BLE device against the known peer database.
  ///
  /// Returns a [ResolvedBleDevice] with the appropriate status:
  /// - [BlePeerStatus.noIdentity] if no identity in advertisement
  /// - [BlePeerStatus.selfIdentity] if it matches local identity
  /// - [BlePeerStatus.knownPeer] if it matches a known peer
  /// - [BlePeerStatus.unknownIdentity] if identity present but unknown
  /// - [BlePeerStatus.identityChanged] if the BLE device presents a
  ///   different identity than previously associated
  ResolvedBleDevice resolve(DiscoveredOneBitDevice device) {
    final publicKeyHex = device.identityIdHex;

    // No identity in advertisement.
    if (publicKeyHex == null) {
      return ResolvedBleDevice(
        device: device,
        status: BlePeerStatus.noIdentity,
      );
    }

    // Check self-identity.
    if (_localPublicKeyHex != null &&
        publicKeyHex.toLowerCase() == _localPublicKeyHex!.toLowerCase()) {
      // I7.4: Track association for self identity.
      _trackAssociation(device.deviceId, publicKeyHex);

      return ResolvedBleDevice(
        device: device,
        status: BlePeerStatus.selfIdentity,
      );
    }

    // Check for identity change via the IdentityChangeService.
    if (_identityChangeService != null) {
      final change = _identityChangeService.checkForChange(device);
      if (change != null && change.hasChanged) {
        // Identity change detected — this BLE address previously
        // presented a different identity. Track the new association
        // and report the change.
        _trackAssociation(device.deviceId, publicKeyHex);

        return ResolvedBleDevice(
          device: device,
          status: BlePeerStatus.identityChanged,
          identityChange: change,
        );
      }
    }

    // Look up in known peers cache.
    final peer = _peerCache[publicKeyHex.toLowerCase()];
    if (peer != null) {
      // I7.4: Track association for known peers.
      _trackAssociation(device.deviceId, publicKeyHex);

      return ResolvedBleDevice(
        device: device,
        peer: peer,
        status: BlePeerStatus.knownPeer,
      );
    }

    // Unknown identity.
    return ResolvedBleDevice(
      device: device,
      status: BlePeerStatus.unknownIdentity,
    );
  }

  /// Dispose resources.
  void dispose() {
    _peerSub?.cancel();
    _discoverySub?.cancel();
    _resolvedController.close();
    _associationController.close();
  }
}
