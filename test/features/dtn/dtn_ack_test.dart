import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/ack/acknowledgement_manager.dart';

void main() {
  const timeout = Duration(minutes: 5);
  final base = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  AcknowledgementManager build() => AcknowledgementManager(ackTimeout: timeout);

  group('AcknowledgementManager delivery ACK', () {
    test('new ack is accepted exactly once', () {
      final ack = build();
      ack.expectAck('p1', base);
      expect(
        ack.acknowledge('p1', base.add(const Duration(seconds: 1))),
        isTrue,
      );
      // Duplicate arrives later.
      expect(
        ack.acknowledge('p1', base.add(const Duration(seconds: 2))),
        isFalse,
      );
    });

    test('late ack for an envelope never expected is still deduplicated', () {
      final ack = build();
      expect(ack.acknowledge('ghost', base), isTrue);
      expect(ack.acknowledge('ghost', base), isFalse);
    });

    test('ack deadline expiry returns the packet id', () {
      final ack = build();
      ack.expectAck('p1', base);
      final expired = ack.timedOut(
        base.add(timeout + const Duration(seconds: 1)),
      );
      expect(expired, ['p1']);
      expect(ack.isExpectingAck('p1'), isFalse);
    });

    test('timeout before deadline yields nothing', () {
      final ack = build();
      ack.expectAck('p1', base);
      expect(ack.timedOut(base.add(const Duration(minutes: 1))), isEmpty);
    });
  });

  group('AcknowledgementManager relay/forward ACK', () {
    test('relay ack is accepted only from the expected relay', () {
      final ack = build();
      ack.expectRelayAck('p1', 'relay-x', base);
      expect(
        ack.acknowledgeRelay(
          'p1',
          'relay-y',
          base.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        ack.acknowledgeRelay(
          'p1',
          'relay-x',
          base.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(ack.isExpectingRelayAck('p1'), isFalse);
    });

    test('forward ack is accepted only from the expected next hop', () {
      final ack = build();
      ack.expectForwardAck('p1', 'hop-1', base);
      expect(
        ack.acknowledgeForward(
          'p1',
          'hop-2',
          base.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        ack.acknowledgeForward(
          'p1',
          'hop-1',
          base.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('relay ack timeout surfaces the packet id', () {
      final ack = build();
      ack.expectRelayAck('p1', 'relay-x', base);
      final due = ack.relayTimedOut(
        base.add(timeout + const Duration(seconds: 1)),
      );
      expect(due, ['p1']);
    });

    test('allTimedOut combines delivery + relay + forward timeouts', () {
      final ack = build();
      ack.expectAck('a', base);
      ack.expectRelayAck('b', 'r', base);
      ack.expectForwardAck('c', 'h', base);
      final due = ack.allTimedOut(
        base.add(timeout + const Duration(seconds: 1)),
      );
      expect(due.toSet(), {'a', 'b', 'c'});
    });
  });

  group('AcknowledgementManager bookkeeping', () {
    test('pending counters reflect outstanding expectations', () {
      final ack = build();
      ack.expectAck('a', base);
      ack.expectRelayAck('b', 'r', base);
      ack.expectForwardAck('c', 'h', base);
      expect(ack.pendingAckCount, 1);
      expect(ack.pendingRelayAckCount, 1);
      expect(ack.pendingForwardAckCount, 1);
    });

    test('forget removes all expectations', () {
      final ack = build();
      ack.expectAck('a', base);
      ack.expectRelayAck('b', 'r', base);
      ack.forget('a');
      ack.forget('b');
      expect(ack.pendingAckCount, 0);
      expect(ack.pendingRelayAckCount, 0);
    });
  });
}
