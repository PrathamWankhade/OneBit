/// Trust state of a peer identity.
///
/// Represents the user's established relationship with a peer's
/// cryptographic identity. Trust is based on the peer's public key,
/// not on display name, BLE address, or device name.
///
/// State transitions:
/// ```
/// unknown → verified → trusted
///                    → revoked
///          trusted → revoked
/// ```
///
/// No backward transitions from revoked.
enum TrustState {
  /// Peer has been discovered but identity not yet verified.
  ///
  /// A peer in this state has a known public key (from BLE or QR)
  /// but the user has not confirmed it belongs to the intended person.
  unknown,

  /// Peer identity has been verified through an out-of-band mechanism.
  ///
  /// Verification means the user confirmed the peer's fingerprint
  /// (via QR scan or manual comparison). The identity is confirmed
  /// but the user has not yet explicitly granted trust.
  verified,

  /// Peer is explicitly trusted by the user.
  ///
  /// Trust means the user has decided to communicate securely with
  /// this peer. Requires prior verification.
  trusted,

  /// Trust has been revoked.
  ///
  /// Revocation is permanent within this pairing cycle.
  /// A revoked peer must be explicitly re-verified and re-trusted.
  revoked,
}
