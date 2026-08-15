import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/cache/duplicate_packet_detector.dart';
import 'package:onebit/features/mesh/domain/mesh_clock.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/relay/relay_queue.dart';

MeshPacket _packet(int sequence) => MeshPacket(
  source: 'A',
  destination: 'B',
  kind: MeshPacketKind.data,
  ttl: 8,
  sequence: sequence,
);

void main() {
  group('DuplicatePacketDetector', () {
    test('markSeen returns true exactly once per packet', () {
      final detector = DuplicatePacketDetector(
        capacity: 16,
        window: const Duration(seconds: 10),
        now: () => DateTime.utc(2026),
      );
      final packet = _packet(1);
      expect(detector.markSeen(packet), isTrue);
      expect(detector.markSeen(packet), isFalse);
      expect(detector.size, 1);
      expect(detector.hits, 1);
    });

    test('evicts the oldest beyond the capacity', () {
      final detector = DuplicatePacketDetector(
        capacity: 2,
        window: const Duration(seconds: 10),
        now: () => DateTime.utc(2026),
      );
      detector.markSeen(_packet(1));
      detector.markSeen(_packet(2));
      expect(detector.size, 2);
      detector.markSeen(_packet(3));
      expect(detector.size, 2);
      expect(detector.evictions, 1);
    });

    test('sweep expires entries outside the window', () {
      final clock = ManualMeshClock();
      final detector = DuplicatePacketDetector(
        capacity: 16,
        window: const Duration(seconds: 10),
        now: clock.now,
      );
      detector.markSeen(_packet(1));
      detector.markSeen(_packet(2));
      expect(detector.size, 2);
      clock.advance(const Duration(seconds: 11));
      detector.sweep(clock.now());
      expect(detector.isSeen(_packet(1)), isFalse);
      expect(detector.isSeen(_packet(2)), isFalse);
    });

    test('stays bounded under high volume', () {
      final clock = ManualMeshClock();
      final detector = DuplicatePacketDetector(
        capacity: 2048,
        window: const Duration(seconds: 10),
        now: clock.now,
      );
      for (var i = 0; i < 10000; i++) {
        detector.markSeen(_packet(i));
      }
      expect(detector.size, lessThanOrEqualTo(2048));
      expect(detector.evictions, 10000 - 2048);
    });
  });

  group('InMemoryRelayQueue', () {
    test('is FIFO with a hard capacity', () {
      final queue = InMemoryRelayQueue(capacity: 2);
      final task = RelayTask(
        to: 'a',
        packet: _packet(1),
        enqueuedAt: DateTime.utc(2026),
      );
      expect(queue.enqueue(task), isTrue);
      expect(queue.enqueue(task), isTrue);
      expect(queue.enqueue(task), isFalse);
      expect(queue.size, 2);
      expect(queue.next(), same(task));
      expect(queue.next(), same(task));
      expect(queue.size, 0);
      expect(queue.next(), isNull);
    });

    test('clear discards every task', () {
      final queue = InMemoryRelayQueue(capacity: 16);
      queue.enqueue(
        RelayTask(to: 'a', packet: _packet(1), enqueuedAt: DateTime.utc(2026)),
      );
      queue.clear();
      expect(queue.size, 0);
    });
  });
}
