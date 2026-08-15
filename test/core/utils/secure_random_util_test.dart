import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/utils/secure_random_util.dart';

void main() {
  group('SecureRandomUtil', () {
    test('randomBytes returns the requested length', () {
      expect(SecureRandomUtil.randomBytes(0), isEmpty);
      expect(SecureRandomUtil.randomBytes(32), hasLength(32));
      expect(SecureRandomUtil.randomBytes(12), hasLength(12));
    });

    test('randomBytes produces distinct values', () {
      final first = SecureRandomUtil.randomBytes(32);
      final second = SecureRandomUtil.randomBytes(32);
      expect(first, isNot(second));
    });

    test('uuidV4 matches RFC 4122 version-4 shape', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(
        pattern.hasMatch(SecureRandomUtil.uuidV4()),
        isTrue,
        reason:
            'uuid must be lowercase hex with version nibble 4 '
            'and variant nibble 8..b',
      );
    });

    test('uuidV4 is unique across calls', () {
      final first = SecureRandomUtil.uuidV4();
      final second = SecureRandomUtil.uuidV4();
      expect(first, isNot(second));
    });
  });
}
