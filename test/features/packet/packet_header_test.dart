import 'package:flutter_test/flutter_test.dart';

import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_id.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';

void main() {
  group('PacketHeader', () {
    test('defaults describe an unfragmented message frame', () {
      final header = PacketHeader(sequence: 1, source: 'a', destination: 'b');
      expect(header.type, PacketType.message);
      expect(header.priority, PacketPriority.normal);
      expect(header.ttl, 8);
      expect(header.fragmentIndex, 0);
      expect(header.fragmentCount, 1);
      expect(header.flags, isEmpty);
    });

    test('creates a deterministic packetId', () {
      final a = PacketHeader(
        sequence: 7,
        source: 'aaa',
        destination: 'bbb',
        fragmentId: 3,
        fragmentIndex: 2,
        fragmentCount: 5,
        flags: const {PacketFlag.encrypted, PacketFlag.compressed},
        ttl: 12,
      );
      final b = PacketHeader(
        sequence: 7,
        source: 'aaa',
        destination: 'bbb',
        fragmentId: 3,
        fragmentIndex: 2,
        fragmentCount: 5,
        flags: const {PacketFlag.encrypted, PacketFlag.compressed},
        ttl: 12,
      );
      expect(a.packetId, b.packetId);
      expect(a.packetId, isA<PacketId>());
    });

    test('isFragmented reflects the flag only', () {
      final plain = PacketHeader(sequence: 1, source: 'a', destination: 'b');
      expect(plain.isFragmented, isFalse);
      final fragmented = PacketHeader(
        sequence: 1,
        source: 'a',
        destination: 'b',
        flags: const {PacketFlag.fragmented},
      );
      expect(fragmented.isFragmented, isTrue);
    });

    test('rejects an index outside the run', () {
      expect(
        () => PacketHeader(
          sequence: 1,
          source: 'a',
          destination: 'b',
          fragmentIndex: 3,
          fragmentCount: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => PacketHeader(
          sequence: 1,
          source: 'a',
          destination: 'b',
          fragmentCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('negative sequence is rejected', () {
      expect(
        () => PacketHeader(
          sequence: -1,
          source: 'a',
          destination: 'b',
        ).toString(),
        throwsArgumentError,
      );
    });

    test('copyWith carries flag mutations', () {
      final base = PacketHeader(sequence: 1, source: 'a', destination: 'b');
      final withFlag = base.copyWith(
        flags: {...base.flags, PacketFlag.ackRequested},
      );
      expect(withFlag.flags, contains(PacketFlag.ackRequested));
      expect(withFlag.sequence, 1);
      expect(withFlag.fragmentIndex, 0);
    });
  });
}
