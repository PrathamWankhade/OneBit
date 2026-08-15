import 'package:onebit/core/crypto/verification/verification_code.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [DeriveVerificationCode].
final class DeriveVerificationCodeParams {
  const DeriveVerificationCodeParams(this.theirFingerprintHex);

  /// 64-character lowercase hex fingerprint of the peer to verify.
  final String theirFingerprintHex;
}

/// Derives the six-digit out-of-band verification code for a peer.
///
/// The peer derives the same code from our fingerprint, so both sides can
/// compare the code over a separate channel (voice, paper, SMS).
final class DeriveVerificationCode
    extends UseCase<DeriveVerificationCodeParams, Result<VerificationCode>> {
  const DeriveVerificationCode(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<VerificationCode>> call(
    DeriveVerificationCodeParams params,
  ) async {
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
    return Result.captureAsync(() {
      return VerificationCode.derive(
        ourFingerprintHex: identity.fingerprintHex,
        theirFingerprintHex: params.theirFingerprintHex,
      );
    });
  }
}
