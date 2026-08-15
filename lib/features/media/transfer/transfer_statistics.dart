import 'package:flutter/foundation.dart';

/// Counters and gauges of the transfer subsystem.
///
/// Produced by the transfer repository from the durable `MediaStatistics`
/// mirror plus live table aggregates; the UI/statistics providers consume
/// it as an immutable snapshot.
@immutable
final class TransferStatistics {
  const TransferStatistics({
    this.sessionsStarted = 0,
    this.activeSessions = 0,
    this.completedSessions = 0,
    this.failedSessions = 0,
    this.cancelledSessions = 0,
    this.expiredSessions = 0,
    this.bytesTransferred = 0,
    this.bytesReceived = 0,
    this.chunksSent = 0,
    this.chunksReceived = 0,
    this.chunkRetries = 0,
    this.averageChunkRate = 0,
    this.peakInFlight = 0,
  });

  final int sessionsStarted;
  final int activeSessions;

  /// Sessions that reached [TransferState.completed].
  final int completedSessions;

  final int failedSessions;
  final int cancelledSessions;
  final int expiredSessions;

  /// Payload bytes acknowledged across send sessions.
  final int bytesTransferred;

  /// Payload bytes verified across receive sessions.
  final int bytesReceived;

  final int chunksSent;
  final int chunksReceived;

  /// Extra transmission attempts caused by nacks / timeouts.
  final int chunkRetries;

  /// Chunks per second across both directions (smoothed gauge).
  final double averageChunkRate;

  /// Highest number of chunks in flight at once (gauge).
  final int peakInFlight;

  static const TransferStatistics empty = TransferStatistics();

  TransferStatistics copyWith({
    int? sessionsStarted,
    int? activeSessions,
    int? completedSessions,
    int? failedSessions,
    int? cancelledSessions,
    int? expiredSessions,
    int? bytesTransferred,
    int? bytesReceived,
    int? chunksSent,
    int? chunksReceived,
    int? chunkRetries,
    double? averageChunkRate,
    int? peakInFlight,
  }) => TransferStatistics(
    sessionsStarted: sessionsStarted ?? this.sessionsStarted,
    activeSessions: activeSessions ?? this.activeSessions,
    completedSessions: completedSessions ?? this.completedSessions,
    failedSessions: failedSessions ?? this.failedSessions,
    cancelledSessions: cancelledSessions ?? this.cancelledSessions,
    expiredSessions: expiredSessions ?? this.expiredSessions,
    bytesTransferred: bytesTransferred ?? this.bytesTransferred,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    chunksSent: chunksSent ?? this.chunksSent,
    chunksReceived: chunksReceived ?? this.chunksReceived,
    chunkRetries: chunkRetries ?? this.chunkRetries,
    averageChunkRate: averageChunkRate ?? this.averageChunkRate,
    peakInFlight: peakInFlight ?? this.peakInFlight,
  );
}

/// Stable keys of the `MediaStatistics` counter mirror.
abstract final class MediaStatConstants {
  const MediaStatConstants._();

  static const String sessionsStarted = 'sessionsStarted';
  static const String sessionsCompleted = 'sessionsCompleted';
  static const String sessionsFailed = 'sessionsFailed';
  static const String sessionsCancelled = 'sessionsCancelled';
  static const String sessionsExpired = 'sessionsExpired';
  static const String chunksSent = 'chunksSent';
  static const String chunksReceived = 'chunksReceived';
  static const String chunkRetries = 'chunkRetries';
  static const String peakInFlight = 'peakInFlight';
  static const String bytesReceived = 'bytesReceived';
  static const String bytesTransferred = 'bytesTransferred';

  /// Every counter key (for maintenance queries).
  static const List<String> all = [
    sessionsStarted,
    sessionsCompleted,
    sessionsFailed,
    sessionsCancelled,
    sessionsExpired,
    chunksSent,
    chunksReceived,
    chunkRetries,
    peakInFlight,
    bytesReceived,
    bytesTransferred,
  ];
}
