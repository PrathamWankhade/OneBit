import 'dart:typed_data';

import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_state.dart';

/// Result of a peer association operation.
enum AssociationResult {
  /// A new peer was created.
  created,

  /// An existing peer was found (no changes).
  existing,

  /// The identity matches the local identity (self).
  self,

  /// The identity data conflicts with an existing peer.
  conflict,

  /// The identity data is invalid.
  invalid,
}

/// Repository for identity persistence via Drift.
class IdentityRepository {
  IdentityRepository(this._db);

  final AppDatabase _db;

  /// Get the local identity (returns null if not created yet).
  Future<IdentityInfo?> getLocalIdentity() async {
    final row = await _db.getLocalIdentity();
    if (row == null) return null;
    return _rowToIdentityInfo(row);
  }

  /// Create a new local identity.
  Future<IdentityInfo> createLocalIdentity({
    required String displayName,
    String? publicKeyHex,
  }) async {
    final row = await _db.createLocalIdentity(
      displayName: displayName,
      publicKey: publicKeyHex,
    );
    return _rowToIdentityInfo(row);
  }

  /// Update the local identity's cryptographic material.
  Future<void> updateLocalIdentityCrypto({
    required int id,
    required String identityId,
    required String publicKeyHex,
  }) async {
    await _db.updateLocalIdentityCrypto(
      id: id,
      identityId: identityId,
      publicKey: publicKeyHex,
    );
  }

  /// Update the local identity's profile (display name and about).
  Future<void> updateLocalIdentityProfile({
    required int id,
    required String displayName,
    String? about,
  }) async {
    await _db.updateLocalIdentityProfile(
      id: id,
      displayName: displayName,
      about: about,
    );
  }

  /// Get a peer identity by ID.
  Future<PeerInfo?> getPeerIdentity(int id) async {
    final row = await _db.getPeerIdentity(id);
    if (row == null) return null;
    return _rowToPeerInfo(row);
  }

  /// Get all known peer identities.
  Future<List<PeerInfo>> getAllPeerIdentities() async {
    final rows = await _db.getAllPeerIdentities();
    return rows.map(_rowToPeerInfo).toList();
  }

  /// Get all known peers (alias for getAllPeerIdentities).
  Future<List<PeerInfo>> getAllPeers() => getAllPeerIdentities();

  /// Watch all known peer identities.
  Stream<List<PeerInfo>> watchPeerIdentities() {
    return _db.watchPeerIdentities().map(
          (rows) => rows.map(_rowToPeerInfo).toList(),
        );
  }

  /// Insert or update a peer identity.
  Future<void> upsertPeerIdentity({
    required String displayName,
    required DateTime createdAt,
    String? identityId,
    String? publicKeyHex,
    DateTime? lastSeenAt,
    String? keyAgreementPublicKeyHex,
  }) async {
    await _db.upsertPeerIdentity(
      displayName: displayName,
      createdAt: createdAt,
      identityId: identityId,
      publicKey: publicKeyHex,
      lastSeenAt: lastSeenAt,
      keyAgreementPublicKey: keyAgreementPublicKeyHex,
    );
  }

  /// Delete a peer identity.
  Future<int> deletePeerIdentity(int id) {
    return _db.deletePeerIdentity(id);
  }

  /// Rename a peer's local display name.
  ///
  /// This does not change the peer's cryptographic identity.
  Future<void> renamePeer({required int id, required String newName}) async {
    await _db.updatePeerDisplayName(id: id, displayName: newName);
  }

  /// Update a peer's X25519 key-agreement public key.
  ///
  /// The [keyAgreementPublicKeyHex] must be a valid 32-byte X25519 public key
  /// encoded as a 64-character hex string.
  Future<void> updatePeerKeyAgreementPublicKey({
    required int id,
    required String keyAgreementPublicKeyHex,
  }) async {
    await _db.updatePeerKeyAgreementPublicKey(
      id: id,
      keyAgreementPublicKey: keyAgreementPublicKeyHex,
    );
  }

  /// Update a peer's last seen BLE address.
  ///
  /// Used for identity change detection (I6.10).
  Future<void> updatePeerLastSeenBleAddress({
    required int id,
    required String? lastSeenBleAddress,
  }) async {
    await _db.updatePeerLastSeenBleAddress(
      id: id,
      lastSeenBleAddress: lastSeenBleAddress,
    );
  }

  /// Remove a peer from the local database.
  ///
  /// Returns the number of deleted rows (0 or 1).
  Future<int> removePeer(int id) {
    return _db.deletePeerIdentity(id);
  }

