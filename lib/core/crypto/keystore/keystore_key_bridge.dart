import 'dart:typed_data';

import 'package:onebit/core/result/result.dart';

/// Contract for the Android Keystore-backed identity seed vault.
///
/// The device never stores identity seeds in plaintext: Kotlin wraps each
/// 32-byte seed with a hardware-backed AES-GCM key that stays inside the
/// Android Keystore, then persists only the wrapped blob (plus a UTF-8
/// version marker). Dart receives the seed only for the lifetime of a single
/// signing/key-agreement call.
abstract interface class KeystoreKeyBridge {
  /// The platform channel this bridge targets.
  String get channelName;

  /// Wraps [seed] with the Keystore AES key and persists it under [alias].
  Future<Result<void>> storeSeed({
    required String alias,
    required Uint8List seed,
  });

  /// Unwraps and returns the seed stored under [alias].
  ///
  /// Resolves to an [IdentityFailure] (`key_not_found`) when the alias does
  /// not exist, so callers can distinguish "cold start" from corruption.
  Future<Result<Uint8List>> loadSeed({required String alias});

  /// True when a wrapped seed exists under [alias].
  Future<Result<bool>> hasIdentity({required String alias});

  /// Permanently removes the seed stored under [alias] from the vault.
  Future<Result<void>> deleteIdentity({required String alias});
}
