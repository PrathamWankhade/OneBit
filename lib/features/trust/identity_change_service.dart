import 'dart:async';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/identity_change.dart';

/// Service that detects when a BLE device presents a different
/// cryptographic identity than previously associated.
///
/// Tracks BLE address → identity mappings in memory and persists
/// `lastSeenBleAddress` in the peer database. When a known BLE
/// address reappears with a different public key, an identity
/// change is flagged.
///
/// This service does NOT create peers, manage trust, or handle
/// verification. It only detects and reports identity changes.
class IdentityChangeService {
  IdentityChangeService([this._repository]);

  final IdentityRepository? _repository;

  /// In-memory mapping: BLE address → last known identity public key hex.
  final Map<String, String> _bleToIdentity = {};

  /// Stream controller for identity change events.
  final _changeController =
      StreamController<PeerIdentityChange>.broadcast();

  /// Stream of identity change events.
  ///
  /// Emits a [PeerIdentityChange] each time a BLE device is discovered
  /// presenting a different cryptographic identity than before.
  Stream<PeerIdentityChange> get onChange => _changeController.stream;

  /// Current number of tracked BLE-to-identity mappings.
  int get trackedCount => _bleToIdentity.length;

  /// Check a BLE discovery for identity change.
  ///
  /// If the BLE address was previously associated with a different
  /// identity, emits an identity change event and returns the change
  /// result. Otherwise returns null.
  ///
  /// Call this for every BLE discovery that carries a valid identity.
  PeerIdentityChange? checkForChange(DiscoveredOneBitDevice device) {
    final identityId = device.identityIdHex;
    if (identityId == null) return null;

    final bleAddress = device.deviceId;
    final previousIdentity = _bleToIdentity[bleAddress];

    // Update the mapping.
    _bleToIdentity[bleAddress] = identityId;

    // First time seeing this BLE address — no change.
    if (previousIdentity == null) return null;

    // Same identity — no change.
    if (previousIdentity.toLowerCase() == identityId.toLowerCase()) {
      return null;
    }

    // Identity change detected!
    final change = PeerIdentityChange(
      bleAddress: bleAddress,
      previousIdentityId: previousIdentity,
      currentIdentityId: identityId,
      status: IdentityChangeStatus.changed,
    );

    AppLogger.warning(
      'Identity change detected for BLE $bleAddress: '
      '${previousIdentity.substring(0, 8)}... → '
      '${identityId.substring(0, 8)}...',
    );

    if (!_changeController.isClosed) {
      _changeController.add(change);
    }

    return change;
  }

  /// Record a BLE-to-identity association without checking for changes.
  ///
  /// Use this to seed the mapping from persisted data (e.g., loading
  /// `lastSeenBleAddress` from the database on startup).
  void recordAssociation(String bleAddress, String identityId) {
    _bleToIdentity[bleAddress] = identityId;
  }

  /// Check if a BLE address was previously associated with a
  /// different identity than the one provided.
  bool hasIdentityChanged(String bleAddress, String currentIdentityId) {
    final previous = _bleToIdentity[bleAddress];
    if (previous == null) return false;
    return previous.toLowerCase() != currentIdentityId.toLowerCase();
  }

  /// Get the previously known identity for a BLE address.
  String? getPreviousIdentity(String bleAddress) {
    return _bleToIdentity[bleAddress];
  }

  /// Load persisted BLE-to-identity mappings from the database.
  ///
  /// Call this during initialization to restore mappings from
  /// `lastSeenBleAddress` columns in the peer table.
  Future<void> loadPersistedMappings() async {
    if (_repository == null) return;
    try {
      final peers = await _repository.getAllPeers();
      for (final peer in peers) {
        final bleAddress = peer.lastSeenBleAddress;
        final identityId = peer.identityId;
        if (bleAddress != null && identityId != null) {
          _bleToIdentity[bleAddress] = identityId;
        }
      }
      AppLogger.info(
        'Loaded ${_bleToIdentity.length} BLE-to-identity mappings',
      );
    } catch (e) {
      AppLogger.warning('Failed to load BLE-to-identity mappings: $e');
    }
  }

  /// Clear all mappings.
  void clear() {
    _bleToIdentity.clear();
  }

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
