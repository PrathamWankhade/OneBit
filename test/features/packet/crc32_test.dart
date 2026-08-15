import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/crc/crc32.dart';

void main() {
  group('Crc32', () {
    test('matches the IEEE 802.3 check value', () {
      expect(Crc32.compute('123456789'.codeUnits), 0xCBF43926);
    });

    test('empty input yields the seed by convention', () {
      expect(Crc32.compute(const []), 0x00000000);
    });

    test('single byte', () {
      expect(Crc32.compute(const [0x61]), isNot(0));
    });

    test('different bytes differ', () {
      expect(
        Crc32.compute('abc'.codeUnits),
        isNot(Crc32.compute('abd'.codeUnits)),
      );
    });

    test('a flipped bit changes the checksum', () {
      final input = List<int>.generate(300, (i) => i % 251);
      final original = Crc32.compute(input);
      final flipped = List<int>.of(input)..[150] ^= 0x40;
      expect(Crc32.compute(flipped), isNot(original));
    });

    test('recompute stabilizes across calls', () {
      final input = List<int>.generate(4096, (i) => i * 7 % 256);
      final first = Crc32.compute(input);
      for (var i = 0; i < 5; i++) {
        expect(Crc32.compute(input), first);
      }
    });
  });
}
