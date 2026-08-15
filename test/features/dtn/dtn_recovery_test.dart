import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/data/network_recovery_manager.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';

import 'support/dtn_test_support.dart';

void main() {
  late DtnHarness h;

  setUp(() => h = DtnHarness());

  List<DtnPacket> persistedPending() => [
    h.place('queued-1'),
    h.place('queued-2'),
    h.place(
      'retry-window-open',
      state: DtnPacketState.retrying,
      nextAttemptAt: h.clock.now.subtract(const Duration(minutes: 5)),
    ),
    h.place(
      'ack-timeout',
      state: DtnPacketState.awaitingAck,
      ackDeadlineAt: h.clock.now.subtract(const Duration(minutes: 1)),
    ),
    h.place(
      'expired-rows',
      ttlSeconds: 1,
      expiresAt: h.clock.now.subtract(const Duration(minutes: 10)),
    ),
  ];

  test('recovery repairs deadlines and deletes expired envelopes', () {
    final persisted = persistedPending();

    // Simulate a second engine that restores the same rows.
    final h2 = DtnHarness();
    final fixed = const NetworkRecoveryManager().restore(h2.engine, persisted);

    expect(fixed, greaterThan(1));
    // Expired rows are pruned during restore.
    expect(h2.engine.statusOf('expired-rows'), isNull);
    // Retry window that opened is re-queued.
    expect(
      h2.engine.statusOf('retry-window-open')!.state,
      DtnPacketState.queued,
    );
    // Ack that timed out is re-armed.
    expect(h2.engine.statusOf('ack-timeout')!.state, DtnPacketState.queued);
    expect(h2.engine.statusOf('ack-timeout')!.ackState, DtnAckState.timedOut);
    // Ordinary envelopes survived the restore untouched.
    expect(h2.engine.statusOf('queued-1'), isNotNull);
  });

  test('unexpired envelope with future deadlines is not touched', () {
    final fresh = [
      h.place(
        'fresh-retry',
        state: DtnPacketState.retrying,
        nextAttemptAt: h.clock.now.add(const Duration(hours: 1)),
      ),
      h.place(
        'fresh-ack',
        state: DtnPacketState.awaitingAck,
        ackDeadlineAt: h.clock.now.add(const Duration(hours: 1)),
      ),
    ];
    final h2 = DtnHarness();
    final fixed = const NetworkRecoveryManager().restore(h2.engine, fresh);
    expect(fixed, 0);
    expect(h2.engine.statusOf('fresh-retry')!.state, DtnPacketState.retrying);
  });

  test('restored engine resumes delivery through the scheduler', () {
    final persisted = persistedPending();
    const NetworkRecoveryManager().restore(h.engine, persisted);
    h.engine.start();
    h.tick(); // window open -> transmits everything it can
    expect(h.engine.statistics.snapshot().recovered, persisted.length);
  });
}
