/// Identity change status for a BLE peer.
///
/// Represents whether a BLE device's cryptographic identity has
/// changed since the last time it was seen.
enum IdentityChangeStatus {
  /// No identity change — the BLE device presents the same
  /// cryptographic identity as before, or this is the first time
  /// the device has been seen.
  unchanged,

  /// The BLE device is presenting a different cryptographic identity
  /// than the one previously associated with this BLE address.
  changed,

  /// The identity change has been acknowledged by the user (e.g.,
  /// the new identity was verified via QR or fingerprint).
  acknowledged,
}

/// Result of identity change detection for a BLE peer.
///
/// Captures the previous and current cryptographic identities when
/// a change is detected, along with the resolution status.
class PeerIdentityChange {
  const PeerIdentityChange({
    required this.bleAddress,
    required this.previousIdentityId,
    required this.currentIdentityId,
    required this.status,
  });

  /// The BLE device address where the change was observed.
  final String bleAddress;

  /// The cryptographic identity (public key hex) previously associated
  /// with this BLE address.
  final String previousIdentityId;

  /// The new cryptographic identity (public key hex) currently presented
  /// by this BLE address.
  final String currentIdentityId;

  /// The detection status.
  final IdentityChangeStatus status;

  /// Whether an identity change was detected.
  bool get hasChanged => status == IdentityChangeStatus.changed;

  @override
  String toString() {
    final prev = previousIdentityId.length > 8
        ? previousIdentityId.substring(0, 8)
        : previousIdentityId;
    final curr = currentIdentityId.length > 8
        ? currentIdentityId.substring(0, 8)
        : currentIdentityId;
    return 'PeerIdentityChange(bleAddress: $bleAddress, '
        'previous: $prev..., '
        'current: $curr..., '
        'status: ${status.name})';
  }
}
