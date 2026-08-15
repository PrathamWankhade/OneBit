import 'dart:collection';

/// Logical acknowledgement manager: dedupe ledger + deadline enforcement.
///
/// Handles all ACK types: delivery, relay, and forward acknowledgements.
/// Provides duplicate detection with bounded time-window ledger.
final class AcknowledgementManager {
  AcknowledgementManager({required this.ackTimeout});

  /// Base timeout for delivery ACKs. Relay/forward ACKs may use shorter timeouts.
  final Duration ackTimeout;

  /// Seen ack references (bounded, time-boxed) for duplicate detection.
  final SplayTreeMap<DateTime, Set<String>> _ledger = SplayTreeMap();

  /// Envelopes awaiting an ack: packetId -> deadline.
  final Map<String, DateTime> _awaiting = {};

  /// Envelopes awaiting relay ACK: packetId -> (relayId, deadline).
  final Map<String, _RelayAckExpectation> _awaitingRelay = {};

  /// Envelopes awaiting forward ACK: packetId -> (nextHopId, deadline).
  final Map<String, _ForwardAckExpectation> _awaitingForward = {};

  static const _ledgerWindow = Duration(minutes: 10);
  static const _ledgerCap = 5000;

  /// Record an outbound envelope that should be acknowledged (delivery ACK).
  void expectAck(String packetId, DateTime sentAt) {
    _awaiting[packetId] = sentAt.add(ackTimeout);
  }

  /// Record an outbound envelope expecting a relay ACK.
  void expectRelayAck(
    String packetId,
    String relayId,
    DateTime sentAt, {
    Duration? timeout,
  }) {
    final deadline = sentAt.add(timeout ?? ackTimeout);
    _awaitingRelay[packetId] = _RelayAckExpectation(
      relayId: relayId,
      deadline: deadline,
    );
  }

  /// Record an outbound envelope expecting a forward ACK (from next hop).
  void expectForwardAck(
    String packetId,
    String nextHopId,
    DateTime sentAt, {
    Duration? timeout,
  }) {
    final deadline = sentAt.add(timeout ?? ackTimeout);
    _awaitingForward[packetId] = _ForwardAckExpectation(
      nextHopId: nextHopId,
      deadline: deadline,
    );
  }

  /// A logical ack for [packetId] arrived. Returns true when it was a *new*
  /// ack (not a duplicate).
  bool acknowledge(String packetId, DateTime at) {
    final deduped = _remember(packetId, at);
    if (!deduped) {
      return false;
    }
    _awaiting.remove(packetId);
    _awaitingRelay.remove(packetId);
    _awaitingForward.remove(packetId);
    return true;
  }

  /// A relay ack arrived from [relayId]. Returns true if expected and new.
  bool acknowledgeRelay(String packetId, String relayId, DateTime at) {
    final expectation = _awaitingRelay[packetId];
    if (expectation == null || expectation.relayId != relayId) {
      return false;
    }
    final deduped = _remember(packetId, at);
    if (!deduped) {
      return false;
    }
    _awaitingRelay.remove(packetId);
    return true;
  }

  /// A forward ack arrived from [nextHopId]. Returns true if expected and new.
  bool acknowledgeForward(String packetId, String nextHopId, DateTime at) {
    final expectation = _awaitingForward[packetId];
    if (expectation == null || expectation.nextHopId != nextHopId) {
      return false;
    }
    final deduped = _remember(packetId, at);
    if (!deduped) {
      return false;
    }
    _awaitingForward.remove(packetId);
    return true;
  }

  bool isExpectingAck(String packetId) => _awaiting.containsKey(packetId);
  bool isExpectingRelayAck(String packetId) =>
      _awaitingRelay.containsKey(packetId);
  bool isExpectingForwardAck(String packetId) =>
      _awaitingForward.containsKey(packetId);

  /// All envelopes whose ack deadline has passed (delivery ACK).
  List<String> timedOut(DateTime now) {
    final due = <String>[];
    _awaiting.removeWhere((id, deadline) {
      if (deadline.isBefore(now)) {
        due.add(id);
        return true;
      }
      return false;
    });
    return due;
  }

  /// Envelopes whose relay ACK deadline has passed.
  List<String> relayTimedOut(DateTime now) {
    final due = <String>[];
    _awaitingRelay.removeWhere((id, exp) {
      if (exp.deadline.isBefore(now)) {
        due.add(id);
        return true;
      }
      return false;
    });
    return due;
  }

  /// Envelopes whose forward ACK deadline has passed.
  List<String> forwardTimedOut(DateTime now) {
    final due = <String>[];
    _awaitingForward.removeWhere((id, exp) {
      if (exp.deadline.isBefore(now)) {
        due.add(id);
        return true;
      }
      return false;
    });
    return due;
  }

  /// All envelopes with any ACK timeout.
  List<String> allTimedOut(DateTime now) {
    return [...timedOut(now), ...relayTimedOut(now), ...forwardTimedOut(now)];
  }

  void forget(String packetId) {
    _awaiting.remove(packetId);
    _awaitingRelay.remove(packetId);
    _awaitingForward.remove(packetId);
  }

  int get pendingAckCount => _awaiting.length;
  int get pendingRelayAckCount => _awaitingRelay.length;
  int get pendingForwardAckCount => _awaitingForward.length;

  bool _remember(String packetId, DateTime at) {
    _prune(at);
    if (_ledger.entries.any((e) => e.value.contains(packetId))) {
      return false;
    }
    _ledger.putIfAbsent(at, () => <String>{}).add(packetId);
    _trim();
    return true;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(_ledgerWindow);
    while (_ledger.isNotEmpty && _ledger.firstKey()!.isBefore(cutoff)) {
      _ledger.remove(_ledger.firstKey());
    }
  }

  void _trim() {
    while (_ledger.length > _ledgerCap) {
      _ledger.remove(_ledger.firstKey());
    }
  }
}

class _RelayAckExpectation {
  const _RelayAckExpectation({required this.relayId, required this.deadline});
  final String relayId;
  final DateTime deadline;
}

class _ForwardAckExpectation {
  const _ForwardAckExpectation({
    required this.nextHopId,
    required this.deadline,
  });
  final String nextHopId;
  final DateTime deadline;
}
