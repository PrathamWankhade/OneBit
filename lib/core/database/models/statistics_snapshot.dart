import 'package:flutter/foundation.dart';

/// Point-in-time aggregate counts across the mesh tables.
@immutable
final class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.messages,
    required this.packets,
    required this.routes,
    required this.neighbors,
    required this.trustedNodes,
    required this.sessions,
    required this.logs,
    required this.stats,
  });

  final int messages;
  final int packets;
  final int routes;
  final int neighbors;
  final int trustedNodes;
  final int sessions;
  final int logs;
  final int stats;
}
