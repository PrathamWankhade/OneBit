import 'dart:async';

/// A handle that cancels a scheduled callback before it runs.
abstract interface class MeshScheduledTask {
  /// Cancels the callback; safe to call more than once.
  void cancel();
}

/// Time source for the mesh engines.
///
/// Engines never call `DateTime.now()` directly: they ask the injected
/// [MeshClock], which lets unit tests and the simulation drive time
/// deterministically. The clock also owns scheduling, so the engine's
/// sweep loop can be stepped manually in tests.
abstract interface class MeshClock {
  /// The current mesh time.
  DateTime now();

  /// Schedules [callback] to run after [delay].
  MeshScheduledTask schedule(Duration delay, void Function() callback);
}

/// Production clock backed by `DateTime.now()` and `Timer`.
final class SystemMeshClock implements MeshClock {
  const SystemMeshClock();

  @override
  DateTime now() => DateTime.now();

  @override
  MeshScheduledTask schedule(Duration delay, void Function() callback) {
    final timer = Timer(delay, callback);
    return _TimerTask(timer);
  }
}

final class _TimerTask implements MeshScheduledTask {
  _TimerTask(this._timer);

  final Timer _timer;
  bool _cancelled = false;

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _timer.cancel();
  }
}

/// Fully deterministic clock for tests and the headless simulator.
///
/// Time only advances when [advance] or [runPending] is called. Scheduled
/// callbacks run in due-time order, including callbacks scheduled from
/// inside other callbacks.
final class ManualMeshClock implements MeshClock {
  ManualMeshClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 1, 1);

  DateTime _now;
  final List<_ManualTask> _pending = [];

  /// Current simulated time.
  @override
  DateTime now() => _now;

  /// Number of not-yet-run scheduled callbacks.
  int get pendingCount => _pending.length;

  /// Advances time by [delta], running every callback that became due.
  ///
  /// The clock jumps to each due time in order, so timer chains (a callback
  /// scheduling another callback) fire in the correct sequence.
  void advance(Duration delta) {
    final target = _now.add(delta);
    _runUntil(target);
    _now = target;
  }

  /// Runs the callbacks due at (or before) the current time, without moving
  /// the clock.
  void runPending() {
    final target = _now;
    _runUntil(target);
  }

  void _runUntil(DateTime target) {
    while (true) {
      _ManualTask? next;
      for (final task in _pending) {
        if (task.cancelled) continue;
        if (next == null || task.due.isBefore(next.due)) next = task;
      }
      if (next == null || next.due.isAfter(target)) return;
      _now = next.due;
      next.cancelled = true;
      _pending.remove(next);
      next.callback();
    }
  }

  @override
  MeshScheduledTask schedule(Duration delay, void Function() callback) {
    final task = _ManualTask(_now.add(delay), callback);
    _pending.add(task);
    return task;
  }
}

final class _ManualTask implements MeshScheduledTask {
  _ManualTask(this.due, this.callback);

  final DateTime due;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
  }
}
