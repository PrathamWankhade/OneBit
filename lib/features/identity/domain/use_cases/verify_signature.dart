import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [VerifySignature].
final class VerifySignatureParams {
  const VerifySignatureParams({
    required this.publicKey,
    required this.message,
    required this.signature,
  });

  /// 32-byte Ed25519 public key of the alleged signer.
  final List<int> publicKey;

  /// The bytes that were signed.
  final List<int> message;

  /// 64-byte signature to check.
  final List<int> signature;
}

/// Verifies an Ed25519 signature against arbitrary key material.
///
/// True when [signature] is valid for [message] under [publicKey]; false
/// (never an error) when it is not. Malformed key material surfaces as a
/// failure.
final class VerifySignature
    extends UseCase<VerifySignatureParams, Result<bool>> {
  const VerifySignature(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<bool>> call(VerifySignatureParams params) {
    return _repository.verify(
      publicKey: params.publicKey,
      message: params.message,
      signature: params.signature,
    );
  }
}
