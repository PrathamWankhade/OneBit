import 'dart:typed_data';

import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/use_cases/repository_bridge_failure.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Builds the signed identity card QR payload for this node.
///
/// The card carries only public material (`id`,`fp`,`ed`,`x`) plus an
/// Ed25519 signature; scanning it lets a peer trust the contact data.
final class BuildIdentityCard extends UseCase<NoParams, Result<String>> {
  const BuildIdentityCard(this._repository);

  final IdentityRepository _repository;

  @override
  Future<Result<String>> call(NoParams params) async {
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
    try {
      final card = QrIdentityCard(
        nodeId: identity.nodeId.value,
        displayName: identity.profile.displayName,
        fingerprintHex: identity.fingerprintHex,
        ed25519PublicKey: identity.ed25519PublicKey,
        x25519PublicKey: identity.x25519PublicKey,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        signature: Uint8List(0),
      );
      final text = await QrPayloadCodec.encodeCard(card, signer: _signer);
      return Ok(text);
    } on RepositoryBridgeFailure catch (failure) {
      return Err(failure.failure);
    }
  }

  Future<Uint8List> _signer(List<int> message) async {
    final result = await _repository.sign(message);
    if (result.isErr) {
      throw RepositoryBridgeFailure(result.failure!);
    }
    return result.value!;
  }
}
