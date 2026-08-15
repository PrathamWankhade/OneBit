import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';

void main() {
  group('NodeId', () {
    test('parses a canonical id', () {
      final id = NodeId.parse('NODE-7A3F-91D2');
      expect(id.value, 'NODE-7A3F-91D2');
      expect(id.firstGroup, '7A3F');
      expect(id.secondGroup, '91D2');
    });

    test('normalizes lowercase and surrounding whitespace', () {
      expect(NodeId.parse('  node-7a3f-91d2  ').value, 'NODE-7A3F-91D2');
    });

    test('rejects malformed ids', () {
      for (final bad in <String>[
        'NODE-7A3F-91D', // too short
        'NODE-7A3F-91D23', // too long
        'NODE-7A3F-91DG', // non-hex
        'NODE-7A3F-91D2-', // trailing dash
        'NODE-7A3F', // missing group
        'FOO-7A3F-91D2', // wrong prefix
        '', // empty
      ]) {
        expect(() => NodeId.parse(bad), throwsFormatException, reason: bad);
        expect(NodeId.isValid(bad), isFalse, reason: bad);
      }
    });

    test('builds from a fingerprint hex (first eight hex digits)', () {
      const fingerprintHex =
          '1a2b3c4d5e6f7890abcdef0123456789abcdef0123456789abcdef0123456789';
      final id = NodeId.fromFingerprintHex(fingerprintHex);
      expect(id.value, 'NODE-1A2B-3C4D');
      expect(id.firstGroup, '1A2B');
      expect(id.secondGroup, '3C4D');
    });

    test('fromFingerprintHex rejects non-64-char or non-hex input', () {
      expect(() => NodeId.fromFingerprintHex('abc'), throwsFormatException);
      expect(() => NodeId.fromFingerprintHex('z' * 64), throwsFormatException);
    });

    test('equality is value-based', () {
      expect(NodeId.parse('NODE-7A3F-91D2'), NodeId.parse('node-7a3f-91d2'));
      expect(
        NodeId.parse('NODE-7A3F-91D2').hashCode,
        NodeId.parse('NODE-7A3F-91D2').hashCode,
      );
      expect(
        NodeId.parse('NODE-7A3F-91D2'),
        isNot(NodeId.parse('NODE-7A3F-91D3')),
      );
    });
  });
}
