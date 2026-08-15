import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/delivery/dtn_gateway.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/retry/retry_manager.dart';

import 'support/dtn_test_support.dart';

void main() {
  late DtnHarness h;
  late RetryManager retries;

  setUp(() {
    h = DtnHarness(
      config: const DtnEngineConfig(
        retryPolicy: DtnRetryPolicy(
          baseDelay: Duration(seconds: 10),
          factor: 2,
          maxDelay: Duration(minutes: 1),
          jitterRatio: 0,
          limit: 3,
        ),
      ),
    );
    retries = RetryManager(config: h.engine.config, now: () => h.clock.now);
  });

  test('backoff doubles per attempt and caps at maxDelay', () {
    expect(retries.delayFor(1), const Duration(seconds: 10));
    expect(retries.delayFor(2), const Duration(seconds: 20));
    expect(retries.delayFor(3), const Duration(seconds: 40));
    // Attempt 6 would be 320s but maxDelay caps at 60s.
    expect(retries.delayFor(6), const Duration(minutes: 1));
  });

  test('isExhausted reflects the policy limit', () {
    expect(retries.isExhausted(2), isFalse);
    expect(retries.isExhausted(3), isTrue);
  });

  test('due() only returns retries whose window has opened', () {
    final now = h.clock.now;
    h.place(
      'overdue',
      state: DtnPacketState.retrying,
      nextAttemptAt: now.subtract(const Duration(minutes: 1)),
    );
    h.place(
      'pending',
      state: DtnPacketState.retrying,
      nextAttemptAt: now.add(const Duration(minutes: 1)),
    );
    final due = retries.due(h.engine);
    expect(due.map((p) => p.packetId), ['overdue']);
  });

  test('immediateRetry makes the envelope due instantly', () {
    h.store('p1');
    final packet = h.engine.statusOf('p1')!;
    final retried = retries.immediateRetry(h.engine, packet, error: 'boom');
    expect(retried.state, DtnPacketState.retrying);
    expect(retried.nextAttemptAt, h.clock.now);
    expect(retried.attemptCount, 1);
  });

  test('RetryTracker records attempts and failures', () {
    final tracker = RetryTracker();
    tracker.recordAttempt('p1', failed: true);
    tracker.recordAttempt('p1', failed: false);
    expect(tracker.attempts('p1'), 2);
    expect(tracker.lastFailure('p1'), isNotNull);
    tracker.forget('p1');
    expect(tracker.attempts('p1'), 0);
  });

  test(
    'engine fleets retries when the window opens (scheduler integration)',
    () {
      h.gateway.outcomes.add(DtnGatewayOutcome.needRetry);
      h.store('p1');
      h.tick(); // first attempt fails -> retrying with backoff 10s
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.retrying);
      h.clock.advance(const Duration(seconds: 11));
      h.tick(); // window open -> delivered
      expect(h.engine.statusOf('p1')!.state, DtnPacketState.delivered);
      expect(h.gateway.transmitted.length, 2);
    },
  );
}
