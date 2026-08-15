import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/dtn/queue/queue_manager.dart';
import 'package:onebit/features/dtn/scheduler/priority_scheduler.dart';

import 'support/dtn_test_support.dart';

void main() {
  late DtnHarness h;

  setUp(() => h = DtnHarness());

  group('QueueManager views', () {
    test('exposes independent per-state queues', () {
      h.store('p-out');
      h.place(
        'p-retry',
        state: DtnPacketState.retrying,
        nextAttemptAt: h.clock.now.add(const Duration(minutes: 1)),
      );
      h.place('p-def', state: DtnPacketState.deferred);
      h.place(
        'p-relay',
        state: DtnPacketState.relaying,
        direction: DtnDirection.relay,
      );
      h.place(
        'p-ack',
        state: DtnPacketState.awaitingAck,
        ackDeadlineAt: h.clock.now.add(const Duration(minutes: 5)),
      );

      final q = QueueManager(h.engine);
      expect(q.outgoing.map((p) => p.packetId), ['p-out']);
      expect(q.retrying.map((p) => p.packetId), ['p-retry']);
      expect(q.deferred.map((p) => p.packetId), ['p-def']);
      expect(q.relaying.map((p) => p.packetId), ['p-relay']);
      expect(q.awaitingAck.map((p) => p.packetId), ['p-ack']);
      expect(q.live, hasLength(5));
    });

    test('counts() aggregates queue depths', () {
      h.store('a');
      h.store('b');
      h.store('c');
      final counts = QueueManager(h.engine).counts();
      expect(counts.outgoing, 3);
      expect(counts.total, 3);
      expect(counts.live, 3);
    });

    test('byExpiration sorts soonest-first even when TTL differs', () {
      h.store('short', ttlSeconds: 10);
      h.store('long', ttlSeconds: 3600);
      final order = QueueManager(h.engine).byExpiration.map((p) => p.packetId);
      expect(order, ['short', 'long']);
    });

    test('byPriority sorts highest first', () {
      h.store('low', priority: DtnPriority.low);
      h.store('critical', priority: DtnPriority.critical);
      h.store('normal', priority: DtnPriority.normal);
      final order = QueueManager(h.engine).byPriority.map((p) => p.packetId);
      expect(order, ['critical', 'normal', 'low']);
    });

    test('find() and forDestination() query helpers', () {
      h.store('x1', destination: 'bob');
      h.store('x2', destination: 'carol');
      final store = QueueManager(h.engine);
      expect(store.find('x1')!.destination, 'bob');
      expect(store.forDestination('bob').single.packetId, 'x1');
      expect(store.forDestination('nobody'), isEmpty);
    });
  });

  group('PriorityScheduler', () {
    test('nextBatch returns envelopes in priority order respecting limit', () {
      for (var i = 0; i < 10; i++) {
        h.store('p$i', priority: DtnPriority.normal);
      }
      h.store('urgent', priority: DtnPriority.critical);
      final batch = const PriorityScheduler().nextBatch(h.engine, limit: 3);
      expect(batch.first.packetId, 'urgent');
      expect(batch, hasLength(3));
    });

    test('buckets() partitions by priority and preserves age order', () {
      h.store('low1', priority: DtnPriority.low);
      h.store('high1', priority: DtnPriority.high);
      h.store('low2', priority: DtnPriority.low);
      final buckets = const PriorityScheduler().buckets(h.engine);
      expect(buckets[DtnPriority.high]!.single.packetId, 'high1');
      expect(buckets[DtnPriority.low]!.map((p) => p.packetId), [
        'low1',
        'low2',
      ]);
      expect(buckets[DtnPriority.critical], isEmpty);
    });
  });
}
