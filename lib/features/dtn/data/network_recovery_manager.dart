import '../delivery/store_forward_engine.dart';
import '../domain/dtn_diagnostics.dart';
import '../domain/dtn_envelope.dart';
import '../domain/dtn_priority.dart';

/// Restores the engine into a state indistinguishable from a node that never
/// stopped: envelopes regroup into the same queues, deadlines that passed
/// while offline are repaired, expired envelopes are pruned.
final class NetworkRecoveryManager {
  const NetworkRecoveryManager();

  /// Apply [persisted] envelopes to [engine].
  ///
  /// Repair work is evaluated against the engine's own clock so a rebooting
  /// node heals exactly what its deadlines say — and tests stay
  /// deterministic. Returns the number of envelopes that needed a fix.
  int restore(StoreForwardEngine engine, List<DtnPacket> persisted) {
    var fixed = 0;
    final now = engine.now;

    final repaired = <DtnPacket>[];
    for (final original in persisted) {
      final packet = _repair(original, now);
      if (identical(packet, original)) {
        repaired.add(original);
      } else {
        repaired.add(packet);
        fixed++;
        engine.diagnostics.logTransition(
          DtnDiagnosticEventKind.recovered,
          packet,
          message: 'deadline/ttl repaired after reboot',
        );
      }
    }

    engine.restore(repaired, at: now);
    engine.diagnostics.logTransition(
      DtnDiagnosticEventKind.recovered,
      DtnPacket(
        packetId: 'restore',
        source: '',
        destination: '',
        payload: const [],
        priority: DtnPriority.normal,
        direction: DtnDirection.outbound,
        ttlSeconds: 0,
        createdAt: now,
        expiresAt: now,
      ),
      message: 'restored ${persisted.length} envelopes, $fixed repaired',
      details: {'count': persisted.length, 'fixed': fixed},
    );
    return fixed;
  }

  /// Returns the same instance when nothing needs fixing.
  DtnPacket _repair(DtnPacket packet, DateTime now) {
    var p = packet;
    if (p.state == DtnPacketState.retrying) {
      final next = p.nextAttemptAt;
      if (next == null || next.isBefore(now)) {
        p = p.copyWith(state: DtnPacketState.queued, enqueuedAt: now);
      }
    }
    if (p.state == DtnPacketState.awaitingAck) {
      final deadline = p.ackDeadlineAt;
      if (deadline != null && deadline.isBefore(now)) {
        p = p.copyWith(
          state: DtnPacketState.queued,
          ackState: DtnAckState.timedOut,
          ackDeadlineAt: null,
          enqueuedAt: now,
        );
      }
    }
    return p;
  }
}
