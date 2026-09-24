/// Verification state of a peer's cryptographic identity.
///
/// Tracks whether OneBit has established that a peer's presented
/// public key corresponds to the intended person. This is separate
/// from [TrustState] — a verified peer is not automatically trusted.
///
/// State transitions:
/// ```
/// unverified → verificationRequired → verified
/// ```
///
/// Verification is tied to the peer's cryptographic identity (public key),
/// not to BLE address, device name, or display name.
enum VerificationState {
  /// No identity verification has been performed.
  ///
  /// A peer in this state has been discovered but its cryptographic
  /// identity has not been verified through any out-of-band mechanism.
  unverified,

  /// The application requires explicit verification before accepting
  /// this peer's identity.
  ///
  /// This state indicates the peer is known to the application but
  /// its identity must be confirmed before it can be marked verified.
  verificationRequired,

  /// The peer's cryptographic identity has been successfully verified.
  ///
  /// The verified identity is anchored to the specific public key
  /// provided at verification time. Verification does NOT imply trust.
  verified,
}
