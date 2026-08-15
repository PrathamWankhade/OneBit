import 'dart:async';

import 'dtn_gateway.dart';
import 'store_forward_engine.dart';

/// Event-driven delivery scheduler over [StoreForwardEngine].
///
/// Tick sequence (each step is bounded and idempotent):
/// 1. expiry sweep (TTL is law even when offline),
/// 2. connectivity gate — when unreachable, park work and stop,
/// 3. retry pass (due retries re-arm),
/// 4. forwarding pass (relaying envelopes re-offer),
/// 5. delivery pass (transmit up to the batch limit, priority order),
/// 6. ack pass (finalize acked, re-arm timed-out).
final class DeliveryScheduler {
  DeliveryScheduler({
    required this.engine,
    required this.gateway,
    DateTime Function()? now,
    this.tickInterval = const Duration(seconds: 5),
  }) : _now = now ?? DateTime.now;

  final StoreForwardEngine engine;
  final DtnGateway gateway;
  final DateTime Function() _now;

  /// Floor cadence of the periodic timer (event-driven wakeups run
  /// immediately on top of it).
  final Duration tickInterval;

  Timer? _timer;
  bool _running = false;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _timer = Timer.periodic(tickInterval, (_) => tick());
    tick();
  }

  /// Event-driven wakeup: store(), connectivity change, ack, topology.
  void arm() {
    if (_running) {
      tick();
    }
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// One full scheduling pass. Re-entrant and idempotent.
  void tick({DateTime? at}) {
    if (!_running) {
      return;
    }
    final now = at ?? _now();

    // 1. Expiry sweep (cheap: the engine only returns due envelopes).
    final due = engine.expiredDue(now);
    if (due.isNotEmpty) {
      engine.expireAll(due, at: now);
    }

    // 2. Connectivity gate.
    final connectivity = gateway.connectivity();
    engine.setConnectivity(connectivity);
    if (!connectivity.reachable) {
      engine.parkAll(at: now);
      return;
    }

    // 3. Retry pass: windows that opened.
    final dueRetries = engine.retriesDue(now);
    if (dueRetries.isNotEmpty) {
      engine.rearmRetries(dueRetries);
    }

    // 4. Forwarding pass: relays may have a fresh opportunity.
    engine.rearmRelaying();

    // 5. Delivery pass in bounded batches within the budget.
    var transmitted = 0;
    final candidates = engine.outgoingCandidates();
    for (final packet in candidates) {
      if (transmitted >= engine.config.batchLimit) {
        break;
      }
      if (!engine.config.budget.allow(1, packet.priority)) {
        break;
      }
      transmitted++;
      final outcome = gateway.transmit(packet);
      engine.noteAttempt(
        packet.packetId,
        outcome.ok,
        error: outcome.errorMessage,
        permanent: outcome.permanent,
        willAck: outcome.willAck,
        at: now,
      );
    }

    // 6. Ack pass: deadlines that passed re-arm for delivery.
    final timeouts = engine.ackTimeouts(now);
    if (timeouts.isNotEmpty) {
      engine.rearmAckTimeouts(timeouts);
    }
  }
}
