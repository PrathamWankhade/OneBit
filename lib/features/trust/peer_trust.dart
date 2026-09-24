import 'package:onebit/features/trust/trust_state.dart';

/// How a peer's identity was verified.
///
/// Records the out-of-band mechanism used to confirm the peer's
/// cryptographic identity matches the intended person.
enum VerificationMethod {
  /// Identity verified by scanning the peer's QR code.
  ///
  /// The QR code contains the peer's public identity. Scanning it
  /// confirms the local user initiated contact with this identity.
  qrScan,

  /// Identity verified by comparing fingerprints manually.
  ///
  /// Both parties compared their fingerprints (in person, voice call, etc.)
  /// and confirmed they match.
  fingerprintComparison,

  /// Identity verified through a secure pairing protocol.
  ///
  /// Used when I6.3 pairing handshake completes successfully.
  pairingProtocol,
}

/// Domain model representing the trust relationship with a peer.
///
/// Binds a peer's cryptographic identity to the user's trust decision.
/// This is the core data structure that all I6 increments build upon.
///
/// ## Security properties
///
/// - Trust is anchored to [peerIdentityId] (the peer's public key hex).
/// - Display name is NOT part of the trust anchor.
/// - BLE address is NOT part of the trust anchor.
/// - Trust states are immutable — transitions return new instances.
class PeerTrust {
  const PeerTrust({
    required this.peerIdentityId,
    required this.state,
    this.verifiedAt,
    this.verificationMethod,
    this.trustedAt,
    this.revokedAt,
    this.revokeReason,
    this.isAuthenticated = false,
  });

  /// The peer's cryptographic identity (hex-encoded Ed25519 public key).
  ///
  /// This is the trust anchor. All trust decisions apply to this
  /// specific cryptographic identity.
  final String peerIdentityId;

  /// Current trust state.
  final TrustState state;

  /// When the peer's identity was verified.
  ///
  /// Null if state is [TrustState.unknown].
  final DateTime? verifiedAt;

  /// How the peer's identity was verified.
  ///
  /// Null if state is [TrustState.unknown].
  final VerificationMethod? verificationMethod;

  /// When the peer was explicitly trusted.
  ///
  /// Null if state is not [TrustState.trusted].
  final DateTime? trustedAt;

  /// When trust was revoked.
  ///
  /// Null if state is not [TrustState.revoked].
  final DateTime? revokedAt;

  /// Optional reason for revocation.
  final String? revokeReason;

  /// Whether the peer has been cryptographically authenticated.
  ///
  /// This is set when the peer successfully proves control of their
  /// identity private key via I6.6 challenge-response authentication.
  /// Authentication and verification are independent dimensions.
  final bool isAuthenticated;

  // ── State queries ──────────────────────────────────────────

  bool get isUnknown => state == TrustState.unknown;
  bool get isVerified => state == TrustState.verified;
  bool get isTrusted => state == TrustState.trusted;
  bool get isRevoked => state == TrustState.revoked;

  /// Whether the peer can be used for secure communication.
  ///
  /// Only [TrustState.trusted] peers should be allowed for
  /// authenticated sessions.
  bool get canCommunicate => state == TrustState.trusted;

  // ── State transitions ──────────────────────────────────────

  /// Mark the peer as verified.
  ///
  /// Valid from [TrustState.unknown] only.
  /// Returns a new [PeerTrust] in [TrustState.verified].
  PeerTrust verify({
    required DateTime at,
    required VerificationMethod method,
  }) {
    if (state != TrustState.unknown) {
      throw StateError(
        'Cannot verify from state ${state.name}',
      );
    }
    return PeerTrust(
      peerIdentityId: peerIdentityId,
      state: TrustState.verified,
      verifiedAt: at,
      verificationMethod: method,
      isAuthenticated: isAuthenticated,
    );
  }

  /// Mark the peer as cryptographically authenticated.
  ///
  /// Can be set from any state except [TrustState.revoked].
  /// Authentication is independent of verification state — a peer can
  /// be authenticated without being verified, and vice versa.
  /// Returns a new [PeerTrust] with [isAuthenticated] set to true.
  PeerTrust markAuthenticated() {
    if (state == TrustState.revoked) {
      throw StateError(
        'Cannot authenticate a revoked peer',
      );
    }
    if (isAuthenticated) return this;
    return PeerTrust(
      peerIdentityId: peerIdentityId,
      state: state,
      verifiedAt: verifiedAt,
      verificationMethod: verificationMethod,
      trustedAt: trustedAt,
      revokedAt: revokedAt,
      revokeReason: revokeReason,
      isAuthenticated: true,
    );
  }

  /// Trust the peer.
  ///
  /// Requires the peer to be in [TrustState.verified] state AND
  /// [isAuthenticated] to be true. Both verification (human/out-of-band
  /// identity confirmation) and authentication (cryptographic proof of
  /// private-key possession) must be satisfied before trust can be established.
  ///
  /// Returns a new [PeerTrust] in [TrustState.trusted].
  PeerTrust trust({required DateTime at}) {
    if (state != TrustState.verified) {
      throw StateError(
        'Cannot trust from state ${state.name}',
      );
    }
    if (!isAuthenticated) {
      throw StateError(
        'Cannot trust without authentication',
      );
    }
    return PeerTrust(
      peerIdentityId: peerIdentityId,
      state: TrustState.trusted,
      verifiedAt: verifiedAt,
      verificationMethod: verificationMethod,
      trustedAt: at,
      isAuthenticated: true,
    );
  }

  /// Revoke trust.
  ///
  /// Valid from [TrustState.verified] or [TrustState.trusted].
  /// Returns a new [PeerTrust] in [TrustState.revoked].
  PeerTrust revoke({
    required DateTime at,
    String? reason,
  }) {
    if (state != TrustState.verified && state != TrustState.trusted) {
      throw StateError(
        'Cannot revoke from state ${state.name}',
      );
    }
    return PeerTrust(
      peerIdentityId: peerIdentityId,
      state: TrustState.revoked,
      verifiedAt: verifiedAt,
      verificationMethod: verificationMethod,
      trustedAt: trustedAt,
      revokedAt: at,
      revokeReason: reason,
      isAuthenticated: isAuthenticated,
    );
  }

  // ── Factory ────────────────────────────────────────────────

  /// Create a new peer trust in [TrustState.unknown].
  factory PeerTrust.unknown({required String peerIdentityId}) {
    return PeerTrust(
      peerIdentityId: peerIdentityId,
      state: TrustState.unknown,
    );
  }

  // ── Equality ───────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerTrust &&
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
    return 'PeerTrust($id, ${state.name})';
  }
}
