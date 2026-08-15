import 'dart:typed_data';

import 'package:onebit/core/crypto/identity/identity_crypto.dart';
import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Parameters for [DecodeIdentityCard].
final class DecodeIdentityCardParams {
  const DecodeIdentityCardParams(this.text);

  /// The scanned `OB1:` wire text.
  final String text;
}

/// Parses and authenticates a scanned identity card.
///
/// The signature is checked against the card's own `ed` key (pure crypto —
/// no secrets or storage involved), so tampered or wrong-key cards fail.
final class DecodeIdentityCard
    extends UseCase<DecodeIdentityCardParams, Result<QrIdentityCard>> {
  const DecodeIdentityCard();

  @override
  Future<Result<QrIdentityCard>> call(DecodeIdentityCardParams params) {
    return Result.captureAsync(() async {
      final card = await QrPayloadCodec.decodeCard(
        params.text,
        verifier: _verify,
      );
      return card;
    });
  }

  static Future<bool> _verify(
    List<int> message,
    Uint8List signature,
    List<int> publicKey,
  ) {
    return IdentityCrypto.verify(
      publicKey: publicKey,
      message: message,
      signature: signature,
    );
  }
}
