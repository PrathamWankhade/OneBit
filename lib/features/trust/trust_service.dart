import 'dart:async';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/peer_verification.dart';
import 'package:onebit/features/trust/trust_state.dart';
import 'package:onebit/features/trust/verification_state.dart';

/// Trust service with optional persistence.
///
/// Manages trust and verification state for discovered peers.
/// All decisions are anchored to the peer's cryptographic identity.
///
/// When an [IdentityRepository] is provided, trust state is persisted
/// to the database and restored on initialization.
///
/// Emits [TrustChangeEvent] on [changeStream] whenever trust or
/// verification state is mutated, enabling reactive synchronization
/// with the peer registry.
class TrustService {
  TrustService([this._repository]) {
    _loadPersistedTrust();
  }

  final IdentityRepository? _repository;

  final Map<String, PeerTrust> _trustMap = {};
  final Map<String, PeerVerification> _verificationMap = {};

  final _changeController = StreamController<TrustChangeEvent>.broadcast();

  /// Stream of trust change events.
  ///
  /// Emitted whenever a trust or verification state mutation occurs.
  /// Each event identifies the peer whose trust changed and the new state.
  Stream<TrustChangeEvent> get changeStream => _changeController.stream;

  void _emitChange(String peerIdentityId, TrustState newState) {
    if (!_changeController.isClosed) {
      _changeController.add(TrustChangeEvent(
        peerIdentityId: peerIdentityId,
        newState: newState,
      ));
    }
  }

  // ── Persistence ──────────────────────────────────────────

  /// Load persisted trust records from the database.
  ///
  /// Also reconstructs the in-memory verification map from persisted
  /// trust data so that [isVerified] returns correct results after restart.
  Future<void> _loadPersistedTrust() async {
    if (_repository == null) return;
    try {
      final records = await _repository.loadAllTrust();
      for (final record in records) {
        _trustMap[record.peerIdentityId] = record;

        // Reconstruct verification state from persisted trust data.
        // If a peer was verified (verifiedAt != null), create a
        // corresponding PeerVerification entry so isVerified() works
        // correctly after restart.
        if (record.verifiedAt != null && record.verificationMethod != null) {
          _verificationMap[record.peerIdentityId] = PeerVerification(
            peerIdentityId: record.peerIdentityId,
            state: VerificationState.verified,
            verifiedPublicKeyHex: record.peerIdentityId,
            verifiedAt: record.verifiedAt,
            method: record.verificationMethod,
          );
        }
      }
      AppLogger.info('Loaded ${records.length} persisted trust records');
    } catch (e) {
      AppLogger.warning('Failed to load trust records: $e');
    }
  }

  /// Persist a trust record to the database.
  Future<void> _persistTrust(PeerTrust trust) async {
    if (_repository == null) return;
    try {
      await _repository.savePeerTrust(
        peerIdentityId: trust.peerIdentityId,
        state: trust.state,
        verifiedAt: trust.verifiedAt,
        verificationMethod: trust.verificationMethod,
        trustedAt: trust.trustedAt,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to persist trust for ${trust.peerIdentityId}: $e',
      );
    }
  }

  // ── Trust queries ──────────────────────────────────────────

  /// Get the trust record for a peer.
  ///
  /// Returns [PeerTrust.unknown] if no trust record exists.
  PeerTrust getTrust(String peerIdentityId) {
    return _trustMap[peerIdentityId] ??
        PeerTrust.unknown(peerIdentityId: peerIdentityId);
  }

  /// Check if a peer is trusted.
  bool isTrusted(String peerIdentityId) {
    return getTrust(peerIdentityId).isTrusted;
  }

  /// Check if a peer can be used for secure communication.
  bool canCommunicate(String peerIdentityId) {
    return getTrust(peerIdentityId).canCommunicate;
  }

  // ── Trust state mutations ──────────────────────────────────

  /// Mark a peer's identity as verified.
  PeerTrust verify({
    required String peerIdentityId,
    required DateTime at,
    required VerificationMethod method,
  }) {
    final current = getTrust(peerIdentityId);
    final updated = current.verify(at: at, method: method);
    _trustMap[peerIdentityId] = updated;
    _persistTrust(updated);
    _emitChange(peerIdentityId, updated.state);
    return updated;
  }

  /// Trust a verified peer.
  PeerTrust trust({
    required String peerIdentityId,
    required DateTime at,
  }) {
    final current = getTrust(peerIdentityId);
    final updated = current.trust(at: at);
    _trustMap[peerIdentityId] = updated;
    _persistTrust(updated);
    _emitChange(peerIdentityId, updated.state);
    return updated;
  }

  /// Revoke trust for a peer.
  ///
  /// Transitions [TrustState.verified] or [TrustState.trusted] to
  /// [TrustState.revoked].  The peer identity itself is not deleted.
  /// Persists the revocation so it survives application restart.
  ///
  /// Returns the updated [PeerTrust].  If the peer is already revoked
  /// the existing record is returned unchanged.
  PeerTrust revoke({
    required String peerIdentityId,
    required DateTime at,
    String? reason,
  }) {
    final current = getTrust(peerIdentityId);
    if (current.isRevoked) return current;
    final updated = current.revoke(at: at, reason: reason);
    _trustMap[peerIdentityId] = updated;
    _persistTrust(updated);
    _emitChange(peerIdentityId, updated.state);
    return updated;
  }

