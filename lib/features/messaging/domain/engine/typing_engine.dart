import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../messages/typing_state.dart';

/// In-memory typing presence layer.
///
/// Remote typing beacons are transient by nature; nothing is persisted
/// (except developer diagnostics rows, written by the engine through the
/// [onDiagnostics] hook). The bus follows the documented phase machine:
///
/// ```
/// idle ─ started ─→ typing ─ stopped ─→ idle
///      └ started ─→ typing ─ (timeoutAfter) ─→ timeout ─ (idleAfter) ─→ idle
/// ```
///
/// Wire flooding is bounded by [minBeaconInterval]: at most one envelope per
/// channel per interval, no matter how many local input events arrive.
final class TypingEngine {
  TypingEngine({
    this.timeoutAfter = const Duration(seconds: 5),
    this.idleAfter = const Duration(seconds: 2),
    this.minBeaconInterval = const Duration(seconds: 1),
    this.onDiagnostics,
  });

  /// How long a typing indicator stays active without a new beacon.
  final Duration timeoutAfter;

  /// How long the `timeout` phase lingers before falling back to `idle`.
  final Duration idleAfter;

  /// Hard wire throttle: one beacon per channel per interval.
  final Duration minBeaconInterval;

  /// Hook for developer diagnostics rows (engine wires the channel repo).
  final void Function({
    required String channelId,
    required String node,
    required TypingPhase phase,
    DateTime since,
  })?
  onDiagnostics;

  final Map<String, Timer> _expiryTimers = {};
  final Map<String, Timer> _idleTimers = {};
  final Map<String, TypingState> _states = {};
  final Map<String, DateTime> _lastBeaconAt = {};
  final _controller = StreamController<TypingState>.broadcast();
  bool _disposed = false;

  /// Observable set of active `channelId::node` keys (UI contract).
  final ValueNotifier<Set<String>> typingKeys = ValueNotifier(const <String>{});

  static String _key(String channelId, String node) => '$channelId::$node';

  /// Live phases of every active indicator (UI contract).
  Stream<TypingState> get changes => _controller.stream;

  /// Marks [node] as typing in [channelId]; the indicator auto-expires.
  /// Returns true when the local bus state actually changed.
  bool startTyping(String channelId, String node) {
    final key = _key(channelId, node);
    _idleTimers.remove(key)?.cancel();
    final previous = _states[key];
    if (previous != null && previous.state == TypingPhase.started) {
      _expiryTimers.remove(key)?.cancel();
      _expiryTimers[key] = Timer(timeoutAfter, () => _timeout(key));
      return false;
    }
    final state = TypingState(
      node: node,
      channelId: channelId,
      state: TypingPhase.started,
      since: DateTime.now(),
    );
    _states[key] = state;
    _setKeys();
    _controller.add(state);
    _expiryTimers.remove(key)?.cancel();
    _expiryTimers[key] = Timer(timeoutAfter, () => _timeout(key));
    _diagnose(state);
    return true;
  }

  /// Marks [node] as no longer typing.
  void stopTyping(String channelId, String node) {
    final key = _key(channelId, node);
    _expiryTimers.remove(key)?.cancel();
    _idleTimers.remove(key)?.cancel();
    final previous = _states.remove(key);
    if (previous == null) return;
    final stopped = previous.copyWith(
      state: TypingPhase.stopped,
      since: DateTime.now(),
    );
    _controller.add(stopped);
    _setKeys();
    _diagnose(stopped);
    final idle = stopped.copyWith(state: TypingPhase.idle);
    _controller.add(idle);
  }

  bool isTyping(String channelId, String node) {
    final state = _states[_key(channelId, node)];
    return state != null && state.isTyping;
  }

  /// The current phase of (channelId, node), or [TypingPhase.idle] when
  /// absent.
  TypingPhase phaseOf(String channelId, String node) =>
      _states[_key(channelId, node)]?.state ?? TypingPhase.idle;

  /// Whether a typing beacon may go on the wire: started/stopped transitions
  /// are always sendable but each channel is throttled to
  /// [minBeaconInterval].
  bool shouldSendBeacon(String channelId, {required bool started}) {
    final now = DateTime.now();
    if (started) {
      // A repeat "started" within the interval is throttled; the bus still
      // refreshed its own expiry timer in [startTyping].
      final last = _lastBeaconAt[channelId];
      if (last != null &&
          !now.difference(last).isNegative &&
          now.difference(last) < minBeaconInterval) {
        return false;
      }
    }
    return true;
  }

  /// Records that a beacon left this node (throttle bookkeeping).
  void markBeaconSent(String channelId) {
    _lastBeaconAt[channelId] = DateTime.now();
  }

  void _timeout(String key) {
    _expiryTimers.remove(key);
    final state = _states[key];
    if (state == null) return;
    final expired = state.copyWith(
      state: TypingPhase.timeout,
      since: DateTime.now(),
    );
    _states[key] = expired;
    _controller.add(expired);
    _diagnose(expired);
    _setKeys();
    _idleTimers[key] = Timer(idleAfter, () => _idle(key));
  }

  void _idle(String key) {
    _idleTimers.remove(key);
    final state = _states.remove(key);
    _setKeys();
    if (state == null) return;
    final idle = state.copyWith(state: TypingPhase.idle, since: DateTime.now());
    _controller.add(idle);
  }

  void _setKeys() {
    typingKeys.value = UnmodifiableSetView(
      _states.entries.where((e) => e.value.isTyping).map((e) => e.key).toSet(),
    );
  }

  void _diagnose(TypingState state) {
    onDiagnostics?.call(
      channelId: state.channelId,
      node: state.node,
      phase: state.state,
      since: state.since,
    );
  }

  /// Whether [dispose] was already called (the engine replaces the bus
  /// rather than reusing a closed one).
  bool get isDisposed => _disposed;

  /// Cancels all pending timers and closes the bus (engine shutdown).
  void dispose() {
    _disposed = true;
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    for (final timer in _idleTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    _idleTimers.clear();
    _states.clear();
    _lastBeaconAt.clear();
    if (!_controller.isClosed) {
      _controller.close();
    }
    typingKeys.dispose();
  }
}
