import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/protocol/packet_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── PacketConstants ──────────────────────────────────────

  group('PacketConstants', () {
    test('version is 1', () {
      expect(PacketConstants.version, 1);
    });

    test('headerSize is 5', () {
      expect(PacketConstants.headerSize, 5);
    });

    test('maxPacketSize is 260', () {
      expect(PacketConstants.maxPacketSize, 260);
    });

    test('maxPayloadSize is headerSize less than maxPacketSize', () {
      expect(
        PacketConstants.maxPayloadSize,
        PacketConstants.maxPacketSize - PacketConstants.headerSize,
      );
    });
  });

  // ── PacketType ───────────────────────────────────────────

  group('PacketType', () {
    test('test type is 0x01', () {
      expect(PacketType.test, 0x01);
    });

    test('isValid recognizes test type', () {
      expect(PacketType.isValid(PacketType.test), isTrue);
    });

    test('isValid rejects unknown types', () {
      expect(PacketType.isValid(0x00), isFalse);
      expect(PacketType.isValid(0x04), isFalse);
      expect(PacketType.isValid(0xFF), isFalse);
    });
  });

  // ── OneBitPacket model ──────────────────────────────────

  group('OneBitPacket', () {
    test('version getter returns constant', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List.fromList([10, 20]),
      );
      expect(packet.version, PacketConstants.version);
    });

    test('payloadLength matches payload bytes', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(packet.payloadLength, 4);
    });

    test('totalSize is headerSize + payloadLength', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      expect(packet.totalSize, PacketConstants.headerSize + 3);
    });

    test('empty payload works', () {
      const packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
      );
      expect(packet.payloadLength, 0);
      expect(packet.totalSize, PacketConstants.headerSize);
    });

    test('payloadAsUtf8 returns correct string', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List.fromList([79, 78, 69, 66, 73, 84]), // "ONEBIT"
      );
      expect(packet.payloadAsUtf8, 'ONEBIT');
    });

    test('toString includes key fields', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 42,
        payload: Uint8List.fromList([1]),
      );
      final str = packet.toString();
      expect(str, contains('v=1'));
      expect(str, contains('0x01'));
      expect(str, contains('id=42'));
      expect(str, contains('len=1'));
    });
  });

  // ── Encoding ─────────────────────────────────────────────

  group('PacketCodec.encode', () {
    test('encodes header fields in correct order', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 7,
        flags: 0,
        payload: Uint8List.fromList([10, 20, 30]),
      );

      final bytes = PacketCodec.encode(packet);

      // version=1, type=0x01, flags=0, packetId=7, length=3
      expect(bytes, [0x01, 0x01, 0x00, 0x07, 0x03, 10, 20, 30]);
    });

    test('empty payload produces header-only packet', () {
      const packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
      );

      final bytes = PacketCodec.encode(packet);

      expect(bytes.length, PacketConstants.headerSize);
      expect(bytes, [0x01, 0x01, 0x00, 0x01, 0x00]);
    });

    test('deterministic — same packet produces identical bytes', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 99,
        payload: Uint8List.fromList([0xFF, 0x00, 0x7F]),
      );

      final a = PacketCodec.encode(packet);
      final b = PacketCodec.encode(packet);

      expect(a, equals(b));
    });

    test('throws packetTooLarge for oversized payload', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List(PacketConstants.maxPayloadSize + 1),
      );

      expect(
        () => PacketCodec.encode(packet),
        throwsA(isA<PacketDecodeException>()),
      );
    });

    test('accepts maximum valid payload', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: Uint8List(PacketConstants.maxPayloadSize),
      );

      final bytes = PacketCodec.encode(packet);
      expect(bytes.length, PacketConstants.maxPacketSize);
    });
  });

  // ── Decoding — valid packets ─────────────────────────────

  group('PacketCodec.decode — valid', () {
    test('decodes a basic test packet', () {
      final bytes = Uint8List.fromList([0x01, 0x01, 0x00, 0x05, 0x03, 1, 2, 3]);
      final packet = PacketCodec.decode(bytes);

      expect(packet.version, 1);
      expect(packet.type, PacketType.test);
      expect(packet.flags, 0);
      expect(packet.packetId, 5);
      expect(packet.payload, [1, 2, 3]);
    });

    test('decodes empty payload', () {
      final bytes = Uint8List.fromList([0x01, 0x01, 0x00, 0x01, 0x00]);
      final packet = PacketCodec.decode(bytes);

      expect(packet.payloadLength, 0);
      expect(packet.payload, isEmpty);
    });

    test('decodes packet with payload 0xFF bytes', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x01, 0x03,
        0xFF, 0xFF, 0xFF,
      ]);
      final packet = PacketCodec.decode(bytes);

      expect(packet.payload, [0xFF, 0xFF, 0xFF]);
    });
  });

  // ── Round-trip ───────────────────────────────────────────

  group('PacketCodec round-trip', () {
    test('empty payload round-trips', () {
      const original = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
      );

      final bytes = PacketCodec.encode(original);
      final decoded = PacketCodec.decode(bytes);

      expect(decoded.version, original.version);
      expect(decoded.type, original.type);
      expect(decoded.flags, original.flags);
      expect(decoded.packetId, original.packetId);
      expect(decoded.payload, original.payload);
    });

    test('text payload round-trips', () {
      final payload = Uint8List.fromList(
        [79, 78, 69, 66, 73, 84, 95, 80, 65, 67, 75, 69, 84, 95, 84, 69, 83, 84],
      ); // "ONEBIT_PACKET_TEST"
      final original = OneBitPacket(
        type: PacketType.test,
        packetId: 42,
        payload: payload,
      );

      final bytes = PacketCodec.encode(original);
      final decoded = PacketCodec.decode(bytes);

      expect(decoded.version, original.version);
      expect(decoded.type, original.type);
      expect(decoded.flags, original.flags);
      expect(decoded.packetId, original.packetId);
      expect(decoded.payload, original.payload);
      expect(decoded.payloadAsUtf8, 'ONEBIT_PACKET_TEST');
    });

    test('binary payload round-trips', () {
      final payload = Uint8List.fromList([0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF]);
      final original = OneBitPacket(
        type: PacketType.test,
        packetId: 200,
        payload: payload,
      );

      final bytes = PacketCodec.encode(original);
      final decoded = PacketCodec.decode(bytes);

      expect(decoded.payload, payload);
      expect(decoded.packetId, 200);
    });

    test('maximum valid payload round-trips', () {
      final payload = Uint8List(PacketConstants.maxPayloadSize);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = i & 0xFF;
      }
      final original = OneBitPacket(
        type: PacketType.test,
        packetId: 255,
        payload: payload,
      );

      final bytes = PacketCodec.encode(original);
      expect(bytes.length, PacketConstants.maxPacketSize);

      final decoded = PacketCodec.decode(bytes);
      expect(decoded.payload, payload);
      expect(decoded.packetId, 255);
    });

    test('all packetId values round-trip', () {
      for (var id = 0; id <= 255; id++) {
        final original = OneBitPacket(
          type: PacketType.test,
          packetId: id,
          payload: Uint8List.fromList([id]),
        );

        final bytes = PacketCodec.encode(original);
        final decoded = PacketCodec.decode(bytes);

        expect(decoded.packetId, id, reason: 'Failed for packetId=$id');
        expect(decoded.payload, [id], reason: 'Payload mismatch for packetId=$id');
      }
    });
  });

  // ── Deterministic encoding ───────────────────────────────

  group('Deterministic encoding', () {
    test('encode(decode(bytes)) reproduces exact bytes for valid packet', () {
      final original = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x0A, 0x05,
        0xDE, 0xAD, 0xBE, 0xEF, 0x42,
      ]);

      final packet = PacketCodec.decode(original);
      final reencoded = PacketCodec.encode(packet);

      expect(reencoded, original);
    });
  });

  // ── Malformed packets ────────────────────────────────────

  group('PacketCodec.decode — malformed', () {
    test('empty buffer rejected', () {
      expect(
        () => PacketCodec.decode(Uint8List(0)),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.malformedPacket,
          ),
        ),
      );
    });

    test('too short for header (4 bytes) rejected', () {
      expect(
        () => PacketCodec.decode(Uint8List.fromList([0x01, 0x01, 0x00, 0x01])),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.malformedPacket,
          ),
        ),
      );
    });

    test('single byte rejected', () {
      expect(
        () => PacketCodec.decode(Uint8List.fromList([0x01])),
        throwsA(isA<PacketDecodeException>()),
      );
    });

    test('unsupported version rejected', () {
      final bytes = Uint8List.fromList([
        0x02, // version 2 (unsupported)
        0x01, 0x00, 0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.unsupportedVersion,
          ),
        ),
      );
    });

    test('version 0 rejected', () {
      final bytes = Uint8List.fromList([
        0x00, // version 0
        0x01, 0x00, 0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.unsupportedVersion,
          ),
        ),
      );
    });

    test('unsupported type rejected', () {
      final bytes = Uint8List.fromList([
        0x01, // version 1
        0x04, // type 0x04 (unknown)
        0x00, 0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.unsupportedType,
          ),
        ),
      );
    });

    test('type 0x00 rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0x00, 0x00, 0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.unsupportedType,
          ),
        ),
      );
    });

    test('type 0xFF rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0xFF, 0x00, 0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.unsupportedType,
          ),
        ),
      );
    });

    test('non-zero flags rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0x01, // flags = 1
        0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.invalidFlags,
          ),
        ),
      );
    });

    test('flags 0xFF rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0xFF,
        0x01, 0x00,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.invalidFlags,
          ),
        ),
      );
    });

    test('declared length > actual payload rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x01,
        0x05, // length says 5
        // but only 2 bytes of payload follow
        0xAA, 0xBB,
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.invalidLength,
          ),
        ),
      );
    });

    test('trailing bytes rejected', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x01,
        0x02, // length says 2
        0xAA, 0xBB,
        0xCC, // trailing byte
      ]);
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(
          isA<PacketDecodeException>().having(
            (e) => e.reason,
            'reason',
            PacketDecodeReason.invalidLength,
          ),
        ),
      );
    });

    test('oversized packet rejected', () {
      // Build a packet that is valid structurally but exceeds maxPacketSize.
      final header = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x01,
        PacketConstants.maxPayloadSize + 1, // length exceeds max
      ]);
      final payload = Uint8List(PacketConstants.maxPayloadSize + 1);
      final bytes = Uint8List.fromList([...header, ...payload]);

      // This will fail on invalidLength first because declared > available,
      // but the header + payload would also exceed maxPacketSize.
      expect(
        () => PacketCodec.decode(bytes),
        throwsA(isA<PacketDecodeException>()),
      );
    });
  });

  // ── PacketDecodeException ────────────────────────────────

  group('PacketDecodeException', () {
    test('toString includes reason', () {
      const ex = PacketDecodeException(PacketDecodeReason.malformedPacket);
      expect(ex.toString(), contains('malformedPacket'));
    });

    test('each reason is distinct', () {
      const reasons = PacketDecodeReason.values;
      final reasonsSet = reasons.toSet();
      expect(reasonsSet.length, reasons.length);
    });
  });

  // ── Integration with reliable transfer ───────────────────

  group('Packet codec through FakeReliableChannel', () {
    // Simulate the full stack:
    //   encode → send → receive → decode
    test('packet survives encode → fake channel → decode', () {
      final original = OneBitPacket(
        type: PacketType.test,
        packetId: 55,
        payload: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      );

      // Encode the packet.
      final encoded = PacketCodec.encode(original);

      // Simulate transmission through a reliable channel (just bytes).
      final received = Uint8List.fromList(encoded);

      // Decode on the other side.
      final decoded = PacketCodec.decode(received);

      expect(decoded.version, original.version);
      expect(decoded.type, original.type);
      expect(decoded.flags, original.flags);
      expect(decoded.packetId, original.packetId);
      expect(decoded.payload, original.payload);
    });

    test('multiple packets through channel maintain identity', () {
      final packets = List.generate(
        10,
        (i) => OneBitPacket(
          type: PacketType.test,
          packetId: i,
          payload: Uint8List.fromList([i, i * 2, i * 3]),
        ),
      );

      final encoded = packets.map(PacketCodec.encode).toList();
      final decoded = encoded.map(PacketCodec.decode).toList();

      for (var i = 0; i < packets.length; i++) {
        expect(decoded[i].packetId, packets[i].packetId);
        expect(decoded[i].payload, packets[i].payload);
      }
    });

    test('retry sends same encoded bytes', () {
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 10,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      // Simulate multiple retries of the same packet.
      final attempt1 = PacketCodec.encode(packet);
      final attempt2 = PacketCodec.encode(packet);
      final attempt3 = PacketCodec.encode(packet);

      // All retries must produce identical bytes.
      expect(attempt1, equals(attempt2));
      expect(attempt2, equals(attempt3));

      // All decode to the same packet.
      final d1 = PacketCodec.decode(attempt1);
      final d2 = PacketCodec.decode(attempt2);
      final d3 = PacketCodec.decode(attempt3);

      expect(d1.packetId, d2.packetId);
      expect(d2.packetId, d3.packetId);
    });
  });

  // ── Edge cases ───────────────────────────────────────────

  group('Edge cases', () {
    test('packetId 0 round-trips', () {
      const packet = OneBitPacket(
        type: PacketType.test,
        packetId: 0,
      );
      final decoded = PacketCodec.decode(PacketCodec.encode(packet));
      expect(decoded.packetId, 0);
    });

    test('packetId 255 round-trips', () {
      const packet = OneBitPacket(
        type: PacketType.test,
        packetId: 255,
      );
      final decoded = PacketCodec.decode(PacketCodec.encode(packet));
      expect(decoded.packetId, 255);
    });

    test('payload with byte values 0x00-0xFE round-trips', () {
      final payload = Uint8List.fromList(List.generate(255, (i) => i));
      final packet = OneBitPacket(
        type: PacketType.test,
        packetId: 1,
        payload: payload,
      );
      final decoded = PacketCodec.decode(PacketCodec.encode(packet));
      expect(decoded.payload, payload);
    });

    test('decode does not mutate input buffer', () {
      final bytes = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x01, 0x03,
        0xAA, 0xBB, 0xCC,
      ]);
      final original = Uint8List.fromList(bytes);

      PacketCodec.decode(bytes);

      expect(bytes, original);
    });
  });
}
