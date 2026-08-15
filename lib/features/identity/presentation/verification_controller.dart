import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/crypto/verification/verification_code.dart';
import 'package:onebit/features/identity/domain/use_cases/derive_verification_code.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';

/// Owns out-of-band verification code derivation for a peer.
///
/// The peer derives the identical code from *our* fingerprint, so both
/// parties can compare the six digits over a separate channel.
final AsyncNotifierProvider<VerificationController, VerificationCode?>
verificationControllerProvider =
    AsyncNotifierProvider<VerificationController, VerificationCode?>(
      VerificationController.new,
    );

final class VerificationController extends AsyncNotifier<VerificationCode?> {
  @override
  Future<VerificationCode?> build() async => null;

  /// Computes the mutual code for [theirFingerprintHex].
  Future<void> compute(String theirFingerprintHex) async {
    final result = await ref
        .read(deriveVerificationCodeProvider)
        .call(DeriveVerificationCodeParams(theirFingerprintHex));
    if (result.isErr) {
      throw result.failure!;
    }
    state = AsyncData(result.value);
  }

  /// Clears the current code.
  void clear() => state = const AsyncData(null);
}
