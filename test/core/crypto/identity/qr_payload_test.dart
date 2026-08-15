import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/identity_crypto.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';

void main() {
  final aliceEdSeed = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final aliceXSeed = Uint8List.fromList(List<int>.generate(32, (i) => 100 + i));
  final bobXSeed = Uint8List.fromList(List<int>.generate(32, (i) => 200 + i));

  Future<QrIdentityCard> aliceCard() async {
    final edPublic = await IdentityCrypto.publicKeyFromSeed(aliceEdSeed);
    final xPublic = await ExchangeCrypto.publicKeyFromSeed(aliceXSeed);
    final fingerprint = await Fingerprint.fromPublicKey(edPublic);
    return QrIdentityCard(
      nodeId: NodeId.fromFingerprintHex(fingerprint.hex).value,
      displayName: 'Alice',
      fingerprintHex: fingerprint.hex,
      ed25519PublicKey: edPublic,
      x25519PublicKey: xPublic,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      signature: Uint8List(0),
    );
  }

  Future<Uint8List> aliceSign(List<int> message) =>
      IdentityCrypto.sign(seed: aliceEdSeed, message: message);

  Future<bool> aliceVerify(
    List<int> message,
    Uint8List signature,
    List<int> publicKey,
  ) => IdentityCrypto.verify(
    publicKey: publicKey,
    message: message,
    signature: signature,
  );

  Future<Uint8List> bobSharedSecret(List<int> remotePublicKey) =>
      ExchangeCrypto.sharedSecret(
        keyPairSeed: bobXSeed,
        remotePublicKey: remotePublicKey,
      );

  group('QrPayloadCodec cards', () {
    test('encode/decode round-trips a signed identity card', () async {
      final card = await aliceCard();
      final wire = await QrPayloadCodec.encodeCard(card, signer: aliceSign);

      expect(wire, startsWith('OB1:'));
      final decoded = await QrPayloadCodec.decodeCard(
        wire,
        verifier: aliceVerify,
      );
      expect(decoded.nodeId, card.nodeId);
      expect(decoded.displayName, 'Alice');
      expect(decoded.fingerprintHex, card.fingerprintHex);
      expect(decoded.ed25519PublicKey, card.ed25519PublicKey);
      expect(decoded.x25519PublicKey, card.x25519PublicKey);
      expect(decoded.timestamp, card.timestamp);
      expect(decoded.signature, hasLength(64));
    });

    test('rejects a wire text that was tampered after signing', () async {
      final card = await aliceCard();
      final wire = await QrPayloadCodec.encodeCard(card, signer: aliceSign);
      final tampered = _withField(wire, 'n', 'Mallory');
      expect(tampered, isNot(wire));

      await expectLater(
        QrPayloadCodec.decodeCard(tampered, verifier: aliceVerify),
        throwsFormatException,
      );
    });

    test('rejects a card signed by another key', () async {
      final card = await aliceCard();
      final otherSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => 255 - i),
      );
      final wire = await QrPayloadCodec.encodeCard(
        card,
        signer: (message) =>
            IdentityCrypto.sign(seed: otherSeed, message: message),
      );
      await expectLater(
        QrPayloadCodec.decodeCard(wire, verifier: aliceVerify),
        throwsFormatException,
      );
    });

    test('rejects a card without a signature', () async {
      final card = await aliceCard();
      final wire = await QrPayloadCodec.encodeCard(card, signer: aliceSign);
      final unsigned = _withField(wire, 's', null);
      await expectLater(
        QrPayloadCodec.decodeCard(unsigned, verifier: aliceVerify),
        throwsFormatException,
      );
    });

    test('rejects bad prefixes, versions and types', () async {
      final card = await aliceCard();
      final wire = await QrPayloadCodec.encodeCard(card, signer: aliceSign);

      await expectLater(
        QrPayloadCodec.decodeCard('not-a-payload', verifier: aliceVerify),
        throwsFormatException,
      );
      await expectLater(
        QrPayloadCodec.decodeCard(
          _withField(wire, 'v', 99),
          verifier: aliceVerify,
        ),
        throwsFormatException,
      );
      await expectLater(
        QrPayloadCodec.decodeCard(
          _withField(wire, 't', 'xfer'),
          verifier: aliceVerify,
        ),
        throwsFormatException,
      );
      await expectLater(
        QrPayloadCodec.decodeCard(
          _withField(wire, 'fp', 'zz'),
          verifier: aliceVerify,
        ),
        throwsFormatException,
      );
    });
  });

  group('QrPayloadCodec transfers', () {
    test('sealed transfer is opened only by the intended recipient', () async {
      final card = await aliceCard();
      final bobPublic = await ExchangeCrypto.publicKeyFromSeed(bobXSeed);
      final content = QrTransferContent(
        nodeId: card.nodeId,
        displayName: 'Alice',
        fingerprintHex: card.fingerprintHex,
        ed25519Seed: aliceEdSeed,
        x25519Seed: aliceXSeed,
      );

      final wire = await QrPayloadCodec.encodeTransfer(
        content,
        recipientPublicKey: bobPublic,
      );

      final opened = await QrPayloadCodec.decodeTransfer(
        wire,
        sharedSecretProvider: bobSharedSecret,
      );
      expect(opened.nodeId, card.nodeId);
      expect(opened.displayName, 'Alice');
      expect(opened.fingerprintHex, card.fingerprintHex);
      expect(opened.ed25519Seed, aliceEdSeed);
      expect(opened.x25519Seed, aliceXSeed);
    });

    test('a wrong recipient cannot open the transfer', () async {
      final card = await aliceCard();
      final bobPublic = await ExchangeCrypto.publicKeyFromSeed(bobXSeed);
      final eveXSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => 99 - i),
      );
      final content = QrTransferContent(
        nodeId: card.nodeId,
        displayName: 'Alice',
        fingerprintHex: card.fingerprintHex,
        ed25519Seed: aliceEdSeed,
        x25519Seed: aliceXSeed,
      );
      final wire = await QrPayloadCodec.encodeTransfer(
        content,
        recipientPublicKey: bobPublic,
      );

      Future<Uint8List> eveShared(List<int> remote) =>
          ExchangeCrypto.sharedSecret(
            keyPairSeed: eveXSeed,
            remotePublicKey: remote,
          );
      await expectLater(
        QrPayloadCodec.decodeTransfer(wire, sharedSecretProvider: eveShared),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('a tampered envelope fails GCM authentication', () async {
      final card = await aliceCard();
      final bobPublic = await ExchangeCrypto.publicKeyFromSeed(bobXSeed);
      final content = QrTransferContent(
        nodeId: card.nodeId,
        displayName: 'Alice',
        fingerprintHex: card.fingerprintHex,
        ed25519Seed: aliceEdSeed,
        x25519Seed: aliceXSeed,
      );
      final wire = await QrPayloadCodec.encodeTransfer(
        content,
        recipientPublicKey: bobPublic,
      );

      final fields = _fieldsOf(wire);
      final envelope = _b64Decode(fields['u']! as String);
      envelope[envelope.length - 1] ^= 0x01;
      final tampered = _withField(wire, 'u', _b64Encode(envelope));

      await expectLater(
        QrPayloadCodec.decodeTransfer(
          tampered,
          sharedSecretProvider: bobSharedSecret,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects a truncated envelope', () async {
      final card = await aliceCard();
      final bobPublic = await ExchangeCrypto.publicKeyFromSeed(bobXSeed);
      final content = QrTransferContent(
        nodeId: card.nodeId,
        displayName: 'Alice',
        fingerprintHex: card.fingerprintHex,
        ed25519Seed: aliceEdSeed,
        x25519Seed: aliceXSeed,
      );
      final wire = await QrPayloadCodec.encodeTransfer(
        content,
        recipientPublicKey: bobPublic,
      );

      final truncated = _withField(wire, 'u', _b64Encode(Uint8List(8)));
      await expectLater(
        QrPayloadCodec.decodeTransfer(
          truncated,
          sharedSecretProvider: bobSharedSecret,
        ),
        throwsFormatException,
      );
    });

    test('rejects a non-transfer payload opened as transfer', () async {
      final card = await aliceCard();
      final wire = await QrPayloadCodec.encodeCard(card, signer: aliceSign);
      await expectLater(
        QrPayloadCodec.decodeTransfer(
          wire,
          sharedSecretProvider: bobSharedSecret,
        ),
        throwsFormatException,
      );
    });
  });
}

/// Wraps a wire payload with [field] overridden to [value] (or removed when
/// `null`), re-encoding without re-signing.
String _withField(String wire, String key, Object? value) {
  final fields = _fieldsOf(wire);
  if (value == null) {
    fields.remove(key);
  } else {
    fields[key] = value;
  }
  final body = _b64Encode(utf8.encode(jsonEncode(fields)));
  return '${QrPayloadCodec.prefix}$body';
}

Map<String, Object?> _fieldsOf(String wire) {
  final jsonText = utf8.decode(
    _b64Decode(wire.substring(QrPayloadCodec.prefix.length)),
  );
  return (jsonDecode(jsonText) as Map).cast<String, Object?>();
}

String _b64Encode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _b64Decode(String encoded) {
  final padding = (4 - encoded.length % 4) % 4;
  return Uint8List.fromList(
    base64Url.decode(encoded.padRight(encoded.length + padding, '=')),
  );
}
