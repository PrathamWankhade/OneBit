import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/backup/backup_cipher.dart';
import 'package:onebit/core/crypto/backup/backup_format.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/identity_crypto.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/crypto/keystore/keystore_key_bridge.dart';
import 'package:onebit/core/crypto/keystore/keystore_providers.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/utils/secure_random_util.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/identity_seeds.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/trust_contact_repository.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [IdentityRepository] backed by the Keystore vault + `SharedPreferences`.
///
/// Private seeds live in the vault (hardware-wrapped at rest); this class
/// only persists *public* metadata (uuid, fingerprint, public keys, profile)
/// in preferences and materializes seeds transiently per operation.
final class IdentityRepositoryImpl implements IdentityRepository {
  const IdentityRepositoryImpl({
    required this._vault,
    required this._prefs,
    required this._logger,
    this._contacts,
  });

  final KeystoreKeyBridge _vault;
  final SharedPreferencesAsync _prefs;
  final AppLogger _logger;
  final TrustContactRepository? _contacts;

  static const int _metadataVersion = 1;

  String get _metadataKey => '${IdentityVault.prefsKeyPrefix}.metadata';

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  @override
  Future<Result<NodeIdentity?>> loadIdentity() async {
    final raw = await _prefs.getString(_metadataKey);
    if (raw == null) {
      return const Ok(null);
    }
    try {
      final fields = (jsonDecode(raw) as Map).cast<String, Object?>();
      final complete = await _vaultComplete();
      if (complete.isErr) {
        return Err(complete.failure!);
      }
      if (!complete.value!) {
        return const Err(
          IdentityFailure(
            code: 'vault_missing',
            message: 'Identity metadata exists but the Keystore vault is empty',
          ),
        );
      }
      return Ok(_identityFromJson(fields));
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Failed to parse identity metadata',
        tag: LogTags.identity,
        error: error,
        stackTrace: stackTrace,
      );
      return Err(
        IdentityFailure(
          code: 'metadata_corrupt',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<NodeIdentity>> createIdentity({
    required String displayName,
    required int avatarColor,
  }) async {
    final existing = await loadIdentity();
    if (existing.isErr) {
      return Err(existing.failure!);
    }
    if (existing.value != null) {
      return const Err(
        IdentityFailure(
          code: 'already_exists',
          message: 'An identity already exists on this device',
        ),
      );
    }
    final uuid = SecureRandomUtil.uuidV4();
    final createdAt = DateTime.now().toUtc();
    final edSeed = SecureRandomUtil.randomBytes(32);
    final xSeed = SecureRandomUtil.randomBytes(32);

    final edPublic = await _captureCrypto(
      () => IdentityCrypto.publicKeyFromSeed(edSeed),
      'derive ed25519 public key',
    );
    if (edPublic.isErr) {
      return Err(edPublic.failure!);
    }
    final xPublic = await _captureCrypto(
      () => ExchangeCrypto.publicKeyFromSeed(xSeed),
      'derive x25519 public key',
    );
    if (xPublic.isErr) {
      return Err(xPublic.failure!);
    }
    final fingerprint = await Fingerprint.fromPublicKey(edPublic.value!);
    final profile = UserProfile(
      displayName: displayName,
      avatarColor: avatarColor,
    );

    final stored = await _storeSeeds(edSeed, xSeed);
    if (stored.isErr) {
      return Err(stored.failure!);
    }
    final persisted = await _saveMetadata(
      NodeIdentity(
        uuid: uuid,
        nodeId: NodeId.fromFingerprintHex(fingerprint.hex),
        fingerprint: fingerprint,
        ed25519PublicKey: edPublic.value!,
        x25519PublicKey: xPublic.value!,
        profile: profile,
        createdAt: createdAt,
      ),
    );
    if (persisted.isErr) {
      return Err(persisted.failure!);
    }
    _logger.info(
      'Identity created: ${persisted.value!.nodeId}',
      tag: LogTags.identity,
    );
    return persisted;
  }

  @override
  Future<Result<NodeIdentity>> updateProfile(UserProfile profile) async {
    final current = await loadIdentity();
    if (current.isErr) {
      return Err(current.failure!);
    }
    final identity = current.value;
    if (identity == null) {
      return const Err(
        IdentityFailure(
          code: 'not_created',
          message: 'Identity does not exist yet',
        ),
      );
    }
    final updated = NodeIdentity(
      uuid: identity.uuid,
      nodeId: identity.nodeId,
      fingerprint: identity.fingerprint,
      ed25519PublicKey: identity.ed25519PublicKey,
      x25519PublicKey: identity.x25519PublicKey,
      profile: profile,
      createdAt: identity.createdAt,
    );
    return _saveMetadata(updated);
  }

  @override
  Future<Result<void>> deleteIdentity() async {
    final removed = await _vault.deleteIdentity(alias: IdentityVault.alias);
    if (removed.isErr) {
      return Err(removed.failure!);
    }
    final removedExchange = await _vault.deleteIdentity(
      alias: IdentityVault.exchangeAlias,
    );
    if (removedExchange.isErr) {
      return Err(removedExchange.failure!);
    }
    await _prefs.remove(_metadataKey);
    _logger.info('Identity deleted', tag: LogTags.identity);
    return const Ok(null);
  }

  // ------------------------------------------------------------------
  // Crypto operations
  // ------------------------------------------------------------------

  @override
  Future<Result<Uint8List>> sign(List<int> message) async {
    final seeds = await loadSeeds();
    if (seeds.isErr) {
      return Err(seeds.failure!);
    }
    return _captureCrypto(
      () => IdentityCrypto.sign(
        seed: Uint8List.fromList(seeds.value!.ed25519Seed),
        message: message,
      ),
      'ed25519 sign',
    );
  }

  @override
  Future<Result<bool>> verify({
    required List<int> publicKey,
    required List<int> message,
    required List<int> signature,
  }) {
    return _captureCrypto(
      () => IdentityCrypto.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      ),
      'ed25519 verify',
    );
  }

  @override
  Future<Result<Uint8List>> sharedSecret(List<int> remotePublicKey) async {
    final seeds = await loadSeeds();
    if (seeds.isErr) {
      return Err(seeds.failure!);
    }
    return _captureCrypto(
      () => ExchangeCrypto.sharedSecret(
        keyPairSeed: Uint8List.fromList(seeds.value!.x25519Seed),
        remotePublicKey: remotePublicKey,
      ),
      'x25519 shared secret',
    );
  }

  @override
  Future<Result<IdentitySeeds>> loadSeeds() async {
    final identity = await loadIdentity();
    if (identity.isErr) {
      return Err(identity.failure!);
    }
    if (identity.value == null) {
      return const Err(
        IdentityFailure(
          code: 'not_created',
          message: 'Identity does not exist yet',
        ),
      );
    }
    final ed = await _vault.loadSeed(alias: IdentityVault.alias);
    if (ed.isErr) {
      return Err(ed.failure!);
    }
    final x = await _vault.loadSeed(alias: IdentityVault.exchangeAlias);
    if (x.isErr) {
      return Err(x.failure!);
    }
    return Ok(IdentitySeeds(ed25519Seed: ed.value!, x25519Seed: x.value!));
  }

  // ------------------------------------------------------------------
  // Backup
  // ------------------------------------------------------------------

  @override
  Future<Result<String>> exportBackup({required String passphrase}) async {
    final identity = await loadIdentity();
    if (identity.isErr) {
      return Err(identity.failure!);
    }
    final node = identity.value;
    if (node == null) {
      return const Err(
        IdentityFailure(
          code: 'not_created',
          message: 'Identity does not exist yet',
        ),
      );
    }
    final seeds = await loadSeeds();
    if (seeds.isErr) {
      return Err(seeds.failure!);
    }
    final contactsResult = _contacts == null
        ? Result.capture<List<TrustContact>>(() => <TrustContact>[])
        : await _contacts.loadContacts();
    if (contactsResult.isErr) {
      return Err(contactsResult.failure!);
    }
    final plaintext = <String, Object?>{
      'v': _metadataVersion,
      'uuid': node.uuid,
      'nodeId': node.nodeId.value,
      'fp': node.fingerprintHex,
      'createdAt': node.createdAt.toIso8601String(),
      'profile': node.profile.toJson(),
      'seed': _b64(seeds.value!.ed25519Seed),
      'xseed': _b64(seeds.value!.x25519Seed),
      'contacts': contactsResult.value!.map((c) => c.toJson()).toList(),
    };
    final aad = BackupAad(
      nodeId: node.nodeId.value,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final envelope = await BackupCipher.encrypt(
      passphrase: passphrase,
      plaintext: plaintext,
      aad: aad,
    );
    if (envelope.isErr) {
      return Err(envelope.failure!);
    }
    final document = BackupFormat.encodeDocument(envelope.value!);
    _logger.info('Backup exported', tag: LogTags.identity);
    return Ok(document);
  }

  @override
  Future<Result<NodeIdentity>> importBackup({
    required String passphrase,
    required String document,
  }) async {
    final BackupEnvelope envelope;
    try {
      envelope = BackupFormat.decodeDocument(document);
    } on Object catch (error, stackTrace) {
      return Err(
        BackupFailure(
          operation: 'parse',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    final plaintext = await BackupCipher.decrypt(
      passphrase: passphrase,
      envelope: envelope,
    );
    if (plaintext.isErr) {
      return Err(plaintext.failure!);
    }
    final fields = plaintext.value!;
    try {
      final edSeed = _unb64(fields['seed']! as String);
      final xSeed = _unb64(fields['xseed']! as String);
      final nodeId = NodeId.parse(fields['nodeId']! as String);
      final fingerprintHex = (fields['fp']! as String).toLowerCase();
      final uuid = fields['uuid']! as String;
      final createdAt =
          DateTime.tryParse(fields['createdAt']! as String) ??
          DateTime.now().toUtc();
      final profile = UserProfile.fromJson(
        (fields['profile']! as Map).cast<String, Object?>(),
      );

      final edPublic = await IdentityCrypto.publicKeyFromSeed(edSeed);
      final derivedFingerprint = await Fingerprint.fromPublicKey(edPublic);
      if (derivedFingerprint.hex != fingerprintHex ||
          NodeId.fromFingerprintHex(fingerprintHex) != nodeId) {
        return const Err(
          BackupFailure(
            operation: 'import',
            message: 'Backup identity does not match its fingerprint',
          ),
        );
      }
      final xPublic = await ExchangeCrypto.publicKeyFromSeed(xSeed);

      final stored = await _storeSeeds(edSeed, xSeed);
      if (stored.isErr) {
        return Err(stored.failure!);
      }
      final identity = NodeIdentity(
        uuid: uuid,
        nodeId: nodeId,
        fingerprint: Fingerprint.fromHex(fingerprintHex),
        ed25519PublicKey: edPublic,
        x25519PublicKey: xPublic,
        profile: profile,
        createdAt: createdAt,
      );
      final saved = await _saveMetadata(identity);
      if (saved.isErr) {
        return Err(saved.failure!);
      }
      await _restoreContacts(fields['contacts']);
      _logger.info(
        'Backup imported: ${identity.nodeId}',
        tag: LogTags.identity,
      );
      return saved;
    } on Object catch (error, stackTrace) {
      return Err(
        BackupFailure(
          operation: 'import',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<Result<void>> _storeSeeds(Uint8List edSeed, Uint8List xSeed) async {
    final ed = await _vault.storeSeed(alias: IdentityVault.alias, seed: edSeed);
    if (ed.isErr) {
      return Err(ed.failure!);
    }
    final x = await _vault.storeSeed(
      alias: IdentityVault.exchangeAlias,
      seed: xSeed,
    );
    if (x.isErr) {
      return Err(x.failure!);
    }
    return const Ok(null);
  }

  Future<Result<bool>> _vaultComplete() async {
    final ed = await _vault.hasIdentity(alias: IdentityVault.alias);
    if (ed.isErr) {
      return Err(ed.failure!);
    }
    final x = await _vault.hasIdentity(alias: IdentityVault.exchangeAlias);
    if (x.isErr) {
      return Err(x.failure!);
    }
    return Ok(ed.value! && x.value!);
  }

  Future<Result<NodeIdentity>> _saveMetadata(NodeIdentity identity) async {
    try {
      final payload = jsonEncode({
        'v': _metadataVersion,
        'uuid': identity.uuid,
        'nodeId': identity.nodeId.value,
        'fp': identity.fingerprintHex,
        'createdAt': identity.createdAt.toIso8601String(),
        'ed': _b64(identity.ed25519PublicKey),
        'x': _b64(identity.x25519PublicKey),
        'profile': identity.profile.toJson(),
      });
      await _prefs.setString(_metadataKey, payload);
      return Ok(identity);
    } on Object catch (error, stackTrace) {
      return Err(
        StorageFailure(
          operation: 'setString',
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  NodeIdentity _identityFromJson(Map<String, Object?> fields) {
    final fingerprintHex = (fields['fp']! as String).toLowerCase();
    return NodeIdentity(
      uuid: fields['uuid']! as String,
      nodeId: NodeId.parse(fields['nodeId']! as String),
      fingerprint: Fingerprint.fromHex(fingerprintHex),
      ed25519PublicKey: _unb64(fields['ed']! as String),
      x25519PublicKey: _unb64(fields['x']! as String),
      profile: UserProfile.fromJson(
        (fields['profile']! as Map).cast<String, Object?>(),
      ),
      createdAt:
          DateTime.tryParse(fields['createdAt']! as String) ??
          DateTime.now().toUtc(),
    );
  }

  Future<void> _restoreContacts(Object? contactsJson) async {
    final repo = _contacts;
    if (repo == null || contactsJson is! List) {
      return;
    }
    for (final entry in contactsJson) {
      if (entry is Map) {
        await repo.upsert(TrustContact.fromJson(entry.cast<String, Object?>()));
      }
    }
  }

  Future<Result<T>> _captureCrypto<T>(
    Future<T> Function() body,
    String operation,
  ) async {
    try {
      return Ok(await body());
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Crypto $operation failed',
        tag: LogTags.identity,
        error: error,
      );
      return Err(
        CryptoFailure(
          operation: operation,
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String encoded) {
    final padding = (4 - encoded.length % 4) % 4;
    return Uint8List.fromList(
      base64Url.decode(encoded.padRight(encoded.length + padding, '=')),
    );
  }
}
