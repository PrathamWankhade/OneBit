import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [SignData].
final class SignDataParams {
  const SignDataParams(this.message);

  /// Arbitrary bytes to sign (UTF-8 for strings).
  final List<int> message;
}

/// Result of a signing operation.
final class SignedData {
  const SignedData({required this.signature, required this.publicKey});

  /// 64-byte Ed25519 signature.
  final List<int> signature;

  /// 32-byte Ed25519 public key of the signer (this node).
  final List<int> publicKey;
}

/// Signs a payload with the node identity's signing key.
final class SignData extends UseCase<SignDataParams, Result<SignedData>> {
  const SignData(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<SignedData>> call(SignDataParams params) async {
    final identityResult = await _repository.loadIdentity();
    if (identityResult.isErr) {
      return Err(identityResult.failure!);
    }
    final identity = identityResult.value;
    if (identity == null) {
      return const Err(
        IdentityFailure(
          code: 'not_created',
          message: 'Identity does not exist yet',
        ),
      );
    }
    final signature = await _repository.sign(params.message);
    return signature.fold(
      (bytes) => Ok(
        SignedData(signature: bytes, publicKey: identity.ed25519PublicKey),
      ),
      Err<SignedData>.new,
    );
  }
}
