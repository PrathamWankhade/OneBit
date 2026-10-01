import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onebit/features/conversations/models/attachment_prep.dart';

/// A noisy picture big enough that the raw bytes could never travel.
Uint8List bigPhoto() {
  final picture = img.Image(width: 2000, height: 1500);
  final random = _Counter();
  for (var y = 0; y < picture.height; y++) {
    for (var x = 0; x < picture.width; x++) {
      picture.setPixel(
        x,
        y,
        img.ColorRgb8(random.next(), random.next(), random.next()),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(picture));
}

class _Counter {
  int _value = 0;
  int next() => (_value += 37) % 256;
}

void main() {
  group('AttachmentPrep.prepareImage', () {
    test('a phone photo comes back a small JPEG', () {
      final out = AttachmentPrep.prepareImage(bigPhoto());

      expect(out, isNotNull);
      expect(out!.length, lessThanOrEqualTo(AttachmentPrep.maxImageBytes));
      // JPEG magic.
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
      // Chat-sized: the longest side fits the first rung.
      final decoded = img.decodeImage(out)!;
      final longest =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      expect(longest, lessThanOrEqualTo(1024));
    });

    test('a small picture passes through nearly untouched', () {
      final picture = img.Image(width: 100, height: 100);
      final bytes = Uint8List.fromList(img.encodePng(picture));

      final out = AttachmentPrep.prepareImage(bytes);

      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      expect(decoded.width, 100);
      expect(decoded.height, 100);
    });

    test('what is not an image is refused', () {
      expect(
        AttachmentPrep.prepareImage(Uint8List.fromList([1, 2, 3, 4])),
        isNull,
      );
      expect(AttachmentPrep.prepareImage(Uint8List(0)), isNull);
    });

    test('an absurd cap refuses instead of destroying', () {
      expect(
        AttachmentPrep.prepareImage(bigPhoto(), maxBytes: 100),
        isNull,
      );
    });
  });
}
