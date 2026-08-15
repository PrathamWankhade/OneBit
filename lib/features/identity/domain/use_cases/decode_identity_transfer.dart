import 'dart:typed_data';

import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/use_cases/repository_bridge_failure.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [DecodeIdentityTransfer].
final class DecodeIdentityTransferParams {
  const DecodeIdentityTransferParams(this.text);

  /// The scanned `OB1:` wire text.
  final String text;
}

/// Opens an identity transfer addressed to this node.
///
/// Uses our exchange key (from the vault) to derive the ECDH secret against
/// the ephemeral key embedded in the envelope; a wrong recipient or tampered
/// document fails authentication.
final class DecodeIdentityTransfer
    extends UseCase<DecodeIdentityTransferParams, Result<QrTransferContent>> {
  const DecodeIdentityTransfer(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<QrTransferContent>> call(
    DecodeIdentityTransferParams params,
  ) async {
    try {
      final content = await QrPayloadCodec.decodeTransfer(
        params.text,
        sharedSecretProvider: _sharedSecretProvider,
      );
      return Ok(content);
    } on RepositoryBridgeFailure catch (failure) {
      return Err(failure.failure);
    }
  }

  Future<Uint8List> _sharedSecretProvider(List<int> remotePublicKey) async {
    final result = await _repository.sharedSecret(remotePublicKey);
    if (result.isErr) {
      throw RepositoryBridgeFailure(result.failure!);
    }
    return result.value!;
  }
}
