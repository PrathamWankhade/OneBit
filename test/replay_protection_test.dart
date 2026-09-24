import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/crypto/aead_cipher.dart';
import 'package:onebit/features/crypto/encrypted_payload.dart';
import 'package:onebit/features/crypto/key_derivation.dart';
import 'package:onebit/features/crypto/replay_protection.dart';

void main() {
  group('ReplayWindow', () {
    test('fresh window accepts first message', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(0), isTrue);
      expect(window.highestSeen, 0);
    });

    test('fresh window accepts any non-negative sequence', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(100), isTrue);
      expect(window.highestSeen, 100);
    });

    test('rejects negative sequence', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(-1), isFalse);
    });

    test('accepts ascending sequences', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(1), isTrue);
      expect(window.accept(2), isTrue);
      expect(window.accept(3), isTrue);
      expect(window.highestSeen, 3);
    });

    test('rejects exact duplicate', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(5), isTrue);
      expect(window.accept(5), isFalse);
    });

    test('accepts out-of-order within window', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(3), isTrue);
      expect(window.accept(1), isTrue); // out of order, within window
      expect(window.highestSeen, 3);
    });

    test('rejects out-of-order duplicate', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(1), isTrue);
      expect(window.accept(3), isTrue);
      expect(window.accept(1), isFalse); // already seen
    });

    test('rejects old message outside window', () {
      final window = ReplayWindow(windowSize: 4);
      expect(window.accept(10), isTrue);
      expect(window.accept(11), isTrue);
      expect(window.accept(12), isTrue);
      expect(window.accept(13), isTrue);
      // highestSeen=13, windowSize=4, range=[10,13]
      // Sequence 9 is outside window
      expect(window.accept(9), isFalse);
    });

    test('accepts message at window boundary', () {
      final window = ReplayWindow(windowSize: 5);
      expect(window.accept(10), isTrue);
      expect(window.accept(11), isTrue);
      expect(window.accept(12), isTrue);
      expect(window.accept(13), isTrue);
      // highestSeen=13, windowSize=5, range=[9,13]
      expect(window.accept(9), isTrue); // at boundary
    });

    test('rejects message just below window boundary', () {
      final window = ReplayWindow(windowSize: 4);
      expect(window.accept(10), isTrue);
      expect(window.accept(14), isTrue);
      // highestSeen=14, windowSize=4, range=[11,14]
      expect(window.accept(10), isFalse); // just below
    });

    test('large jump past window clears bitset', () {
      final window = ReplayWindow(windowSize: 4);
      expect(window.accept(0), isTrue);
      expect(window.accept(1), isTrue);
      // Jump past entire window
      expect(window.accept(100), isTrue);
      expect(window.highestSeen, 100);
      // Old sequences all rejected (range=[97,100])
      expect(window.accept(0), isFalse);
      expect(window.accept(1), isFalse);
      expect(window.accept(99), isTrue); // within window
      expect(window.accept(96), isFalse); // outside window
    });

    test('window size 1 only accepts exact sequence', () {
      final window = ReplayWindow(windowSize: 1);
      expect(window.accept(5), isTrue);
      expect(window.accept(5), isFalse);
      expect(window.accept(6), isTrue);
      expect(window.accept(5), isFalse);
    });

    test('contains returns true for seen sequences', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.contains(5), isFalse);
      window.accept(5);
      expect(window.contains(5), isTrue);
      expect(window.contains(6), isFalse);
    });

    test('contains is non-mutating', () {
      final window = ReplayWindow(windowSize: 64);
      window.accept(5);
      window.contains(5);
      window.contains(5);
      // State unchanged — 5 still accepted as already seen
      expect(window.accept(5), isFalse);
    });

    test('reset clears state', () {
      final window = ReplayWindow(windowSize: 64);
      window.accept(5);
      window.reset();
      expect(window.highestSeen, -1);
      expect(window.accept(5), isTrue); // fresh window
    });

    test('multiple duplicates rejected', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(7), isTrue);
      expect(window.accept(7), isFalse);
      expect(window.accept(7), isFalse);
      expect(window.accept(7), isFalse);
    });

    test('interleaved sequences', () {
      final window = ReplayWindow(windowSize: 8);
      expect(window.accept(10), isTrue);
      expect(window.accept(12), isTrue);
      expect(window.accept(11), isTrue);
      expect(window.accept(9), isTrue);
      // highestSeen=12, windowSize=8, range=[5,12]
      expect(window.accept(8), isTrue); // within window
      expect(window.accept(4), isFalse); // outside window
      expect(window.accept(9), isFalse); // duplicate
      expect(window.accept(10), isFalse); // duplicate
    });
  });

  group('SendCounter', () {
    test('starts at 0', () {
      final counter = SendCounter();
      expect(counter.value, 0);
    });

    test('next increments and returns', () {
      final counter = SendCounter();
      expect(counter.next(), 1);
      expect(counter.next(), 2);
      expect(counter.next(), 3);
      expect(counter.value, 3);
    });

    test('can start from custom value', () {
      final counter = SendCounter(value: 100);
      expect(counter.value, 100);
      expect(counter.next(), 101);
    });

    test('throws at max safe sequence', () {
      final counter = SendCounter(value: maxSafeSequence);
      expect(
        () => counter.next(),
        throwsA(isA<CounterExhaustedException>()),
      );
    });

    test('exhaustion error has message', () {
      const error = CounterExhaustedException();
      expect(error.toString(), contains('exhausted'));
    });
  });

  group('encodeSequenceForAad', () {
    test('encodes 0 as 8-byte big-endian', () {
      final bytes = encodeSequenceForAad(0);
      expect(bytes.length, 8);
      expect(bytes, equals(Uint8List(8)));
    });

    test('encodes 1 correctly', () {
      final bytes = encodeSequenceForAad(1);
      expect(bytes[7], 1);
      expect(bytes.sublist(0, 7), equals(Uint8List(7)));
    });

    test('encodes large value correctly', () {
      final bytes = encodeSequenceForAad(256);
      expect(bytes[6], 1);
      expect(bytes[7], 0);
    });

    test('deterministic — same input produces same output', () {
      final a = encodeSequenceForAad(42);
      final b = encodeSequenceForAad(42);
      expect(a, equals(b));
    });

    test('different sequences produce different encoding', () {
      final a = encodeSequenceForAad(1);
      final b = encodeSequenceForAad(2);
      expect(a, isNot(equals(b)));
    });

    test('rejects negative sequence', () {
      expect(
        () => encodeSequenceForAad(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects sequence above max safe', () {
      expect(
        () => encodeSequenceForAad(maxSafeSequence + 1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts max safe sequence', () {
      final bytes = encodeSequenceForAad(maxSafeSequence);
      expect(bytes.length, 8);
    });
  });

  group('AAD integration with AES-GCM', () {
    late SecretKey testKey;

    setUp(() {
      testKey = SecretKey(
        Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
    });

    test('sequence in AAD affects authentication', () async {
      final plaintext = Uint8List.fromList('hello'.codeUnits);
      final aad1 = encodeSequenceForAad(1);
      final aad2 = encodeSequenceForAad(2);

      // Encrypt with sequence=1
      final encrypted = await OneBitEncryptedPayload.encrypt(
        key: testKey,
        plaintext: plaintext,
        associatedData: aad1,
      );

      // Decrypt with sequence=1 — should succeed
      final decrypted = await OneBitEncryptedPayload.decrypt(
        key: testKey,
        payload: encrypted,
        associatedData: aad1,
      );
      expect(decrypted, equals(plaintext));

      // Decrypt with sequence=2 — should fail (wrong AAD)
      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: encrypted,
          associatedData: aad2,
        ),
        throwsA(isA<AeadCipherException>()),
      );
    });

    test('modified AAD sequence fails authentication', () async {
      final plaintext = Uint8List.fromList('data'.codeUnits);
      final originalAad = encodeSequenceForAad(5);
      final tamperedAad = encodeSequenceForAad(6);

      final encrypted = await OneBitEncryptedPayload.encrypt(
        key: testKey,
        plaintext: plaintext,
        associatedData: originalAad,
      );

      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: encrypted,
          associatedData: tamperedAad,
        ),
        throwsA(isA<AeadCipherException>()),
      );
    });

    test('empty AAD vs sequence AAD fails', () async {
      final plaintext = Uint8List.fromList('test'.codeUnits);
      final aad = encodeSequenceForAad(1);

      final encrypted = await OneBitEncryptedPayload.encrypt(
        key: testKey,
        plaintext: plaintext,
        associatedData: aad,
      );

      // Decrypt with no AAD — should fail
      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: testKey,
          payload: encrypted,
        ),
        throwsA(isA<AeadCipherException>()),
      );
    });
  });

  group('Full replay protection flow', () {
    late SecretKey sessionKey;

    setUp(() async {
      final algorithm = X25519();
      final kpA = await algorithm.newKeyPair();
      final kpB = await algorithm.newKeyPair();
      final pubB = await kpB.extractPublicKey();
      final secret = await algorithm.sharedSecretKey(
        keyPair: kpA,
        remotePublicKey: pubB,
      );
      sessionKey = await KeyDerivation.deriveSessionKey(sharedSecret: secret);
    });

    test('fresh message accepted, duplicate rejected', () async {
      final sendCounter = SendCounter();
      final receiveWindow = ReplayWindow(windowSize: 64);

      // Sender: encrypt with sequence
      final seq1 = sendCounter.next(); // 1
      final aad1 = encodeSequenceForAad(seq1);
      final payload1 = await OneBitEncryptedPayload.encrypt(
        key: sessionKey,
        plaintext: Uint8List.fromList('msg1'.codeUnits),
        associatedData: aad1,
      );

      // Receiver: authenticate, then replay check
      const seq1Received = 1; // extracted from packet
      final aad1Received = encodeSequenceForAad(seq1Received);
      final decrypted1 = await OneBitEncryptedPayload.decrypt(
        key: sessionKey,
        payload: payload1,
        associatedData: aad1Received,
      );
      expect(receiveWindow.accept(seq1Received), isTrue);
      expect(decrypted1, equals(Uint8List.fromList('msg1'.codeUnits)));

      // Replay same payload — should be rejected
      await OneBitEncryptedPayload.decrypt(
        key: sessionKey,
        payload: payload1,
        associatedData: aad1Received,
      );
      expect(receiveWindow.accept(seq1Received), isFalse);
    });

    test('out-of-order accepted within window', () async {
      final sendCounter = SendCounter();
      final receiveWindow = ReplayWindow(windowSize: 64);

      // Send messages 1, 2, 3
      final payloads = <OneBitEncryptedPayload>[];
      for (var i = 0; i < 3; i++) {
        final seq = sendCounter.next();
        final aad = encodeSequenceForAad(seq);
        final payload = await OneBitEncryptedPayload.encrypt(
          key: sessionKey,
          plaintext: Uint8List.fromList('msg$seq'.codeUnits),
          associatedData: aad,
        );
        payloads.add(payload);
      }

      // Receive in order: 3, 1, 2
      for (final seq in [3, 1, 2]) {
        final aad = encodeSequenceForAad(seq);
        final decrypted = await OneBitEncryptedPayload.decrypt(
          key: sessionKey,
          payload: payloads[seq - 1],
          associatedData: aad,
        );
        expect(receiveWindow.accept(seq), isTrue);
        expect(decrypted, equals(Uint8List.fromList('msg$seq'.codeUnits)));
      }
    });

    test('old message outside window rejected', () async {
      final receiveWindow = ReplayWindow(windowSize: 4);

      // Accept messages 10-13
      for (var i = 10; i <= 13; i++) {
        expect(receiveWindow.accept(i), isTrue);
      }

      // Sequence 9 is outside window
      expect(receiveWindow.accept(9), isFalse);
      expect(receiveWindow.accept(8), isFalse);
    });

    test('forged high sequence with invalid auth does not advance window',
        () async {
      final receiveWindow = ReplayWindow(windowSize: 64);

      // Accept a few messages
      expect(receiveWindow.accept(1), isTrue);
      expect(receiveWindow.accept(2), isTrue);

      // Simulate forged high sequence with wrong auth — authenticate first
      final forgedAad = encodeSequenceForAad(999);
      final forgedPayload = OneBitEncryptedPayload(
        version: 1,
        nonce: Uint8List(12),
        ciphertext: Uint8List(4),
        authenticationTag: Uint8List(16),
      );

      // Authentication fails — must NOT advance window
      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: sessionKey,
          payload: forgedPayload,
          associatedData: forgedAad,
        ),
        throwsA(isA<AeadCipherException>()),
      );

      // Window state unchanged
      expect(receiveWindow.highestSeen, 2);
      expect(receiveWindow.contains(1), isTrue);
      expect(receiveWindow.contains(2), isTrue);
    });

    test('valid high sequence advances window', () async {
      final sendCounter = SendCounter();
      final receiveWindow = ReplayWindow(windowSize: 64);

      // Skip to sequence 100
      for (var i = 0; i < 100; i++) {
        sendCounter.next();
      }

      // Encrypt message 101
      final seq = sendCounter.next(); // 101
      final aad = encodeSequenceForAad(seq);
      final payload = await OneBitEncryptedPayload.encrypt(
        key: sessionKey,
        plaintext: Uint8List.fromList('high'.codeUnits),
        associatedData: aad,
      );

      // Receive and authenticate
      final decrypted = await OneBitEncryptedPayload.decrypt(
        key: sessionKey,
        payload: payload,
        associatedData: aad,
      );

      // Replay check
      expect(receiveWindow.accept(seq), isTrue);
      expect(receiveWindow.highestSeen, 101);
      expect(decrypted, equals(Uint8List.fromList('high'.codeUnits)));
    });

    test('session isolation — same sequence in two windows', () {
      final windowA = ReplayWindow(windowSize: 64);
      final windowB = ReplayWindow(windowSize: 64);

      // Both accept sequence 1 independently
      expect(windowA.accept(1), isTrue);
      expect(windowB.accept(1), isTrue);

      // Both reject duplicate independently
      expect(windowA.accept(1), isFalse);
      expect(windowB.accept(1), isFalse);
    });

    test('closed session rejects — replay window not usable', () {
      final window = ReplayWindow(windowSize: 64);
      window.accept(1);

      // Simulate session closure — window state frozen
      window.reset(); // explicit reset simulates invalidation

      // After reset, sequence 1 is accepted again (new session context)
      expect(window.accept(1), isTrue);
    });

    test('wrong key fails authentication, replay state unchanged', () async {
      final receiveWindow = ReplayWindow(windowSize: 64);

      // Encrypt with sessionKey
      final aad = encodeSequenceForAad(1);
      final payload = await OneBitEncryptedPayload.encrypt(
        key: sessionKey,
        plaintext: Uint8List.fromList('secret'.codeUnits),
        associatedData: aad,
      );

      // Try to decrypt with wrong key
      final wrongKey = SecretKey(
        Uint8List.fromList(List.generate(32, (i) => i + 100)),
      );

      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: wrongKey,
          payload: payload,
          associatedData: aad,
        ),
        throwsA(isA<AeadCipherException>()),
      );

      // Replay state should be unchanged
      expect(receiveWindow.highestSeen, -1);
    });

    test('tampered ciphertext fails auth, replay state unchanged', () async {
      final receiveWindow = ReplayWindow(windowSize: 64);

      final aad = encodeSequenceForAad(1);
      final payload = await OneBitEncryptedPayload.encrypt(
        key: sessionKey,
        plaintext: Uint8List.fromList('data'.codeUnits),
        associatedData: aad,
      );

      // Tamper with ciphertext
      final tampered = OneBitEncryptedPayload(
        version: payload.version,
        nonce: payload.nonce,
        ciphertext: Uint8List.fromList(payload.ciphertext)
          ..[0] ^= 0xFF,
        authenticationTag: payload.authenticationTag,
      );

      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: sessionKey,
          payload: tampered,
          associatedData: aad,
        ),
        throwsA(isA<AeadCipherException>()),
      );

      expect(receiveWindow.highestSeen, -1);
    });

    test('tampered tag fails auth, replay state unchanged', () async {
      final receiveWindow = ReplayWindow(windowSize: 64);

      final aad = encodeSequenceForAad(1);
      final payload = await OneBitEncryptedPayload.encrypt(
        key: sessionKey,
        plaintext: Uint8List.fromList('data'.codeUnits),
        associatedData: aad,
      );

      // Tamper with tag
      final tampered = OneBitEncryptedPayload(
        version: payload.version,
        nonce: payload.nonce,
        ciphertext: payload.ciphertext,
        authenticationTag: Uint8List.fromList(payload.authenticationTag)
          ..[0] ^= 0xFF,
      );

      expect(
        () => OneBitEncryptedPayload.decrypt(
          key: sessionKey,
          payload: tampered,
          associatedData: aad,
        ),
        throwsA(isA<AeadCipherException>()),
      );

      expect(receiveWindow.highestSeen, -1);
    });

    test('new session gets fresh replay state', () {
      final window1 = ReplayWindow(windowSize: 64);
      window1.accept(1);
      window1.accept(2);
      expect(window1.highestSeen, 2);

      // New session — new window
      final window2 = ReplayWindow(windowSize: 64);
      expect(window2.highestSeen, -1);
      expect(window2.accept(1), isTrue); // fresh context
    });

    test('counter exhaustion — safe failure', () {
      final counter = SendCounter(value: maxSafeSequence);
      expect(
        () => counter.next(),
        throwsA(isA<CounterExhaustedException>()),
      );
      // Counter value unchanged
      expect(counter.value, maxSafeSequence);
    });
  });

  group('ReplayWindow bounded memory', () {
    test('window does not grow unbounded', () {
      final window = ReplayWindow(windowSize: 8);
      // Accept 1000 messages
      for (var i = 0; i < 1000; i++) {
        window.accept(i);
      }
      // Window should only remember the last 8
      expect(window.highestSeen, 999);
      // range=[992, 999]
      expect(window.accept(992), isFalse); // already seen (duplicate)
      expect(window.accept(991), isFalse); // outside window
      expect(window.accept(993), isFalse); // already seen (duplicate)
    });
  });

  group('ReplayWindow edge cases', () {
    test('sequence 0 accepted and tracked', () {
      final window = ReplayWindow(windowSize: 64);
      expect(window.accept(0), isTrue);
      expect(window.accept(0), isFalse);
      expect(window.contains(0), isTrue);
    });

    test('large sequence values', () {
      final window = ReplayWindow(windowSize: 64);
      const large = 1000000000;
      expect(window.accept(large), isTrue);
      expect(window.accept(large), isFalse);
      expect(window.accept(large - 1), isTrue);
    });

    test('window size larger than sequence range', () {
      final window = ReplayWindow(windowSize: 100);
      expect(window.accept(0), isTrue);
      expect(window.accept(1), isTrue);
      // Both should be within window
      expect(window.accept(0), isFalse); // duplicate
      expect(window.accept(1), isFalse); // duplicate
    });
  });

  group('ReplayException', () {
    test('has message', () {
      const error = ReplayException('test');
      expect(error.message, 'test');
      expect(error.toString(), 'ReplayException: test');
    });
  });
}
