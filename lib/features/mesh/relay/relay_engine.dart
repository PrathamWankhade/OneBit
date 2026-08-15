import 'dart:async';

import 'package:onebit/features/mesh/domain/mesh_events.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import '../cache/duplicate_packet_detector.dart';
import '../routing/loop_detector.dart';
import '../routing/routing_engine.dart';
import 'relay_decision.dart';
import 'relay_queue.dart';
import 'ttl_manager.dart';

/// The outcome of a relay pass, consumed by the engine.
sealed class RelayOutcome {
  const RelayOutcome();
}

/// Deliver the packet to the local node.
final class RelayDeliverUp extends RelayOutcome {
  const RelayDeliverUp(this.packet);

  final MeshPacket packet;
}

/// The packet was queued for one or more forwards.
final class RelayQueued extends RelayOutcome {
  const RelayQueued(this.forwards);

  final List<RelayTask> forwards;
}

/// The packet was dropped for [reason].
final class RelayDropped extends RelayOutcome {
  const RelayDropped(this.packet, this.reason);

  final MeshPacket packet;
  final RelayDropReason reason;
}

/// The relay pipeline: decide, queue, and report every inbound packet.
///
/// Rules run in order, first match wins:
///   1. addressed to us            → DeliverUp
///   2. we originated it           → Drop(ownPacket)
///   3. TTL already spent          → Drop(ttlExpired)
///   4. already seen               → Drop(duplicate)
///   5. re-enters our path         → Drop(loop)
///   6. broadcast                  → Forward to every safe neighbor
///   7. discovery reply path       → Forward along the recorded path
///   8. route exists               → Forward
///   9. otherwise                  → Drop(noRoute)
///
/// Forwards are written into the injected [RelayQueue]; the engine drains
/// the queue and pushes each task to the transport. Statistics and the
/// relay log consume [events].
final class RelayEngine {
  RelayEngine({
    required this.localNodeId,
    required this._routing,
    required this._ttl,
    required this._loopDetector,
    required this._duplicateDetector,
    required this._queue,
    required this._liveNeighborIds,
    required this._now,
  });

  final String localNodeId;
  final RoutingEngine _routing;
  final TTLManager _ttl;
  final LoopDetector _loopDetector;
  final DuplicatePacketDetector _duplicateDetector;
  final RelayQueue _queue;
  final List<String> Function() _liveNeighborIds;
  final DateTime Function() _now;

  final StreamController<MeshRelayEvent> _events =
      StreamController<MeshRelayEvent>.broadcast();

  /// Every relay decision, for UI, statistics and diagnostics.
  Stream<MeshRelayEvent> get events => _events.stream;

  /// Pending forwards.
  int get queueSize => _queue.size;

  /// Picks the next queued forward, or `null`.
  RelayTask? dequeue() => _queue.next();

  /// Marks [task] delivered to the transport immediately, so the pending
  /// sweep tick will not resend it.
  void removeQueued(RelayTask task) => _queue.remove(task);

  RelayOutcome decide(MeshPacket packet, {bool origin = false}) {
    if (packet.destination == localNodeId) {
      _emit(MeshRelayEventKind.deliveredUp, packet);
      return RelayDeliverUp(packet);
    }
    if (!origin && packet.source == localNodeId) {
      return _drop(packet, RelayDropReason.ownPacket);
    }
    if (_ttl.isExpired(packet)) {
      return _drop(packet, RelayDropReason.ttlExpired);
    }
    if (!_duplicateDetector.markSeen(packet)) {
      return _drop(packet, RelayDropReason.duplicate);
    }
    if (_loopDetector.wouldReenter(packet, localNodeId) && !origin) {
      return _drop(packet, RelayDropReason.loop);
    }

    if (packet.isBroadcast) {
      return _broadcast(packet);
    }

    final viaPath = _routing.nextHopForControl(packet);
    if (viaPath != null) {
      return _forwardSingle(packet, viaPath);
    }

    final route = _routing.route(packet.destination);
    if (route != null) {
      return _forwardSingle(packet, route.nextHop);
    }

    return _drop(packet, RelayDropReason.noRoute);
  }

  RelayOutcome _broadcast(MeshPacket packet) {
    final forwards = <RelayTask>[];
    for (final neighbor in _liveNeighborIds()) {
      if (_loopDetector.wouldCreateLoop(packet, neighbor)) continue;
      final relayed = _advance(packet);
      if (relayed == null) continue;
      final task = RelayTask(to: neighbor, packet: relayed, enqueuedAt: _now());
      if (_queue.enqueue(task)) {
        forwards.add(task);
        _emit(MeshRelayEventKind.forwarded, packet, nextHop: neighbor);
      } else {
        _queueFull(task);
      }
    }
    return RelayQueued(forwards);
  }

  RelayOutcome _forwardSingle(MeshPacket packet, String nextHop) {
    final relayed = _advance(packet);
    if (relayed == null) {
      return _drop(packet, RelayDropReason.ttlExpired);
    }
    final task = RelayTask(to: nextHop, packet: relayed, enqueuedAt: _now());
    if (!_queue.enqueue(task)) {
      _queueFull(task);
      return _drop(packet, RelayDropReason.queueFull);
    }
    _emit(MeshRelayEventKind.forwarded, packet, nextHop: nextHop);
    return RelayQueued([task]);
  }

  /// Returns the TTL-decremented packet with this node appended to its
  /// path, or `null` when TTL was exhausted.
  MeshPacket? _advance(MeshPacket packet) {
    final next = _ttl.next(packet);
    return next?.relayedBy(localNodeId);
  }

  RelayDropped _drop(MeshPacket packet, RelayDropReason reason) {
    _emit(MeshRelayEventKind.dropped, packet, dropReason: reason.name);
    return RelayDropped(packet, reason);
  }

  void _queueFull(RelayTask task) {
    _emit(
      MeshRelayEventKind.dropped,
      task.packet,
      nextHop: task.to,
      dropReason: RelayDropReason.queueFull.name,
    );
  }

  void _emit(
    MeshRelayEventKind kind,
    MeshPacket packet, {
    String? nextHop,
    String? dropReason,
  }) {
    _events.add(
      MeshRelayEvent(
        kind: kind,
        source: packet.source,
        destination: packet.destination,
        sequence: packet.sequence,
        hopCount: packet.hopCount,
        ttl: packet.ttl,
        at: _now(),
        nextHop: nextHop,
        dropReason: dropReason,
      ),
    );
  }

  void dispose() {
    _events.close();
  }
}
