import 'package:flutter/foundation.dart';

/// Connection behaviour for one peer link.
@immutable
final class ConnectionOptions {
  const ConnectionOptions({
    this.autoReconnect = true,
    this.maxRetries = 3,
    this.connectTimeout = const Duration(seconds: 20),
    this.retryDelay = const Duration(seconds: 5),
    this.retryBackoff = 1.5,
    this.requestMtu = 512,
    this.preferL2cap = false,
  });

  /// Whether to attempt automatic reconnect after an unexpected loss.
  final bool autoReconnect;

  /// Max reconnect attempts per session; 0 disables reconnects.
  final int maxRetries;

  /// How long a single connect attempt may take before failing.
  final Duration connectTimeout;

  /// Base delay before the first reconnect attempt.
  final Duration retryDelay;

  /// Multiplier applied to [retryDelay] after each failed attempt.
  final double retryBackoff;

  /// Requested MTU; the native side negotiates up to this value and falls
  /// back gracefully (see [MTUManager] docs).
  final int requestMtu;

  /// When true, prefer a connection-oriented channel where the platform
  /// exposes one (Android 13+ L2CAP over LE).
  final bool preferL2cap;

  ConnectionOptions copyWith({Duration? connectTimeout}) => ConnectionOptions(
    autoReconnect: autoReconnect,
    maxRetries: maxRetries,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    retryDelay: retryDelay,
    retryBackoff: retryBackoff,
    requestMtu: requestMtu,
    preferL2cap: preferL2cap,
  );
}
