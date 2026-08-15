import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [EncodeIdentityTransfer].
final class EncodeIdentityTransferParams {
  const EncodeIdentityTransferParams(this.recipientPublicKey);

  /// 32-byte X25519 public key of the receiving node.
  final List<int> recipientPublicKey;
}

/// Seals this node's identity (seeds included) for transfer to another
/// device via a QR code. Only [recipientPublicKey]'s owner can open it.
final class EncodeIdentityTransfer
    extends UseCase<EncodeIdentityTransferParams, Result<String>> {
  const EncodeIdentityTransfer(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<String>> call(EncodeIdentityTransferParams params) async {
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
    final seedsResult = await _repository.loadSeeds();
    if (seedsResult.isErr) {
      return Err(seedsResult.failure!);
    }
    final seeds = seedsResult.value!;
    final content = QrTransferContent(
      nodeId: identity.nodeId.value,
      displayName: identity.profile.displayName,
      fingerprintHex: identity.fingerprintHex,
      ed25519Seed: seeds.ed25519Seed,
      x25519Seed: seeds.x25519Seed,
    );
    final text = await QrPayloadCodec.encodeTransfer(
      content,
      recipientPublicKey: params.recipientPublicKey,
    );
    return Ok(text);
  }
}
