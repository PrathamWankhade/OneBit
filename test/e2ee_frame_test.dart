import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/e2ee_frame.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/protocol/key_announcement.dart';
import 'package:onebit/features/protocol/message_codec.dart';

Future<(SimpleKeyPair, Uint8List)> x25519Pair() async {
  final pair = await X25519().newKeyPair();
  final public = await pair.extractPublicKey();
  return (pair, Uint8List.fromList(public.bytes));
}

String hexOf(Uint8List bytes) => IdentityRepository.bytesToHex(bytes);

void main() {
  group('E2eeFrame', () {
    test('a frame goes out encrypted and comes back', () async {
      final (alice, alicePub) = await x25519Pair();
      final (bob, bobPub) = await x25519Pair();
      final inner = MessageCodec.encode(
        externalMessageId: 'm_1',
        content: 'hello',
        timestampMs: 1700000000000,
      );

      final encrypted = await E2eeFrame.encrypt(
        localKeyPair: alice,
        peerPublicKey: bobPub,
        frame: inner,
      );

      final opened = await E2eeFrame.decrypt(
        localKeyPair: bob,
        payload: encrypted,
      );
      expect(opened, isNotNull);
      expect(opened!.senderKey, alicePub);
      expect(opened.frame, inner);
      expect(MessageCodec.decode(opened.frame).content, 'hello');
    });

    test('either end derives the same session key', () async {
      final (alice, alicePub) = await x25519Pair();
      final (bob, bobPub) = await x25519Pair();
      final inner = MessageCodec.encode(
        externalMessageId: 'm_2',
        content: 'both ways',
        timestampMs: 1,
      );

      final fromBob = await E2eeFrame.encrypt(
        localKeyPair: bob,
        peerPublicKey: alicePub,
        frame: inner,
      );
      final opened = await E2eeFrame.decrypt(
        localKeyPair: alice,
        payload: fromBob,
      );
      expect(opened, isNotNull);
      expect(opened!.frame, inner);
    });

    test('a tampered frame fails closed', () async {
      final (alice, _) = await x25519Pair();
      final (bob, bobPub) = await x25519Pair();
      final encrypted = await E2eeFrame.encrypt(
        localKeyPair: alice,
        peerPublicKey: bobPub,
        frame: Uint8List.fromList([1, 2, 3]),
      );

      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;
      expect(
        await E2eeFrame.decrypt(localKeyPair: bob, payload: tampered),
        isNull,
      );
    });

    test('a swapped sender key fails closed', () async {
      final (alice, _) = await x25519Pair();
      final (bob, bobPub) = await x25519Pair();
      final (_, malloryPub) = await x25519Pair();
      final encrypted = await E2eeFrame.encrypt(
        localKeyPair: alice,
        peerPublicKey: bobPub,
        frame: Uint8List.fromList([9, 9, 9]),
      );

      // The header is authenticated data: rewriting who it claims to
      // be from breaks the tag even though the key bytes are valid.
      final swapped = Uint8List.fromList(encrypted);
      swapped.setAll(2, malloryPub);
      expect(
        await E2eeFrame.decrypt(localKeyPair: bob, payload: swapped),
        isNull,
      );
    });

    test('a third key cannot open the frame', () async {
      final (alice, _) = await x25519Pair();
      final (bob, bobPub) = await x25519Pair();
      final (mallory, _) = await x25519Pair();
      final encrypted = await E2eeFrame.encrypt(
        localKeyPair: alice,
        peerPublicKey: bobPub,
        frame: Uint8List.fromList([7, 7, 7]),
      );

      expect(
        await E2eeFrame.decrypt(localKeyPair: mallory, payload: encrypted),
        isNull,
      );
    });

    test('garbage is left for the plaintext path', () async {
      final (bob, _) = await x25519Pair();
      expect(
        await E2eeFrame.decrypt(
          localKeyPair: bob,
          payload: Uint8List.fromList([1, 2, 3]),
        ),
        isNull,
      );
      expect(
        await E2eeFrame.decrypt(localKeyPair: bob, payload: Uint8List(0)),
        isNull,
      );
      // Right magic, nothing behind it.
      expect(
        await E2eeFrame.decrypt(
          localKeyPair: bob,
          payload: Uint8List.fromList([0xE1, 0x01, ...List.filled(32, 1)]),
        ),
        isNull,
      );
    });

    test('a peer built before encryption drops the frame', () {
      // No E2eeFrame involved on their side: strict decode is all it
      // takes to refuse what they cannot read.
      expect(
        () => MessageCodec.decode(Uint8List.fromList([
          0xE1,
          0x01,
          ...List.filled(40, 7),
        ])),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('KeyAnnouncement', () {
    test('an announcement round-trips through a frame', () async {
      final edPair = await Ed25519().newKeyPair();
      final (_, xPub) = await x25519Pair();
      final edPublic = await edPair.extractPublicKey();
      final sig = await Ed25519().sign(xPub, keyPair: edPair);

      final frame = KeyAnnouncement.encodeFrame(
        x25519Hex: hexOf(xPub),
        signature: Uint8List.fromList(sig.bytes),
        timestampMs: 1700000000000,
      );
      final parsed = KeyAnnouncement.decodeFrame(frame);
      expect(parsed, isNotNull);
      expect(parsed!.keyHex, hexOf(xPub));

      expect(
        await KeyAnnouncement.verify(
          content: KeyAnnouncement.encode(
            x25519Hex: hexOf(xPub),
            signature: Uint8List.fromList(sig.bytes),
          ),
          senderEdPublicKey: Uint8List.fromList(edPublic.bytes),
        ),
        isTrue,
      );
    });

    test('a forged announcement fails verification', () async {
      final edPair = await Ed25519().newKeyPair();
      final malloryEd = await Ed25519().newKeyPair();
      final (_, xPub) = await x25519Pair();
      final malloryPublic = await malloryEd.extractPublicKey();

      // Signed by Mallory, attributed to the real sender.
      final sig = await Ed25519().sign(xPub, keyPair: malloryEd);
      final content = KeyAnnouncement.encode(
        x25519Hex: hexOf(xPub),
        signature: Uint8List.fromList(sig.bytes),
      );

      expect(
        await KeyAnnouncement.verify(
          content: content,
          senderEdPublicKey: Uint8List.fromList(malloryPublic.bytes),
        ),
        isTrue,
        reason: 'signed by Mallory, checked against Mallory: consistent',
      );

      final edPublic = await edPair.extractPublicKey();
      expect(
        await KeyAnnouncement.verify(
          content: content,
          senderEdPublicKey: Uint8List.fromList(edPublic.bytes),
        ),
        isFalse,
        reason: 'signed by Mallory, checked against the sender: forged',
      );
    });

    test('what is not an announcement is not mistaken for one', () async {
      final edPair = await Ed25519().newKeyPair();
      final edPublic = await edPair.extractPublicKey();
      final edBytes = Uint8List.fromList(edPublic.bytes);

      expect(KeyAnnouncement.parse('hello'), isNull);
      expect(KeyAnnouncement.parse('[receipt:read:m_1]'), isNull);
      expect(KeyAnnouncement.parse('[key:abc]'), isNull);
      expect(
        await KeyAnnouncement.verify(content: 'hello', senderEdPublicKey: edBytes),
        isFalse,
      );

      // All zeros is 64 hex chars of nothing.
      expect(KeyAnnouncement.parse('[key:${'0' * 64}:${'0' * 128}]'), isNull);
    });

    test('an ordinary message is left for the message decoder', () {
      final frame = MessageCodec.encode(
        externalMessageId: 'm_1',
        content: 'hello',
        timestampMs: 1,
      );
      expect(KeyAnnouncement.decodeFrame(frame), isNull);
      expect(MessageCodec.decode(frame).content, 'hello');
    });

    test('a peer built before announcements drops the frame', () {
      final frame = KeyAnnouncement.encodeFrame(
        x25519Hex: 'ab' * 32,
        signature: Uint8List(64),
        timestampMs: 1,
      );
      expect(
        () => MessageCodec.decode(frame),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Trailing bytes'),
        )),
      );
      expect(KeyAnnouncement.decodeFrame(frame), isNotNull);
    });
  });
}
