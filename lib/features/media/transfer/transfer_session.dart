import 'package:flutter/foundation.dart';

import 'transfer_bitmap.dart';
import 'transfer_state.dart';

/// One chunked file transfer between this node and [peerNodeId].
///
/// Immutable; every lifecycle transition produces a new instance that the
/// [TransferEngine] persists before returning. The bitmap is the
/// authoritative progress record — [bytesTransferred] is derived from it.
@immutable
final class TransferSession {
  const TransferSession({
    required this.sessionId,
    required this.attachmentId,
    required this.peerNodeId,
    required this.direction,
    required this.state,
    required this.chunkSize,
    required this.totalChunks,
    required this.chunksBitmap,
    required this.bytesTransferred,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.lastError,
    this.attemptCount = 0,
    this.ttl,
  });

  final String sessionId;

  /// The catalog attachment this session transfers.
  final String attachmentId;

  /// The remote node (recipient for `send`, sender for `receive`).
  final String peerNodeId;

  final TransferDirection direction;

  final TransferState state;

  /// Payload bytes per chunk (the wire unit).
  final int chunkSize;

  /// `ceil(sizeBytes / chunkSize)`, K ≥ 1.
  final int totalChunks;

  /// Set of acknowledged / received-and-verified chunks.
  final TransferBitmap chunksBitmap;

  /// Sum of the sizes of acknowledged chunks (progress in bytes).
  final int bytesTransferred;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// Human-readable reason of the latest failure.
  final String? lastError;

  /// How many times this session was (re)started.
  final int attemptCount;

  /// Optional session lifetime; expired sessions are swept on maintenance.
  final Duration? ttl;

  /// True when every chunk is acknowledged.
  bool get isComplete => chunksBitmap.isComplete;

  /// 0..1 progress fraction.
  double get progress => chunksBitmap.progress;

  TransferSession copyWith({
    TransferState? state,
    TransferBitmap? chunksBitmap,
    int? bytesTransferred,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? lastError,
    int? attemptCount,
    Duration? ttl,
  }) => TransferSession(
    sessionId: sessionId,
    attachmentId: attachmentId,
    peerNodeId: peerNodeId,
    direction: direction,
    state: state ?? this.state,
    chunkSize: chunkSize,
    totalChunks: totalChunks,
    chunksBitmap: chunksBitmap ?? this.chunksBitmap,
    bytesTransferred: bytesTransferred ?? this.bytesTransferred,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
    lastError: lastError ?? this.lastError,
    attemptCount: attemptCount ?? this.attemptCount,
    ttl: ttl ?? this.ttl,
  );

  @override
  bool operator ==(Object other) =>
      other is TransferSession && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() =>
      'TransferSession($sessionId '
      '$attachmentId→$peerNodeId [$direction/$state '
      '${chunksBitmap.acknowledgedCount}/$totalChunks])';
}
