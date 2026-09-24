import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/identity/private_key_store.dart';

/// Ed25519 seed must be exactly 32 bytes.
const int _kEd25519SeedLength = 32;

/// Service for identity lifecycle management.
///
/// Handles Ed25519 key generation, identity persistence, and private key storage.
/// Public metadata is stored in Drift; private key material is stored via
/// [PrivateKeyStore] which uses platform-backed secure storage.
///
/// ## Identity lifecycle guarantees
///
/// - At most one local identity can exist. [createIdentity] is guarded
///   against duplicate creation.
/// - [initialize] validates consistency between the stored public key
///   and the reconstructed key pair. A mismatch is treated as corruption
///   and throws [IdentityCorruptionException].
/// - Private key bytes must be exactly 32 bytes (Ed25519 seed).
/// - Identity must survive app restarts, process death, force stop,
///   hot restart, provider rebuild, and app updates without regeneration.
class IdentityService {
  IdentityService(this._repository, this._privateKeyStore);

  final IdentityRepository _repository;
  final PrivateKeyStore _privateKeyStore;

  IdentityInfo? _localIdentity;
  SimpleKeyPair? _keyPair;
  bool _initialized = false;

  /// The current local identity metadata.
  IdentityInfo? get localIdentity => _localIdentity;

  /// Whether a local identity has been loaded.
  bool get hasIdentity => _localIdentity != null;

  /// The current Ed25519 key pair (in-memory after creation or initialize).
  SimpleKeyPair? get keyPair => _keyPair;

  /// Initialize identity from stored metadata and private key.
  ///
  /// Returns true if identity exists and was loaded, false if no identity exists.
  ///
  /// Throws [PrivateKeyStoreException] if the private key is missing from
  /// secure storage.
  /// Throws [IdentityCorruptionException] if the stored identity is
  /// inconsistent (missing crypto material, private key length invalid,
  /// or reconstructed public key does not match stored public key).
  Future<bool> initialize() async {
    if (_initialized) {
      AppLogger.info('Identity already initialized');
      return _localIdentity != null;
    }

    final stored = await _repository.getLocalIdentity();
    if (stored == null) {
      AppLogger.info('No stored identity found');
      _initialized = true;
      return false;
    }

    // Validate that we have the required cryptographic material
    if (stored.identityId == null || stored.publicKeyBytes == null) {
      AppLogger.warning('Identity exists but missing cryptographic material');
      throw IdentityCorruptionException(
        'Identity exists but missing cryptographic material',
      );
    }

    // Load private key from secure storage
    final privateKeyBytes = await _privateKeyStore.read();
    if (privateKeyBytes == null) {
      AppLogger.warning('Private key missing from secure storage');
      throw PrivateKeyStoreException('Private key missing');
    }

    // Validate private key length
    if (privateKeyBytes.length != _kEd25519SeedLength) {
      AppLogger.warning(
        'Private key has invalid length: ${privateKeyBytes.length} '
        '(expected $_kEd25519SeedLength)',
      );
      throw IdentityCorruptionException(
        'Private key has invalid length: ${privateKeyBytes.length}',
      );
    }

    // Reconstruct key pair from stored private key
    final algorithm = Ed25519();
    _keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);

    // Verify consistency: reconstructed public key must match stored public key
    final reconstructedPublic = await _keyPair!.extract();
    final reconstructedHex = IdentityRepository.bytesToHex(
      Uint8List.fromList(reconstructedPublic.bytes),
    );
    if (reconstructedHex.toLowerCase() != stored.identityId!.toLowerCase()) {
      AppLogger.warning('Identity integrity check failed: public key mismatch');
      throw IdentityCorruptionException(
        'Public key mismatch between stored identity and private key',
      );
    }

    _localIdentity = stored;
    _initialized = true;
    AppLogger.info('Identity loaded');
    return true;
  }

  /// Create a new identity with the given display name.
  ///
  /// Generates an Ed25519 key pair, stores the private key securely,
  /// and persists public metadata in Drift.
  ///
  /// Throws [StateError] if an identity already exists.
  Future<IdentityInfo> createIdentity(String displayName) async {
    // Guard: do not create if identity already exists
    if (_localIdentity != null) {
      AppLogger.warning('Cannot create identity: identity already exists');
      throw StateError('Identity already exists');
    }

    AppLogger.info('Creating new identity');

    // Generate Ed25519 key pair
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extract();

    // Get raw public key bytes
    final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

    // Get raw private key bytes for secure storage
    final privateKeyData = await keyPair.extract();
    final privateKeyBytes = Uint8List.fromList(privateKeyData.bytes);

    // Derive identity ID from public key (hex-encoded)
    final identityId = IdentityRepository.bytesToHex(publicKeyBytes);

    // Store private key securely BEFORE persisting public metadata
    // This ensures we don't have a broken identity if storage fails
    await _privateKeyStore.write(privateKeyBytes);

    // Persist identity metadata (public key only)
    final identity = await _repository.createLocalIdentity(
      displayName: displayName,
      publicKeyHex: identityId,
    );

    // Update with crypto fields
    await _repository.updateLocalIdentityCrypto(
      id: identity.id,
      identityId: identityId,
      publicKeyHex: identityId,
    );

    // Keep key pair in memory for immediate use
    _keyPair = keyPair;

    // Update local state
    _localIdentity = IdentityInfo(
      id: identity.id,
      identityId: identityId,
      displayName: identity.displayName,
      createdAt: identity.createdAt,
      publicKeyBytes: publicKeyBytes,
    );

    _initialized = true;
    AppLogger.info('Identity created');
    return _localIdentity!;
  }

  /// Get the current public key bytes (if identity exists).
  Uint8List? get publicKeyBytes => _localIdentity?.publicKeyBytes;

  /// Get the current identity ID (if identity exists).
  String? get identityId => _localIdentity?.identityId;

  /// Associate a public identity as a known peer.
  ///
  /// Returns the peer and the association result. If the identity matches
  /// the local identity, returns [AssociationResult.self] with null peer.
  /// If the identity already exists, returns [AssociationResult.existing].
  /// If a new peer is created, returns [AssociationResult.created].
  Future<(PeerInfo?, AssociationResult)> associatePeer(
    PublicIdentity publicIdentity,
  ) async {
    final localKey = identityId;
    if (localKey == null) {
      AppLogger.warning('Cannot associate peer: no local identity');
      return (null, AssociationResult.invalid);
    }

    final (peer, result) = await _repository.findOrCreatePeer(
      publicIdentity: publicIdentity,
      localPublicKeyHex: localKey,
    );

    switch (result) {
      case AssociationResult.created:
        AppLogger.info('Peer created');
      case AssociationResult.existing:
        AppLogger.info('Peer already known');
      case AssociationResult.self:
        AppLogger.info('Self identity scanned');
      case AssociationResult.conflict:
        AppLogger.warning('Identity conflict');
      case AssociationResult.invalid:
        AppLogger.warning('Invalid identity for association');
    }

    return (peer, result);
  }
}

/// Exception for identity corruption or inconsistency.
///
/// Thrown when the stored identity is inconsistent: missing crypto material,
/// private key length invalid, or reconstructed public key does not match
/// stored public key. The caller must handle this explicitly and should
/// never auto-generate a replacement identity.
class IdentityCorruptionException implements Exception {
  IdentityCorruptionException(this.message);
  final String message;

  @override
  String toString() => 'IdentityCorruptionException: $message';
}
