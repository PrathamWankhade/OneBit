import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/delivery/dtn_gateway.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';

import 'support/dtn_test_support.dart';

void main() {
  late DtnHarness h;

  setUp(() => h = DtnHarness());

  group('store', () {
    test('store → queued, and snapshots reflect the queue', () {
      h.store('p1');
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.queued);
      expect(h.engine.snapshot().outgoing, 1);
    });

    test('store is idempotent for the same packet id', () {
      h.store('p1');
      h.store('p1');
      expect(h.engine.snapshot().live, 1);
    });

    test('store rejects a zero TTL', () {
      expect(() => h.store('bad', ttlSeconds: 0), throwsA(isA<DtnFailure>()));
    });
  });

  group('deliver', () {
    test('reachable gateway delivers immediately', () {
      h.store('p1');
      h.tick();
      expect(h.engine.snapshot().outgoing, 0);
      expect(h.gateway.transmitted.map((p) => p.packetId), ['p1']);
    });

    test('unreachable gateway parks the envelope', () {
      h.gateway.reachable = false;
      h.store('p1');
      h.tick();
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.deferred);
    });

    test('critical envelopes are not parked when connectivity drops', () {
      h.gateway.reachable = false;
      h.store('p1'); // normal
      h.store('p2', priority: DtnPriority.critical);
      h.tick();
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.deferred);
      expect(h.engine.statusOf('p2')!.state, DtnPacketState.queued);
    });
  });

  group('ack flow', () {
    test('store and transmit marks the envelope delivered (consistency)', () {
      h.store('p1');
      h.tick(); // delivered fire-and-forget by the test gateway

      expect(h.engine.statusOf('p1')!.state, DtnPacketState.delivered);
      expect(h.engine.snapshot().live, 0); // out of the live queues
      expect(h.engine.statistics.snapshot().delivered, 1);
    });

    test('ack re-arm after timeout re-queues the envelope', () {
      h.gateway.fallback = DtnGatewayOutcome.accepted; // willAck: true
      h.store('p1');
      h.tick();
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.awaitingAck);

      // Ack never arrives; wait past the 5-minute ack timeout.
      h.clock.advance(const Duration(minutes: 6));
      h.tick(); // ack pass re-arms the envelope
      expect(h.engine.statusOf('p1')!.ackState, DtnAckState.timedOut);
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.queued);
    });

    test('acknowledge() completes the handshake', () {
      h.place(
        'p1',
        state: DtnPacketState.awaitingAck,
        ackDeadlineAt: h.clock.now.add(const Duration(minutes: 5)),
      );
      h.engine.acknowledge('p1', by: 'node-b');
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.delivered);
      expect(h.engine.statistics.snapshot().acknowledged, 1);
    });
  });

  group('relay', () {
    test('relay envelopes rearm on topology changes', () {
      h.place(
        'p1',
        state: DtnPacketState.relaying,
        direction: DtnDirection.relay,
      );
      expect(h.engine.snapshot().relaying, 1);
      h.engine.rearmRelaying();
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.queued);
    });
  });

  group('cancel', () {
    test('cancel removes an envelope from the live queue', () {
      h.store('p1');
      h.engine.cancel('p1');
      expect(h.engine.statusOf('p1'), isNull);
    });
  });
}
