import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';

void main() {
  final fragmenter = PacketFragmenter(serializer: const PacketSerializer());

  Packet bigPacket(int size) {
    return Packet(
      header: PacketHeader(
        sequence: 7,
        source: 'one-bit-a',
        destination: 'one-bit-b',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      payload: PacketPayload.binary(List<int>.generate(size, (i) => i % 256)),
    );
  }

  group('PacketFragmenter', () {
    test('keeps a fitting packet as one frame', () {
      final framing = fragmenter.frame(bigPacket(50), mtu: 512);
      expect(framing.fragmented, isFalse);
      expect(framing.frames, hasLength(1));
      expect(framing.frames.single.packet.header.fragmentCount, 1);
      expect(
        framing.frames.single.packet.header.flags,
        isNot(contains(PacketFlag.fragmented)),
      );
      expect(framing.frames.single.bytes.length, lessThanOrEqualTo(512));
    });

    test('splits a large payload into budgeted frames', () {
      final framing = fragmenter.frame(bigPacket(4000), mtu: 512);
      expect(framing.fragmented, isTrue);
      expect(framing.frames.length, greaterThan(1));
      for (final frame in framing.frames) {
        expect(frame.bytes.length, lessThanOrEqualTo(512));
        expect(frame.packet.header.flags, contains(PacketFlag.fragmented));
      }
    });

    test('fragment run is internally consistent', () {
      final framing = fragmenter.frame(bigPacket(10_000), mtu: 512);
      final count = framing.frames.length;
      for (final frame in framing.frames) {
        final header = frame.packet.header;
        expect(header.fragmentCount, count);
        expect(header.fragmentIndex, inInclusiveRange(0, count - 1));
        expect(
          header.fragmentId,
          framing.frames.first.packet.header.fragmentId,
        );
      }
    });

    test('parent signature rides on fragment 0 only', () {
      final packet = Packet(
        header: PacketHeader(
          sequence: 9,
          source: 'a',
          destination: 'b',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        payload: PacketPayload.binary(List<int>.filled(900, 7)),
        signature: [0x01, 0x02, 0x03],
      );
      final framing = fragmenter.frame(packet, mtu: 300);
      expect(framing.frames, hasLength(greaterThan(1)));
      expect(framing.frames.first.packet.signature, [0x01, 0x02, 0x03]);
      for (var i = 1; i < framing.frames.length; i++) {
        expect(framing.frames[i].packet.signature, isEmpty);
      }
    });

    test('payload bytes are reassembled verbatim, in order', () {
      final payload = List<int>.generate(5000, (i) => (i * 31) % 256);
      final framing = fragmenter.frame(
        Packet(
          header: PacketHeader(
            sequence: 1,
            source: 'a',
            destination: 'b',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
          payload: PacketPayload.binary(payload),
        ),
        mtu: 400,
      );
      final joined = <int>[];
      for (final frame in framing.frames) {
        joined.addAll(frame.packet.payload.bytes);
      }
      expect(joined, payload);
    });

    test('rejects an mtu smaller than the overhead', () {
      expect(
        () => fragmenter.frame(bigPacket(100), mtu: 8),
        throwsArgumentError,
      );
    });

    test('frames each fit the serialized budget', () {
      final framing = fragmenter.frame(bigPacket(30_000), mtu: 180);
      for (final frame in framing.frames) {
        expect(frame.bytes.length, lessThanOrEqualTo(180));
      }
    });
  });
}
