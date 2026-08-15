import '../delivery/store_forward_engine.dart';
import '../domain/dtn_envelope.dart';
import 'relay_candidate.dart';

/// Result of a forwarding evaluation.
final class ForwardingDecision {
  const ForwardingDecision({
    required this.packetId,
    required this.selectedRelay,
    required this.previousRelay,
    required this.reason,
  });

  final String packetId;
  final RelayCandidate? selectedRelay;
  final RelayCandidate? previousRelay;
  final String reason;

  bool get changed => selectedRelay != previousRelay;
}

/// Opportunistic forwarding engine.
///
/// Evaluates relay candidates against envelopes in relaying/awaitingAck/retrying
/// states and re-arms those with a better next hop back to the outgoing queue.
/// The engine is stateless; the scheduler calls [evaluate] on topology changes.
final class ForwardingEngine {
  ForwardingEngine({required this._engine, required this._policy});

  final StoreForwardEngine _engine;
  final RelayPolicy _policy;

  /// Current best relay per envelope (for flap detection).
  final Map<String, RelayCandidate> _bestRelay = {};

  /// Evaluate all candidates against forwardable envelopes.
  ///
  /// Returns decisions for envelopes where the best relay changed.
  List<ForwardingDecision> evaluate(
    Iterable<RelayCandidate> candidates, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final decisions = <ForwardingDecision>[];
    final candidateList = candidates.toList();

    // Consider envelopes that can be relayed: relaying, awaitingAck (for hop),
    // and retrying (to find a better path).
    final forwardable = _engine.envelopes.where(
      (p) =>
          p.direction == DtnDirection.relay ||
          p.direction == DtnDirection.outbound &&
              (p.state == DtnPacketState.relaying ||
                  p.state == DtnPacketState.awaitingAck ||
                  p.state == DtnPacketState.retrying ||
                  p.state == DtnPacketState.deferred),
    );

    for (final packet in forwardable) {
      if (packet.isTerminal) {
        continue;
      }
      final decision = _evaluatePacket(packet, candidateList, now);
      if (decision.changed) {
        decisions.add(decision);
        _bestRelay[packet.packetId] = decision.selectedRelay!;
        // Re-arm to outgoing so the scheduler picks it up with new route.
        _engine.reattach(
          packet.copyWith(state: DtnPacketState.queued, enqueuedAt: now),
        );
      }
    }
    return decisions;
  }

  ForwardingDecision _evaluatePacket(
    DtnPacket packet,
    List<RelayCandidate> candidates,
    DateTime now,
  ) {
    RelayCandidate? best = _bestRelay[packet.packetId];
    for (final c in candidates) {
      if (best == null || _policy.isBetter(c, best, packet)) {
        best = c;
      }
    }
    final previous = _bestRelay[packet.packetId];
    if (best != null && best != previous) {
      return ForwardingDecision(
        packetId: packet.packetId,
        selectedRelay: best,
        previousRelay: previous,
        reason:
            'better relay: ${best.nodeId} (score ${_policy.score(best, packet).toStringAsFixed(3)})',
      );
    }
    return ForwardingDecision(
      packetId: packet.packetId,
      selectedRelay: best,
      previousRelay: previous,
      reason: 'no change',
    );
  }

  /// Record a successful forward through a relay (updates history).
  void recordForwardSuccess(String packetId, String relayId) {
    final candidate = _bestRelay[packetId];
    if (candidate != null && candidate.nodeId == relayId) {
      // Update delivery success rate with exponential moving average.
      final updated = candidate.copyWith(
        deliverySuccessRate: 0.9 * candidate.deliverySuccessRate + 0.1 * 1.0,
        lastSeenAt: DateTime.now(),
      );
      _bestRelay[packetId] = updated;
    }
  }

  /// Record a failed forward through a relay.
  void recordForwardFailure(String packetId, String relayId) {
    final candidate = _bestRelay[packetId];
    if (candidate != null && candidate.nodeId == relayId) {
      final updated = candidate.copyWith(
        deliverySuccessRate: 0.9 * candidate.deliverySuccessRate + 0.1 * 0.0,
        lastSeenAt: DateTime.now(),
      );
      _bestRelay[packetId] = updated;
    }
  }

  /// Remove tracking for a delivered/expired envelope.
  void forget(String packetId) {
    _bestRelay.remove(packetId);
  }

  /// Get current best relay for a packet (diagnostics).
  RelayCandidate? getBestRelay(String packetId) => _bestRelay[packetId];

  /// Clear all relay state (e.g., on full topology reset).
  void clear() {
    _bestRelay.clear();
  }
}
