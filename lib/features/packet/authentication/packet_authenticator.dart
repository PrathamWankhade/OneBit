import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

/// Sign/verify boundary for packet authentication.
///
/// This phase defines only the interface and a no-op default. Signing is a
/// pure transformation over the packet's canonical bytes (everything before
/// the signature trailer), so a real crypto implementation can land later
/// without a wire-format change.
abstract interface class PacketAuthenticator {
  /// True when a real signer is installed (the [NoopAuthenticator] returns
  /// false) — lets callers skip work that cannot succeed.
  bool get isAvailable;

  /// Produces a signature over [canonicalBytes], or an `Err` when no signer
  /// is available.
  Future<Result<List<int>>> sign({required List<int> canonicalBytes});

  /// Verifies [signature] over [canonicalBytes]; adopts `Ok(false)` for a
  /// mismatch and `Err` when no verifier is available.
  Future<Result<bool>> verify({
    required List<int> canonicalBytes,
    required List<int> signature,
  });
}

/// The shipped default: no signing, and verification only accepts an empty
/// signature (anonymous, unauthenticated traffic).
final class NoopPacketAuthenticator implements PacketAuthenticator {
  const NoopPacketAuthenticator();

  @override
  bool get isAvailable => false;

  @override
  Future<Result<List<int>>> sign({required List<int> canonicalBytes}) async {
    return const Err(
      UnsupportedOperationFailure(
        feature: 'packet.crypto',
        message: 'no signer installed in this build',
      ),
    );
  }

  @override
  Future<Result<bool>> verify({
    required List<int> canonicalBytes,
    required List<int> signature,
  }) async {
    if (signature.isEmpty) return const Ok(true);
    return const Err(
      UnsupportedOperationFailure(
        feature: 'packet.verify',
        message: 'no verifier installed in this build',
      ),
    );
  }
}