  /// High-level trust revocation API.
  ///
  /// Explicitly revoke an existing trust relationship.  Only peers in
  /// [TrustState.verified] or [TrustState.trusted] can be revoked.
  /// The revocation is persisted and survives application restart.
  ///
  /// If the peer is already revoked the existing record is returned
  /// unchanged (idempotent).
  ///
  /// Returns the updated [PeerTrust].
  PeerTrust revokeTrust({
    required String peerIdentityId,
    required DateTime at,
    String? reason,
  }) {
    final current = getTrust(peerIdentityId);
    if (current.isRevoked) return current;
    if (current.state != TrustState.verified &&
        current.state != TrustState.trusted) {
      throw StateError(
        'Cannot revoke trust: peer is not verified or trusted '
        '(current state: ${current.state.name})',
      );
    }
    final updated = current.revoke(at: at, reason: reason);
    _trustMap[peerIdentityId] = updated;
    _persistTrust(updated);
    _emitChange(peerIdentityId, updated.state);
    return updated;
  }

  /// Get all trust records.
  List<PeerTrust> getAll() => _trustMap.values.toList();

  /// Get all trusted peers.
  List<PeerTrust> getTrusted() =>
      _trustMap.values.where((t) => t.isTrusted).toList();

  /// Get all verified peers.
  List<PeerTrust> getVerified() =>
      _trustMap.values.where((t) => t.isVerified).toList();

  /// Get all revoked peers.
  List<PeerTrust> getRevoked() =>
      _trustMap.values.where((t) => t.isRevoked).toList();

  /// Number of trust records.
  int get count => _trustMap.length;

  /// Clear all trust state.
  void clear() {
    _trustMap.clear();
    _verificationMap.clear();
  }

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }

  // ── Verification ──────────────────────────────────────────

  /// Get the verification record for a peer.
  PeerVerification getVerification(String peerIdentityId) {
    return _verificationMap[peerIdentityId] ??
        PeerVerification.unverified(peerIdentityId: peerIdentityId);
  }

  /// Check if a peer's identity has been verified.
  bool isVerified(String peerIdentityId) {
    return getVerification(peerIdentityId).isVerified;
  }

  /// Mark a peer as requiring verification.
  PeerVerification requireVerification(String peerIdentityId) {
    final current = getVerification(peerIdentityId);
    final updated = current.requireVerification();
    _verificationMap[peerIdentityId] = updated;
    return updated;
  }

  /// Mark a peer's identity as verified.
  ///
  /// Updates both the verification map AND the trust record so that
  /// verification state is persisted and survives application restart.
  PeerVerification verifyIdentity({
    required String peerIdentityId,
    required DateTime at,
    required String publicKeyHex,
    required VerificationMethod method,
  }) {
    final current = getVerification(peerIdentityId);
    final updated = current.markVerified(
      at: at,
      publicKeyHex: publicKeyHex,
      method: method,
    );
    _verificationMap[peerIdentityId] = updated;

    // Also update the trust record's verification fields so that
    // verification state persists across restarts.
    final trust = getTrust(peerIdentityId);
    if (trust.state == TrustState.unknown) {
      final verifiedTrust = trust.verify(at: at, method: method);
      _trustMap[peerIdentityId] = verifiedTrust;
      _persistTrust(verifiedTrust);
      _emitChange(peerIdentityId, verifiedTrust.state);
    }

    return updated;
  }

  // ── Authentication ──────────────────────────────────────────

  /// Mark a peer as cryptographically authenticated.
  PeerTrust markAuthenticated({
    required String peerIdentityId,
  }) {
    final current = getTrust(peerIdentityId);
    final updated = current.markAuthenticated();
    _trustMap[peerIdentityId] = updated;
    return updated;
  }

  /// Check if a peer is authenticated.
  bool isAuthenticated(String peerIdentityId) {
    return getTrust(peerIdentityId).isAuthenticated;
  }

  // ── Trust establishment ─────────────────────────────────────

  /// Check whether a peer is eligible for trust establishment.
  bool canEstablishTrust(String peerIdentityId) {
    final trust = getTrust(peerIdentityId);
    return trust.state == TrustState.verified && trust.isAuthenticated;
  }

  /// Establish trust for a verified and authenticated peer.
  PeerTrust establishTrust({
    required String peerIdentityId,
    required DateTime at,
  }) {
    final current = getTrust(peerIdentityId);

    if (current.isTrusted) {
      return current;
    }

    if (current.state != TrustState.verified) {
      throw StateError(
        'Cannot establish trust: peer must be verified '
        '(current state: ${current.state.name})',
      );
    }

    if (!current.isAuthenticated) {
      throw StateError(
        'Cannot establish trust: peer must be authenticated',
      );
    }

    final updated = current.trust(at: at);
    _trustMap[peerIdentityId] = updated;
    _persistTrust(updated);
    _emitChange(peerIdentityId, updated.state);
    return updated;
  }
}

/// Notification event when trust state changes for a peer.
class TrustChangeEvent {
  const TrustChangeEvent({
    required this.peerIdentityId,
    required this.newState,
  });

  /// The identity ID of the peer whose trust changed.
  final String peerIdentityId;

  /// The new trust state after the change.
  final TrustState newState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrustChangeEvent &&
          runtimeType == other.runtimeType &&
          peerIdentityId == other.peerIdentityId &&
          newState == other.newState;

  @override
  int get hashCode => Object.hash(peerIdentityId, newState);

  @override
  String toString() {
    final id = peerIdentityId.length < 16
        ? peerIdentityId
        : '${peerIdentityId.substring(0, 8)}…';
    return 'TrustChangeEvent($id, ${newState.name})';
  }
}
