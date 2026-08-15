import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_version.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';

Packet _packet({
  int sequence = 1,
  String source = 'alice',
  String destination = 'bob',
  PacketPayload? payload,
  Set<PacketFlag> flags = const {},
  PacketVersion version = PacketVersion.current,
}) {
  return Packet(
    header: PacketHeader(
      sequence: sequence,
      source: source,
      destination: destination,
      flags: flags,
      ttl: 6,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    payload: payload ?? PacketPayload.utf8('hi'),
  );
}

void main() {
  const serializer = PacketSerializer();

  group('PacketSerializer encode/decode', () {
    test('round-trips a message frame exactly', () {
      final packet = _packet(
        payload: PacketPayload.utf8('hello'),
        flags: const {PacketFlag.ackRequested, PacketFlag.encrypted},
      );
      final encoded = serializer.encode(packet);
      expect(encoded, isA<Ok<List<int>>>());
      final decoded = serializer.decode(encoded.value!);
      expect(decoded, isA<Ok<Packet>>());
      final back = decoded.value!;
      expect(back.header.sequence, 1);
      expect(back.header.source, 'alice');
      expect(back.header.destination, 'bob');
      expect(String.fromCharCodes(back.payload.bytes), 'hello');
      expect(back.header.flags, containsAll(packet.header.flags));
      expect(back.header.createdAt, DateTime.utc(2026, 1, 1));
      expect(back.header.ttl, 6);
    });

    test('sequence is big-endian at the fixed offset', () {
      final bytes = serializer.encode(_packet(sequence: 0x01020304)).value!;
      // fixed prefix: [transport(0), major(1), revision(2), compat(3),
      // type(4), priority(5), flags(6), reserved(7), ttl(8), hop(9),
      // sequence(10..13)]
      expect(bytes[10], 0x01);
      expect(bytes[11], 0x02);
      expect(bytes[12], 0x03);
      expect(bytes[13], 0x04);
    });

    test('transport nibble carries the version', () {
      final bytes = serializer
          .encode(_packet(version: PacketVersion.current))
          .value!;
      expect(bytes[0] >> 4, PacketVersion.current.transport);
      expect(bytes[1], PacketVersion.current.major);
      expect(bytes[2], PacketVersion.current.revision);
    });

    test('fragment metadata survives the wire', () {
      final packet = Packet(
        header: PacketHeader(
          sequence: 9,
          source: 'alice',
          destination: 'bob',
          flags: const {PacketFlag.fragmented},
          fragmentId: 42,
          fragmentIndex: 3,
          fragmentCount: 5,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        payload: PacketPayload.utf8('frag'),
      );
      final back = serializer.decode(serializer.encode(packet).value!).value!;
      expect(back.header.fragmentId, 42);
      expect(back.header.fragmentIndex, 3);
      expect(back.header.fragmentCount, 5);
      expect(back.header.isFragmented, isTrue);
    });

    test('empty and unicode payloads survive', () {
      for (final payload in [
        PacketPayload.utf8(''),
        PacketPayload.utf8('ñü…'),
        PacketPayload.binary(List<int>.generate(2000, (i) => i % 256)),
      ]) {
        final back = serializer
            .decode(serializer.encode(_packet(payload: payload)).value!)
            .value!;
        expect(back.payload.type, payload.type);
        expect(back.payload.bytes, payload.bytes);
      }
    });

    test('a flipped payload byte trips the CRC', () {
      final bytes = serializer.encode(_packet()).value!;
      const payloadIndex =
          28 + 'alice'.length + 'bob'.length + 5; // skip type+len
      expect(
        serializer.decode(
          [...bytes]..[payloadIndex] = bytes[payloadIndex] ^ 0x01,
        ),
        isA<Err<Packet>>(),
      );
    });

    test('truncated frames are rejected', () {
      final bytes = serializer.encode(_packet()).value!;
      expect(
        serializer.decode(bytes.sublist(0, bytes.length - 1)),
        isA<Err<Packet>>(),
      );
      expect(
        serializer.decode(const [0x10, 0x00, 0x01, 0x00]),
        isA<Err<Packet>>(),
      );
    });

    test('trailing bytes are rejected as suspicious', () {
      final bytes = serializer.encode(_packet()).value!;
      expect(serializer.decode([...bytes, 0xAB, 0xCD]), isA<Err<Packet>>());
    });

    test('an unknown payload type code is rejected', () {
      final bytes = serializer.encode(_packet()).value!;
      const index = 28 + 'alice'.length + 'bob'.length; // payload type byte
      expect(serializer.decode([...bytes]..[index] = 0x7F), isA<Err<Packet>>());
    });

    test('a different transport nibble is rejected', () {
      final bytes = serializer.encode(_packet()).value!;
      expect(serializer.decode([...bytes]..[0] = 0x20), isA<Err<Packet>>());
    });

    test('canonical bytes are stable and exclude crc and signature', () {
      final a = serializer.canonicalBytes(_packet(sequence: 5)).value!;
      final b = serializer.canonicalBytes(_packet(sequence: 5)).value!;
      expect(a, b);
      final framed = serializer.encode(_packet(sequence: 5)).value!;
      expect(a.length, framed.length - 4 - 2); // no crc, no sig-length
    });

    test('maxPayloadLength caps the accepted frame body', () {
      const cap = PacketSerializer(maxPayloadLength: 64);
      final big = _packet(
        payload: PacketPayload.binary(List<int>.filled(128, 0x61)),
      );
      expect(cap.decode(cap.encode(big).value!), isA<Err<Packet>>());
    });
  });
}
