import 'package:cryptography/cryptography.dart';

/// Ed25519 public-key derivation that depends on nothing but the
/// cryptography package, so the database migration can reach it without
/// pulling in the identity layer (which pulls the database back).
///
/// It exists because of one mistake worth naming: a `SimpleKeyPair`'s
/// `extract().bytes` is the **private seed**, not the public key, and
/// `extractPublicKey()` is the only way to get the other half. Hex-encode
/// the wrong one and the secret is published — which is what the app did
/// with `identityId` until this landed.

/// The hex characters of the Ed25519 public key that [seedHex] holds.
///
/// Returns null when [seedHex] is not a 32-byte hex value, so callers can
/// tell "this is a seed" apart from "this is not one" instead of
/// guessing. A wrong guess here would either publish a secret or quietly
/// replace an identity with one nobody holds.
Future<String?> ed25519PublicKeyHex(String seedHex) async {
  if (seedHex.length != 64 || !_hexPattern.hasMatch(seedHex)) return null;

  final seed = _hexToBytes(seedHex);
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  final public = await keyPair.extractPublicKey();
  return _toHex(public.bytes);
}

final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');

List<int> _hexToBytes(String hex) {
  final out = List<int>.filled(hex.length ~/ 2, 0);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
