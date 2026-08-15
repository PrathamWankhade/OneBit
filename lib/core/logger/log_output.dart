import 'dart:collection';

import 'package:onebit/core/logger/log_record.dart';

/// Destination for formatted log records.
///
/// Implementations must be cheap and must never throw: a logging failure
/// must not take down the calling business flow. All output sinks are
/// synchronous by contract to keep record ordering deterministic.
abstract interface class LogOutput {
  /// Writes [record] to the destination.
  ///
  /// Implementations must catch their own errors internally.
  void write(LogRecord record);

  /// Called once during application shutdown, if the output needs to flush.
  void dispose() {}
}

/// [LogOutput] that fans a record out to multiple sinks.
///
/// The group never fails even when one of its members throws.
final class LogOutputGroup implements LogOutput {
  LogOutputGroup(Iterable<LogOutput> outputs) : _outputs = List.of(outputs);

  final List<LogOutput> _outputs;

  @override
  void write(LogRecord record) {
    for (final output in _outputs) {
      try {
        output.write(record);
      } catch (_) {
        // A broken sink must not break the whole pipeline.
      }
    }
  }

  @override
  void dispose() {
    for (final output in _outputs) {
      try {
        output.dispose();
      } catch (_) {
        // Intentionally ignored during shutdown.
      }
    }
  }
}

/// In-memory ring buffer that keeps the most recent [capacity] records.
///
/// Powers the developer log panel and debug screens without any platform
/// I/O. Snapshots are immutable lists safe for widgets to render.
final class BufferLogOutput implements LogOutput {
  BufferLogOutput({int capacity = 256})
    : assert(capacity > 0, 'capacity must be positive'),
      _capacity = capacity;

  final int _capacity;
  final ListQueue<LogRecord> _records = ListQueue();

  /// Most recently written records, oldest first, capped at [capacity].
  List<LogRecord> snapshot() => List.unmodifiable(_records);

  @override
  void write(LogRecord record) {
    _records.addLast(record);
    while (_records.length > _capacity) {
      _records.removeFirst();
    }
  }

  /// Removes all buffered records.
  void clear() {
    _records.clear();
  }

  @override
  void dispose() {
    _records.clear();
  }
}
