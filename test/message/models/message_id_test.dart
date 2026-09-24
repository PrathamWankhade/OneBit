import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/models/message_id.dart';

void main() {
  group('MessageId', () {
    test('generates unique values', () {
      final id1 = MessageId();
      final id2 = MessageId();

      expect(id1, isNot(equals(id2)));
    });

    test('value returns hex string with dashes', () {
      final id = MessageId();
      final v = id.value;

      expect(v.length, equals(36));
      expect(v.contains('-'), isTrue);
    });

    test('toHexString matches value', () {
      final id = MessageId();
      expect(id.toHexString(), equals(id.value));
    });

    test('toBytes returns 16 bytes', () {
      final id = MessageId();
      final bytes = id.toBytes();

      expect(bytes.length, equals(16));
    });

    test('toBytes returns immutable copy', () {
      final id = MessageId();
      final bytes1 = id.toBytes();
      final bytes2 = id.toBytes();

      expect(bytes1, isNot(same(bytes2)));
      expect(bytes1, equals(bytes2));
    });

    test('fromBytes creates instance with same bytes', () {
      final original = MessageId();
      final bytes = original.toBytes();
      final copy = MessageId.fromBytes(bytes);

      expect(copy, equals(original));
      expect(copy.toHexString(), equals(original.toHexString()));
    });

    test('fromBytes rejects wrong length', () {
      expect(
        () => MessageId.fromBytes(Uint8List(10)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromBytes rejects invalid version bits', () {
      final bytes = Uint8List(16);
      bytes[6] = 0x00; // version 0, not 4
      bytes[8] = 0x80; // valid variant
      expect(
        () => MessageId.fromBytes(bytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromBytes rejects invalid variant bits', () {
      final bytes = Uint8List(16);
      bytes[6] = 0x40; // version 4
      bytes[8] = 0x00; // invalid variant
      expect(
        () => MessageId.fromBytes(bytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString creates instance with same hex value', () {
      final original = MessageId();
      final hex = original.toHexString();
      final copy = MessageId.fromString(hex);

      expect(copy, equals(original));
    });

    test('fromString rejects invalid UUID format', () {
      expect(
        () => MessageId.fromString('not-a-uuid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString rejects empty string', () {
      expect(
        () => MessageId.fromString(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString rejects non-v4 UUID', () {
      expect(
        () => MessageId.fromString(
          '12345678-1234-1123-8123-123456789abc',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString rejects invalid variant', () {
      expect(
        () => MessageId.fromString(
          '12345678-1234-4123-c123-123456789abc',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('value equality based on bytes', () {
      final id1 = MessageId();
      final id2 = MessageId.fromBytes(id1.toBytes());

      expect(id1, equals(id2));
      expect(id1.hashCode, equals(id2.hashCode));
    });

    test('inequality for different IDs', () {
      final id1 = MessageId();
      final id2 = MessageId();

      expect(id1 == id2, isFalse);
    });

    test('toString truncates hex for readability', () {
      final id = MessageId();
      final str = id.toString();

      expect(str, startsWith('MessageId('));
      expect(str.length, lessThan(50));
    });

    test('safe for use as Set key', () {
      final id1 = MessageId();
      final id2 = MessageId.fromBytes(id1.toBytes());
      final id3 = MessageId();

      final set = <MessageId>{id1, id2, id3};
      expect(set.length, equals(2)); // id1 == id2
    });

    test('safe for use as Map key', () {
      final id1 = MessageId();
      final id2 = MessageId.fromBytes(id1.toBytes());

      final map = <MessageId, String>{id1: 'a', id2: 'b'};
      expect(map.length, equals(1)); // id1 == id2
      expect(map[id1], equals('b')); // last write wins
    });

    test('round trip: generate → bytes → fromBytes → equals', () {
      final original = MessageId();
      final bytes = original.toBytes();
      final restored = MessageId.fromBytes(bytes);

      expect(restored, equals(original));
      expect(restored.toHexString(), equals(original.toHexString()));
    });
  });
}
