import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/verification_state.dart';

/// Immutable domain model representing the verification status
/// of a peer's cryptographic identity.
///
/// Verification is separate from trust. A verified peer has had
/// its public key confirmed through an out-of-band mechanism, but
/// the user has not necessarily granted trust.
///
/// ## Security properties
///
/// - Verification is anchored to [peerIdentityId] (public key hex).
/// - The [verifiedPublicKeyHex] records exactly which key was verified.
/// - Display name and BLE address are NOT part of verification.
/// - No private keys, session keys, or shared secrets are stored.
class PeerVerification {
  const PeerVerification({
    required this.peerIdentityId,
    required this.state,
    this.verifiedPublicKeyHex,
    this.verifiedAt,
    this.method,
  });

  /// The peer's cryptographic identity (hex-encoded Ed25519 public key).
  final String peerIdentityId;

  /// Current verification state.
  final VerificationState state;

  /// The public key that was verified.
  ///
  /// Must match [peerIdentityId] when [state] is [VerificationState.verified].
  /// Used to detect silent key replacement — if the presented key changes
  /// from this value, it is a security event.
  final String? verifiedPublicKeyHex;

  /// When the peer's identity was verified.
  ///
  /// Null if [state] is not [VerificationState.verified].
  final DateTime? verifiedAt;

  /// How the peer's identity was verified.
  ///
  /// Null if [state] is not [VerificationState.verified].
  final VerificationMethod? method;

  // ── State queries ──────────────────────────────────────────

  bool get isUnverified => state == VerificationState.unverified;
  bool get isVerificationRequired =>
      state == VerificationState.verificationRequired;
  bool get isVerified => state == VerificationState.verified;

  // ── State transitions ──────────────────────────────────────

  /// Mark verification as required.
  ///
  /// Valid from [VerificationState.unverified] only.
  PeerVerification requireVerification() {
    if (state != VerificationState.unverified) {
      throw StateError(
        'Cannot require verification from state ${state.name}',
      );
    }
    return PeerVerification(
      peerIdentityId: peerIdentityId,
      state: VerificationState.verificationRequired,
    );
  }

  /// Mark the peer as verified with the given public key.
  ///
  /// Valid from [VerificationState.verificationRequired] or
  /// [VerificationState.unverified].
  ///
  /// The [publicKeyHex] must match [peerIdentityId] to prevent
  /// identity swap attacks.
  PeerVerification markVerified({
    required DateTime at,
    required String publicKeyHex,
    required VerificationMethod method,
  }) {
    if (state == VerificationState.verified) {
      throw StateError('Peer is already verified');
    }
    if (publicKeyHex != peerIdentityId) {
      throw ArgumentError(
        'Public key does not match peer identity',
      );
    }
    return PeerVerification(
      peerIdentityId: peerIdentityId,
      state: VerificationState.verified,
      verifiedPublicKeyHex: publicKeyHex,
      verifiedAt: at,
      method: method,
    );
  }

  // ── Factory ────────────────────────────────────────────────

  /// Create an unverified peer.
  factory PeerVerification.unverified({required String peerIdentityId}) {
    return PeerVerification(
      peerIdentityId: peerIdentityId,
      state: VerificationState.unverified,
    );
  }

  /// Create a peer with verification required.
  factory PeerVerification.verificationRequired({
    required String peerIdentityId,
  }) {
    return PeerVerification(
      peerIdentityId: peerIdentityId,
      state: VerificationState.verificationRequired,
    );
  }

  // ── Equality ───────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerVerification &&
          runtimeType == other.runtimeType &&
          peerIdentityId == other.peerIdentityId &&
          state == other.state;

  @override
  int get hashCode => Object.hash(peerIdentityId, state);

  @override
  String toString() {
    final id = peerIdentityId.length < 16
        ? peerIdentityId
        : '${peerIdentityId.substring(0, 8)}…';
    return 'PeerVerification($id, ${state.name})';
  }
}
