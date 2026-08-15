import 'package:onebit/features/mesh/domain/mesh_packet.dart';

/// A queued forward awaiting the transport.
final class RelayTask {
  RelayTask({required this.to, required this.packet, required this.enqueuedAt});

  final String to;
  final MeshPacket packet;
  final DateTime enqueuedAt;
}

/// The seam for outbound relay work.
///
/// Today the engine drains the queue immediately on its sweep tick; a later
/// store-and-forward phase persists it and drains when the destination is
/// next observed — the engine API stays identical.
abstract interface class RelayQueue {
  /// Queues [task]; returns `false` when the queue is full.
  bool enqueue(RelayTask task);

  /// Pops the next task, or `null`.
  RelayTask? next();

  /// Removes [task] when still queued — the engine does this after
  /// dispatching it immediately, so the sweep tick does not resend it.
  void remove(RelayTask task);

  /// Number of queued tasks.
  int get size;

  /// Maximum capacity.
  int get capacity;

  /// Discards every task.
  void clear();
}

/// In-memory FIFO with a hard capacity (memory bounded).
final class InMemoryRelayQueue implements RelayQueue {
  InMemoryRelayQueue({this.capacity = 64});

  @override
  final int capacity;
  final List<RelayTask> _tasks = [];

  @override
  bool enqueue(RelayTask task) {
    if (_tasks.length >= capacity) return false;
    _tasks.add(task);
    return true;
  }

  @override
  RelayTask? next() {
    if (_tasks.isEmpty) return null;
    return _tasks.removeAt(0);
  }

  @override
  void remove(RelayTask task) {
    final index = _tasks.indexOf(task);
    if (index != -1) _tasks.removeAt(index);
  }

  @override
  int get size => _tasks.length;

  @override
  void clear() => _tasks.clear();
}
