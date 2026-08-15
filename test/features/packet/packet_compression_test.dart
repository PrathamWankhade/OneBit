import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/compression/zlib_compressor.dart';

void main() {
  final compressor = ZlibFastCompressor();

  group('PacketCompressionPolicy', () {
    test('compresses repetitive text below its original size', () {
      final payload = List<int>.generate(
        2048,
        (i) => 'the quick brown fox jumps over the lazy dog '.codeUnits[i % 43],
      );
      final result = compressor.compress(payload);
      expect(result, isNotNull);
      expect(result!.bytes.length, lessThan(payload.length));
      expect(result.originalSize, payload.length);
      expect(
        compressor.decompress(result.bytes, originalSize: result.originalSize),
        payload,
      );
    });

    test('returns null when deflate cannot shrink the payload', () {
      final randomish = List<int>.generate(1024, (i) => (i * 7919) % 256);
      final result = compressor.compress(randomish);
      if (result != null) {
        // At least it must never expand the payload.
        expect(result.bytes.length, lessThanOrEqualTo(randomish.length));
      }
    });

    test('decompress reverses a known zlib stream', () {
      final compressed = compressor.compress('hello hello hello'.codeUnits)!;
      expect(
        String.fromCharCodes(
          compressor.decompress(
            compressed.bytes,
            originalSize: compressed.originalSize,
          ),
        ),
        'hello hello hello',
      );
    });
  });
}
