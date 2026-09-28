import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';

void main() {
  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => (i * 7) & 0xFF));

  group('splitPayload', () {
    test('leaves a payload that already fits untouched', () {
      final payload = bytesOf(PacketConstants.maxPayloadSize);

      final slices = splitPayload(payload);

      expect(slices, hasLength(1));
      expect(slices.single, equals(payload));
      // Untouched means an older peer can still read it.
      expect(isChunkPayload(slices.single), isFalse);
    });

    test('frames a payload that outgrows one packet', () {
      final payload = bytesOf(600);

      final slices = splitPayload(payload);

      expect(slices.length, (600 + maxChunkSlice - 1) ~/ maxChunkSlice);
      expect(slices.length, greaterThan(1));
      for (final slice in slices) {
        expect(slice.length, lessThanOrEqualTo(PacketConstants.maxPayloadSize));
        expect(isChunkPayload(slice), isTrue);
      }
    });

    test('refuses a payload chunking cannot carry', () {
      expect(
        () => splitPayload(Uint8List(maxChunkedPayload + 1)),
        throwsArgumentError,
      );
    });
  });

  group('split → reassemble', () {
    for (final size in [1, 255, 256, 600, 5000]) {
      test('survives $size bytes', () {
        final payload = bytesOf(size);
        final slices = splitPayload(payload);
        final reassembler = PacketChunkReassembler();

        Uint8List? whole;
        for (final slice in slices) {
          whole = reassembler.accept('peer', 3, slice);
        }

        expect(whole, equals(payload));
      });
    }
  });

  group('isChunkPayload', () {
    test('rejects a legacy MessageCodec frame', () {
      // Opens with the big-endian length of the external message id.
      final legacy = Uint8List.fromList([0x00, 0x03, 0x6D, 0x5F, 0x31, 99]);
      expect(isChunkPayload(legacy), isFalse);
    });

    test('rejects an envelope or advertisement version byte', () {
      for (final version in [1, 2]) {
        final framed = Uint8List(300)..[0] = version;
        expect(isChunkPayload(framed), isFalse);
      }
    });

    test('rejects a frame whose index runs past its count', () {
      final bad = Uint8List.fromList(
        [chunkMagic, 4, 3, 0x00, 0x10, 1, 2, 3],
      );
      expect(isChunkPayload(bad), isFalse);
    });

    test('rejects a frame too short to hold a slice', () {
      final short = Uint8List.fromList([chunkMagic, 0, 2, 0x00, 0x10]);
      expect(isChunkPayload(short), isFalse);
    });
  });

  group('sendInPackets', () {
    test('sends a payload that fits as one ordinary packet', () async {
      final sent = <Uint8List>[];

      final result = await sendInPackets(
        [1, 2, 3],
        type: PacketType.message,
        packetId: 7,
        send: (bytes) async {
          sent.add(bytes);
          return TransferResult.delivered;
        },
      );

      expect(result, TransferResult.delivered);
      expect(sent, hasLength(1));
      final packet = PacketCodec.decode(sent.single);
      expect(packet.type, PacketType.message);
      expect(packet.packetId, 7);
      expect(packet.payload, [1, 2, 3]);
    });

    test('spreads a large payload over packets that share an id', () async {
      final sent = <Uint8List>[];
      final payload = bytesOf(700);

      final result = await sendInPackets(
        payload,
        type: PacketType.message,
        packetId: 42,
        send: (bytes) async {
          sent.add(bytes);
          return TransferResult.delivered;
        },
      );

      expect(result, TransferResult.delivered);
      expect(sent.length, greaterThan(1));

      final reassembler = PacketChunkReassembler();
      Uint8List? whole;
      for (final raw in sent) {
        final packet = PacketCodec.decode(raw);
        expect(packet.type, PacketType.message);
        // The shared id is how the far end groups the slices.
        expect(packet.packetId, 42);
        whole = reassembler.accept(
          'peer',
          packet.packetId,
          Uint8List.fromList(packet.payload),
        );
      }

      expect(whole, equals(payload));
    });

    test('stops at the first packet the link refuses', () async {
      var attempts = 0;

      final result = await sendInPackets(
        bytesOf(600),
        type: PacketType.message,
        packetId: 1,
        send: (bytes) async {
          attempts++;
          return attempts == 1 ? TransferResult.delivered : TransferResult.failed;
        },
      );

      expect(result, TransferResult.failed);
      expect(attempts, 2);
    });

    test('reports failure without sending a payload it cannot carry', () async {
      var attempts = 0;

      final result = await sendInPackets(
        Uint8List(maxChunkedPayload + 1),
        type: PacketType.message,
        packetId: 1,
        send: (bytes) async {
          attempts++;
          return TransferResult.delivered;
        },
      );

      expect(result, TransferResult.failed);
      expect(attempts, 0);
    });
  });

  group('PacketChunkReassembler', () {
    test('passes an unchunked payload straight through', () {
      final reassembler = PacketChunkReassembler();
      final payload = bytesOf(120);

      expect(reassembler.accept('peer', 1, payload), equals(payload));
    });

    test('holds slices until the last one lands', () {
      final payload = bytesOf(600);
      final slices = splitPayload(payload);
      final reassembler = PacketChunkReassembler();

      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[1]), isNull);
      expect(reassembler.accept('peer', 1, slices[2]), equals(payload));
    });

    test('reassembles slices that arrive out of order', () {
      final payload = bytesOf(600);
      final slices = splitPayload(payload);
      final reassembler = PacketChunkReassembler();

      expect(reassembler.accept('peer', 1, slices[2]), isNull);
      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[1]), equals(payload));
    });

    test('counts a retransmitted slice once', () {
      final payload = bytesOf(600);
      final slices = splitPayload(payload);
      final reassembler = PacketChunkReassembler();

      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[1]), isNull);
      // The repeat did not take the place of the missing third slice.
      expect(reassembler.accept('peer', 1, slices[2]), equals(payload));
    });

    test('discards a partial the link never finished in time', () async {
      final reassembler =
          PacketChunkReassembler(maxAge: const Duration(milliseconds: 5));
      final payload = bytesOf(600);
      final slices = splitPayload(payload);

      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[1]), isNull);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Two slices held and one arriving would have completed it had the
      // stale partial survived.
      expect(reassembler.accept('peer', 1, slices[2]), isNull);
    });

    test('forget clears what is held for a device', () {
      final payload = bytesOf(600);
      final slices = splitPayload(payload);
      final reassembler = PacketChunkReassembler();

      expect(reassembler.accept('peer', 1, slices[0]), isNull);
      expect(reassembler.accept('peer', 1, slices[1]), isNull);

      reassembler.forget('peer');

      expect(reassembler.accept('peer', 1, slices[2]), isNull);
    });

    test('keeps partials for different devices apart', () {
      final payload = bytesOf(600);
      final slices = splitPayload(payload);
      final reassembler = PacketChunkReassembler();

      expect(reassembler.accept('a', 1, slices[0]), isNull);
      expect(reassembler.accept('b', 1, slices[2]), isNull);
      expect(reassembler.accept('b', 1, slices[1]), isNull);
      expect(reassembler.accept('a', 1, slices[1]), isNull);
      expect(reassembler.accept('a', 1, slices[2]), equals(payload));
      expect(reassembler.accept('b', 1, slices[0]), equals(payload));
    });
  });
}
