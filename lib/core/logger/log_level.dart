/// Severity of a [LogRecord].
///
/// Ordered by increasing importance so filters can compare levels with
/// `>=` / `<=`.
enum LogLevel {
  /// Deepest diagnostics: byte dumps, token traffic (never enabled in prod).
  trace(0, 'TRACE'),

  /// Detailed flow information for debugging a feature.
  debug(1, 'DEBUG'),

  /// Normal operational events (startup, connection established).
  info(2, 'INFO'),

  /// Notable but non-fatal conditions (retry scheduled, degraded mode).
  warning(3, 'WARN'),

  /// A failure occurred and was handled by the failure framework.
  error(4, 'ERROR'),

  /// A failure that ended a whole workflow.
  fatal(5, 'FATAL');

  const LogLevel(this.severity, this.label);

  /// Numeric weight; higher = more severe.
  final int severity;

  /// Stable 5-char label used in rendered log lines.
  final String label;

  /// Returns the least severe level that satisfies [label] (or [trace] when
  /// the label is unknown). Used when parsing runtime configuration.
  static LogLevel fromName(String? name) {
    for (final level in values) {
      if (level.name == name) return level;
    }
    return LogLevel.trace;
  }

  /// True when this level is at least as severe as [other].
  bool atLeast(LogLevel other) => severity >= other.severity;
}
