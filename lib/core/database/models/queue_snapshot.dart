import 'package:flutter/foundation.dart';

/// Point-in-time counts of the outbound processing queues.
@immutable
final class QueueSnapshot {
  const QueueSnapshot({
    required this.pending,
    required this.retrying,
    required this.relaying,
  });

  /// Items in the pending (outbound) queue.
  final int pending;

  /// Items awaiting retry with backoff.
  final int retrying;

  /// Items scheduled for relay.
  final int relaying;

  int get total => pending + retrying + relaying;
}
