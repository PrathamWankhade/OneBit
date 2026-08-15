import 'package:flutter/foundation.dart';

/// The two private seeds of an identity, materialized transiently.
///
/// **Sensitive.** Instances must never be stored in state, logged, or kept
/// longer than the single operation they serve (QR transfer sealing, backup
/// export). The repository loads them from the vault and they die with the
/// operation.
@immutable
final class IdentitySeeds {
  const IdentitySeeds({required this.ed25519Seed, required this.x25519Seed});

  /// 32-byte Ed25519 signing seed.
  final List<int> ed25519Seed;

  /// 32-byte X25519 key-agreement seed.
  final List<int> x25519Seed;

  @override
  String toString() =>
      'IdentitySeeds(ed:${ed25519Seed.length}B, x:${x25519Seed.length}B)';
}
