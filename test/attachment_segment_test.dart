import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/attachment_segment.dart';

Uint8List bytesOf(int length) =>
    Uint8List.fromList(List.generate(length, (i) => i % 256));

void main() {
  group('SegTag', () {
    test('slices round-trip across several frames', () {
      final segId = 'ab' * 8;
      final slices = SegTag.encodeSlices(
        segId: segId,
        fileName: 'photo.jpg',
        bytes: bytesOf(6000),
      );

      // 6000 bytes at 2900 per slice: three frames, not one.
      expect(slices.length, 3);

      final reassembled = <int, Uint8List>{};
      var count = 0;
      for (final slice in slices) {
        final parsed = SegTag.parse(slice);
        expect(parsed, isNotNull);
        expect(parsed!.id, segId);
        expect(parsed.name, 'photo.jpg');
        count = parsed.count;
        reassembled[parsed.index] = parsed.bytes;
      }
      expect(count, 3);

      final out = <int>[];
      for (var i = 0; i < count; i++) {
        out.addAll(reassembled[i]!);
      }
      expect(out, bytesOf(6000).toList());
    });

    test('a single small file is one slice', () {
      final slices = SegTag.encodeSlices(
        segId: 'cd' * 8,
        fileName: 'a.jpg',
        bytes: bytesOf(100),
      );
      expect(slices.length, 1);
      expect(slices.single, startsWith('[seg:cdcdcdcdcdcdcdcd:0/1:a.jpg:'));
    });

    test('what is not a slice is not mistaken for one', () {
      expect(SegTag.parse('hello'), isNull);
      expect(SegTag.parse('[receipt:read:m_1]'), isNull);
      expect(SegTag.parse('[image:photo.jpg]'), isNull);
      expect(SegTag.parse('[seg:]'), isNull);
      expect(SegTag.parse('[seg:abc:0/1:a:eA==]'), isNull);
      // Bad index, bad count, out-of-range index.
      expect(SegTag.parse('[seg:${'ab' * 8}:x/1:a:eA==]'), isNull);
      expect(SegTag.parse('[seg:${'ab' * 8}:0/0:a:eA==]'), isNull);
      expect(SegTag.parse('[seg:${'ab' * 8}:1/1:a:eA==]'), isNull);
      // Not base64, and more than one slice's worth of bytes.
      expect(SegTag.parse('[seg:${'ab' * 8}:0/1:a:!!!]'), isNull);
      expect(SegTag.parse('[seg:${'ab' * 8}:0/1:a:b/c]'), isNull);
    });

    test('oversize attachments are refused, not truncated', () {
      expect(
        () => SegTag.encodeSlices(
          segId: 'ab' * 8,
          fileName: 'huge.bin',
          bytes: Uint8List(SegTag.sliceBytes * SegTag.maxSlices + 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AttachmentManifest', () {
    test('a transfer manifest round-trips', () {
      final manifest = AttachmentManifest.encode(
        kind: 'image',
        fileName: 'photo.jpg',
        segId: 'ab' * 8,
        count: 3,
      );

      final parsed = AttachmentManifest.parse(manifest);
      expect(parsed, isNotNull);
      expect(parsed!.kind, 'image');
      expect(parsed.name, 'photo.jpg');
      expect(parsed.segId, 'ab' * 8);
      expect(parsed.count, 3);
    });

    test('a legacy manifest parses without a transfer', () {
      final parsed = AttachmentManifest.parse('[image:photo.png]');
      expect(parsed, isNotNull);
      expect(parsed!.kind, 'image');
      expect(parsed.name, 'photo.png');
      expect(parsed.segId, isNull);
    });

    test('a voice manifest carries its duration', () {
      final manifest = AttachmentManifest.encode(
        kind: 'voice',
        fileName: 'voice_123.m4a',
        segId: 'ef' * 8,
        count: 12,
        extra: ['45000'],
      );

      final parsed = AttachmentManifest.parse(manifest);
      expect(parsed, isNotNull);
      expect(parsed!.kind, 'voice');
      expect(parsed.name, 'voice_123.m4a');
      expect(parsed.segId, 'ef' * 8);
      expect(parsed.count, 12);
      expect(parsed.extra, ['45000']);
    });

    test('other markers belong to other renderers', () {
      expect(AttachmentManifest.parse('hello'), isNull);
      expect(AttachmentManifest.parse('[receipt:read:m_1]'), isNull);
      expect(AttachmentManifest.parse('[location:here]'), isNull);
      expect(AttachmentManifest.parse('[poll:q|a|b]'), isNull);
      expect(AttachmentManifest.parse('[image:]'), isNull);
      expect(AttachmentManifest.parse('[image:a:b]'), isNull);
    });

    test('sanitize keeps what the filesystem can wear', () {
      expect(AttachmentManifest.sanitize('photo.jpg'), 'photo.jpg');
      expect(AttachmentManifest.sanitize('/a/b/c.jpg'), 'c.jpg');
      expect(AttachmentManifest.sanitize('a:b[c].jpg'), 'a_b_c_.jpg');
      expect(AttachmentManifest.sanitize(''), 'file');
    });
  });
}
