import 'dart:typed_data';

import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_seeds.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';

/// Repository contract for the node's own identity.
///
/// The repository is the *only* component that owns the private seeds: it
/// loads them from the Keystore vault per operation and never stores them in
/// identity models. All symmetric/transit operations (sign, ECDH) go through
/// these methods so presentation code never sees key material.
abstract interface class IdentityRepository {
  /// Loads the current identity, or `null` when none was created yet.
  ///
  /// A fresh install (no vault entry and no metadata record), a partially
  /// restored backup, and a corrupt vault are distinguished via failure
  /// codes rather than lumped together.
  Future<Result<NodeIdentity?>> loadIdentity();

  /// Generates a brand-new identity (two fresh key pairs) and persists it.
  ///
  /// The signing and exchange seeds are wrapped into the Keystore vault
  /// immediately; only public material + profile metadata are returned.
  Future<Result<NodeIdentity>> createIdentity({
    required String displayName,
    required int avatarColor,
  });

  /// Persists [profile] and returns the updated identity.
  Future<Result<NodeIdentity>> updateProfile(UserProfile profile);

  /// Clears the identity (vault + metadata). Idempotent.
  Future<Result<void>> deleteIdentity();

  /// Ed25519- signs [message] with the identity's signing seed.
  Future<Result<Uint8List>> sign(List<int> message);

  /// Verifies a 64-byte Ed25519 [signature] over [message] with [publicKey].
  Future<Result<bool>> verify({
    required List<int> publicKey,
    required List<int> message,
    required List<int> signature,
  });

  /// Computes the X25519 shared secret with [remotePublicKey] using the
  /// identity's exchange seed (used to seal/open QR identity transfers).
  Future<Result<Uint8List>> sharedSecret(List<int> remotePublicKey);

  /// Materializes the private seeds from the vault for a single operation.
  ///
  /// Only required by flows that must move key material (QR identity
  /// transfer sealing, backup export). Callers must not retain the result.
  Future<Result<IdentitySeeds>> loadSeeds();

  /// Exports the identity (seeds, profile, contacts) as an encrypted
  /// backup document string, protected by [passphrase].
  Future<Result<String>> exportBackup({required String passphrase});

  /// Restores an identity from a backup [document], re-wrapping the seeds
  /// into the Keystore vault.
  Future<Result<NodeIdentity>> importBackup({
    required String passphrase,
    required String document,
  });
}
