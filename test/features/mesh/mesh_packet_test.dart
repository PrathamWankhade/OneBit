import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/data/mesh_packet_codec.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';

void main() {
  group('MeshPacket', () {
    test('exposes a stable source-local packet id', () {
      final packet = MeshPacket(
        source: 'A',
        destination: 'B',
        kind: MeshPacketKind.data,
        ttl: 8,
        sequence: 3,
      );
      expect(packet.packetId, 'A:3');
    });

    test('is a broadcast when the destination is empty', () {
      final broadcast = MeshPacket(
        source: 'A',
        destination: '',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryRequest('B'),
        ttl: 8,
        sequence: 1,
      );
      expect(broadcast.isBroadcast, isTrue);
    });

    test('decrementTtl copies with a lower ttl and dies at zero', () {
      final atOne = MeshPacket(
        source: 'A',
        destination: 'B',
        kind: MeshPacketKind.data,
        ttl: 1,
        sequence: 1,
      );
      final next = atOne.decrementTtl();
      expect(next, isNotNull);
      expect(next!.ttl, 0);
      expect(next.decrementTtl(), isNull);
    });

    test('relayedBy appends each relay once', () {
      final origin = MeshPacket(
        source: 'A',
        destination: 'B',
        kind: MeshPacketKind.data,
        ttl: 8,
        sequence: 1,
        path: const ['A'],
      );
      final viaA = origin.relayedBy('A');
      expect(viaA.path, const ['A']);
      final viaB = viaA.relayedBy('B');
      expect(viaB.path, const ['A', 'B']);
      expect(viaB.hopCount, 2);
    });

    test('equality is by source and sequence', () {
      final a = MeshPacket(
        source: 'A',
        destination: 'B',
        kind: MeshPacketKind.data,
        ttl: 8,
        sequence: 1,
      );
      final b = MeshPacket(
        source: 'A',
        destination: 'C',
        kind: MeshPacketKind.data,
        ttl: 5,
        sequence: 1,
      );
      expect(a, b);
    });
  });

  group('MeshPacketCodec', () {
    const codec = MeshPacketCodec();

    test('data round-trips every header field', () {
      final packet = MeshPacket(
        source: 'n-1',
        destination: 'n-2',
        kind: MeshPacketKind.data,
        payload: [1, 2, 3, 250],
        ttl: 7,
        hopCount: 2,
        path: const ['n-1', 'n-3'],
        sequence: 42,
      );
      final decoded = codec.decode(codec.encode(packet));
      expect(decoded, isNotNull);
      expect(decoded!.source, packet.source);
      expect(decoded.destination, packet.destination);
      expect(decoded.kind, MeshPacketKind.data);
      expect(decoded.payload, packet.payload);
      expect(decoded.ttl, 7);
      expect(decoded.hopCount, 2);
      expect(decoded.path, packet.path);
      expect(decoded.sequence, 42);
    });

    test('discovery request round-trips', () {
      final packet = MeshPacket(
        source: 'A',
        destination: '',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryRequest('target-node'),
        ttl: 8,
        sequence: 1,
      );
      final decoded = codec.decode(codec.encode(packet));
      expect(decoded, isNotNull);
      expect(decoded!.control, isA<RouteDiscoveryRequest>());
      expect((decoded.control! as RouteDiscoveryRequest).target, 'target-node');
    });

    test('discovery reply round-trips its recorded path', () {
      final packet = MeshPacket(
        source: 'E',
        destination: 'A',
        kind: MeshPacketKind.control,
        control: const RouteDiscoveryReply('E', ['A', 'B']),
        ttl: 9,
        sequence: 2,
        path: const ['A', 'B'],
      );
      final decoded = codec.decode(codec.encode(packet));
      expect(decoded, isNotNull);
      final reply = decoded!.control! as RouteDiscoveryReply;
      expect(reply.target, 'E');
      expect(reply.path, const ['A', 'B']);
      expect(decoded.path, packet.path);
    });

    test('rejects wrong versions, unknown kinds and truncation', () {
      expect(codec.decode(const []), isNull);
      expect(codec.decode(const [0xFF]), isNull);
      expect(codec.decode(const [0x03, 0, 0, 0, 0, 0, 0]), isNull);
      expect(
        codec.decode(const [
          0x00,
          0x08,
          0x00,
          0x00,
          0x00,
          0x00,
          0x01, // header, ttl, hopCount, seq
          0x00, // source length (incomplete)
        ]),
        isNull,
      );
    });
  });
}
