import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_result.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  Packet fragment({
    required int index,
    required int count,
    int sequence = 1,
    int fragmentId = 10,
    String source = 'a',
    String destination = 'b',
    int chunk = 0,
  }) {
    return Packet(
      header: PacketHeader(
        sequence: sequence,
        source: source,
        destination: destination,
        flags: const {PacketFlag.fragmented},
        fragmentId: fragmentId,
        fragmentIndex: index,
        fragmentCount: count,
        createdAt: now,
      ),
      payload: PacketPayload.binary([chunk, index]),
    );
  }

  group('ReassemblyEngine', () {
    test('delivers an in-order run', () {
      final engine = ReassemblyEngine(now: () => now);
      expect(
        engine.accept(fragment(index: 0, count: 3, chunk: 10)),
        isA<ReassemblyWaiting>(),
      );
      expect(
        engine.accept(fragment(index: 1, count: 3, chunk: 20)),
        isA<ReassemblyWaiting>(),
      );
      final complete = engine.accept(fragment(index: 2, count: 3, chunk: 30));
      expect(complete, isA<ReassemblyComplete>());
      final packet = (complete as ReassemblyComplete).packet;
      expect(packet.payload.bytes, [10, 0, 20, 1, 30, 2]);
      expect(engine.sessionCount, 0);
    });

    test('assembles out-of-order runs', () {
      final engine = ReassemblyEngine(now: () => now);
      engine.accept(fragment(index: 3, count: 4, chunk: 40));
      engine.accept(fragment(index: 1, count: 4, chunk: 20));
      final complete = engine.accept(fragment(index: 0, count: 4, chunk: 10));
      expect(complete, isA<ReassemblyWaiting>());
      final done = engine.accept(fragment(index: 2, count: 4, chunk: 30));
      expect(done, isA<ReassemblyComplete>());
      expect((done as ReassemblyComplete).packet.payload.bytes, [
        10,
        0,
        20,
        1,
        30,
        2,
        40,
        3,
      ]);
    });

    test('duplicate fragments are ignored, never double-written', () {
      final engine = ReassemblyEngine(now: () => now);
      engine.accept(fragment(index: 0, count: 2, chunk: 11));
      final dup = engine.accept(fragment(index: 0, count: 2, chunk: 99));
      expect(dup, isA<ReassemblyWaiting>());
      final complete = engine.accept(fragment(index: 1, count: 2, chunk: 22));
      final payload = (complete as ReassemblyComplete).packet.payload.bytes;
      expect(payload, [11, 0, 22, 1]);
    });

    test('expired sessions are swept and never delivered', () {
      var clock = now;
      final engine = ReassemblyEngine(
        now: () => clock,
        timeout: const Duration(seconds: 30),
      );
      engine.accept(fragment(index: 0, count: 3));
      expect(engine.sessionCount, 1);
      expect(engine.sweepExpired(), 0); // nothing is old yet

      clock = clock.add(const Duration(seconds: 31));
      expect(engine.sweepExpired(), 1);
      expect(engine.sessionCount, 0);

      // A late fragment starts a *new* run; the old one is gone.
      final late = engine.accept(fragment(index: 2, count: 3, chunk: 4));
      expect(late, isA<ReassemblyWaiting>());
      expect(engine.sessionCount, 1);
    });

    test('sweeps eagerly on accept (no timer needed)', () {
      var clock = now;
      final engine = ReassemblyEngine(now: () => clock);
      engine.accept(fragment(index: 0, count: 2));
      clock = clock.add(const Duration(minutes: 5));
      final outcome = engine.accept(fragment(index: 1, count: 2));
      // The stale session was evicted; this fragment opens a new one.
      expect(outcome, isA<ReassemblyWaiting>());
      expect(engine.sessionCount, 1);
    });

    test('evicts the oldest session at capacity', () {
      final engine = ReassemblyEngine(now: () => now, maxSessions: 2);
      engine.accept(fragment(index: 0, count: 3, sequence: 1));
      engine.accept(fragment(index: 0, count: 3, sequence: 2));
      engine.accept(fragment(index: 0, count: 3, sequence: 3));
      expect(engine.sessionCount, 2);

      // The newest run is still open; feed the middle fragment then
      // complete it.
      engine.accept(fragment(index: 1, count: 3, sequence: 3, chunk: 7));
      final done = engine.accept(
        fragment(index: 2, count: 3, sequence: 3, chunk: 8),
      );
      expect(done, isA<ReassemblyComplete>());
      expect(engine.sessionCount, 1);
    });

    test('keys runs by source, sequence and fragmentId', () {
      final engine = ReassemblyEngine(now: () => now);
      engine.accept(
        fragment(index: 0, count: 2, sequence: 5, fragmentId: 7, source: 'a'),
      );
      engine.accept(
        fragment(index: 0, count: 2, sequence: 5, fragmentId: 8, source: 'a'),
      );
      engine.accept(
        fragment(index: 0, count: 2, sequence: 5, fragmentId: 7, source: 'b'),
      );
      // A fragment from the third run must not complete either of the two
      // open ones.
      final outcome = engine.accept(
        fragment(index: 1, count: 2, sequence: 5, fragmentId: 7, source: 'b'),
      );
      expect(outcome, isA<ReassemblyComplete>());
      expect(engine.sessionCount, 2);
    });
  });
}
