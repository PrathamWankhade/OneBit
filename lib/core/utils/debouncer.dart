import 'dart:async';

/// Executes a callback only after the caller has stopped emitting events
/// for [duration]. Typical use: search-as-you-type, BLE reconnection flaps.
final class Debouncer<T> {
  Debouncer({required this.duration});

  /// Quiet window after the last call before [onEmit] fires.
  final Duration duration;

  Timer? _timer;

  /// Restarts the countdown. The callback receives the latest [value].
  void debounce(T value, void Function(T value) onEmit) {
    _timer?.cancel();
    _timer = Timer(duration, () => onEmit(value));
  }

  /// Immediately cancels any pending invocation.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
