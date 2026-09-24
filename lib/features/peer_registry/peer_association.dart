/// Explicit association between a BLE runtime device and a logical peer.
///
/// An association maps:
///   BLE device (transport) ↔ Peer identity (cryptographic)
///
/// Associations are runtime-only — never persisted as BLE objects.
/// The underlying peer ↔ cryptographic identity relationship is
/// managed by the existing identity repository (I4).
///
/// ## Security properties
///
/// - BLE address is never treated as cryptographic identity.
/// - Association does not imply verification, trust, authentication,
///   or pairing.
/// - Identity changes flow through I6.10, not through this model.
class PeerAssociation {
  const PeerAssociation({
    required this.bleDeviceId,
    required this.peerIdentityId,
    required this.generation,
    this.createdAt,
  });

  /// BLE transport device identifier (MAC address).
  final String bleDeviceId;

  /// Cryptographic identity ID of the associated peer (hex public key).
  final String peerIdentityId;

  /// Generation counter for stale-event protection.
  ///
  /// Monotonically increasing per association. Used to reject
  /// stale asynchronous events from old connection attempts.
  final int generation;

  /// When this association was created.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerAssociation &&
          runtimeType == other.runtimeType &&
          bleDeviceId == other.bleDeviceId &&
          peerIdentityId == other.peerIdentityId &&
          generation == other.generation;

  @override
  int get hashCode => Object.hash(bleDeviceId, peerIdentityId, generation);

  @override
  String toString() {
    final id = peerIdentityId.length > 8
        ? peerIdentityId.substring(0, 8)
        : peerIdentityId;
    return 'PeerAssociation(device: $bleDeviceId, peer: $id..., '
        'gen: $generation)';
  }
}

/// Conflict result when an identity is already associated with a
/// different BLE device.
///
/// Returned by [IdentityAssociationResolver] when a new association
/// would conflict with an existing one.
class AssociationConflict {
  const AssociationConflict({
    required this.identityId,
    required this.existingDeviceId,
    required this.requestedDeviceId,
  });

  /// The cryptographic identity in conflict.
  final String identityId;

  /// The BLE device currently associated with this identity.
  final String existingDeviceId;

  /// The BLE device that requested the new association.
  final String requestedDeviceId;

  @override
  String toString() {
    final id = identityId.length > 8
        ? identityId.substring(0, 8)
        : identityId;
    return 'AssociationConflict(identity: $id..., '
        'existing: $existingDeviceId, requested: $requestedDeviceId)';
  }
}