  /// Get a peer by its cryptographic identity ID (hex public key).
  Future<PeerInfo?> getPeerByIdentityId(String identityId) async {
    final row = await _db.getPeerIdentityByIdentityId(identityId);
    if (row == null) return null;
    return _rowToPeerInfo(row);
  }

  // ── Trust persistence (I6.8) ─────────────────────────────

  /// Load all persisted trust records from the database.
  Future<List<PeerTrust>> loadAllTrust() async {
    final records = await _db.loadAllTrust();
    return records.map(_recordToPeerTrust).toList();
  }

  /// Persist trust state for a peer.
  Future<void> savePeerTrust({
    required String peerIdentityId,
    required TrustState state,
    DateTime? verifiedAt,
    VerificationMethod? verificationMethod,
    DateTime? trustedAt,
  }) async {
    await _db.savePeerTrust(
      peerIdentityId: peerIdentityId,
      trustState: state.name,
      verifiedAt: verifiedAt,
      verificationMethod: verificationMethod?.name,
      trustedAt: trustedAt,
    );
  }

  /// Associate a public identity as a known peer.
  ///
  /// Returns the peer and the association result. If the identity matches
  /// the local identity, returns [AssociationResult.self] with null peer.
  /// If the identity already exists, returns [AssociationResult.existing].
  /// If a new peer is created, returns [AssociationResult.created].
  /// If the identity conflicts with an existing peer, returns
  /// [AssociationResult.conflict].
  Future<(PeerInfo?, AssociationResult)> findOrCreatePeer({
    required PublicIdentity publicIdentity,
    required String localPublicKeyHex,
    String? keyAgreementPublicKeyHex,
  }) async {
    final publicKeyHex = publicIdentity.publicKeyHex;

    // Check if this is the local identity
    if (publicKeyHex.toLowerCase() == localPublicKeyHex.toLowerCase()) {
      return (null, AssociationResult.self);
    }

    // Look for existing peer by identity ID
    final existing = await getPeerByIdentityId(publicKeyHex);
    if (existing != null) {
      // Validate: existing peer's public key must match
      if (existing.publicKeyHex != null &&
          existing.publicKeyHex!.toLowerCase() != publicKeyHex.toLowerCase()) {
        return (null, AssociationResult.conflict);
      }
      return (existing, AssociationResult.existing);
    }

    // Create new peer
    final now = DateTime.now();
    await _db.upsertPeerIdentity(
      displayName: publicIdentity.displayName ?? 'Unknown',
      createdAt: now,
      identityId: publicKeyHex,
      publicKey: publicKeyHex,
      keyAgreementPublicKey: keyAgreementPublicKeyHex,
    );

    final created = await getPeerByIdentityId(publicKeyHex);
    return (created, AssociationResult.created);
  }

  IdentityInfo _rowToIdentityInfo(LocalIdentityData row) {
    return IdentityInfo(
      id: row.id,
      identityId: row.identityId,
      displayName: row.displayName,
      about: row.about,
      createdAt: row.createdAt,
      publicKeyBytes: row.publicKey != null
          ? hexToBytes(row.publicKey!)
          : null,
    );
  }

  PeerInfo _rowToPeerInfo(PeerIdentity row) {
    return PeerInfo(
      id: row.id,
      identityId: row.identityId,
      publicKeyHex: row.publicKey,
      displayName: row.displayName,
      about: row.about,
      createdAt: row.createdAt,
      lastSeenAt: row.lastSeenAt,
      keyAgreementPublicKeyHex: row.keyAgreementPublicKey,
      lastSeenBleAddress: row.lastSeenBleAddress,
    );
  }

  PeerTrust _recordToPeerTrust(PeerTrustRecord record) {
    return PeerTrust(
      peerIdentityId: record.peerIdentityId,
      state: TrustState.values.firstWhere(
        (s) => s.name == record.trustState,
        orElse: () => TrustState.unknown,
      ),
      verifiedAt: record.verifiedAt,
      verificationMethod: record.verificationMethod != null
          ? VerificationMethod.values.firstWhere(
              (m) => m.name == record.verificationMethod,
              orElse: () => VerificationMethod.qrScan,
            )
          : null,
      trustedAt: record.trustedAt,
    );
  }

  /// Convert hex string to bytes.
  static Uint8List hexToBytes(String hex) {
    final buffer = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      buffer[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return buffer;
  }

  /// Convert bytes to hex string.
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
