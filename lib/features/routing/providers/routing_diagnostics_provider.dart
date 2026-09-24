import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/routing/providers/routing_providers.dart';
import 'package:onebit/features/routing/reachability_reason.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_security.dart';

/// Read-only snapshot of the entire routing system state.
///
/// Computed from existing routing services. Contains no mutable state.
class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.neighborCount,
    required this.reachablePeerCount,
    required this.topologySourceCount,
    required this.activeRouteCount,
    required this.securityEventCount,
    required this.neighbors,
    required this.reachablePeers,
    required this.topologyEntries,
    required this.routes,
    required this.securityEvents,
    required this.recoveringDestinations,
    required this.generatedAt,
  });

  final int neighborCount;
  final int reachablePeerCount;
  final int topologySourceCount;
  final int activeRouteCount;
  final int securityEventCount;
  final List<NeighborDiagnostics> neighbors;
  final List<String> reachablePeers;
  final List<TopologyEntryDiagnostics> topologyEntries;
  final List<RouteDiagnostics> routes;
  final List<SecurityEventDiagnostics> securityEvents;
  final List<String> recoveringDestinations;
  final DateTime generatedAt;
}

/// Diagnostics data for a single neighbor.
class NeighborDiagnostics {
  const NeighborDiagnostics({
    required this.peerId,
    required this.isActive,
    required this.isReachable,
    required this.reachabilityReason,
  });

  final String peerId;
  final bool isActive;
  final bool isReachable;
  final ReachabilityReason reachabilityReason;
}

/// Diagnostics data for a topology entry.
class TopologyEntryDiagnostics {
  const TopologyEntryDiagnostics({
    required this.sourceIdentity,
    required this.neighborCount,
    required this.sequence,
    required this.receivedAt,
  });

  final String sourceIdentity;
  final int neighborCount;
  final int sequence;
  final DateTime receivedAt;
}

/// Diagnostics data for a single route.
class RouteDiagnostics {
  const RouteDiagnostics({
    required this.destinationPeerId,
    required this.nextHopPeerId,
    required this.metric,
    required this.state,
    required this.source,
    required this.expiresAt,
  });

  final String destinationPeerId;
  final String nextHopPeerId;
  final int metric;
  final RouteState state;
  final RouteSource source;
  final DateTime? expiresAt;

  factory RouteDiagnostics.fromRoute(Route route) {
    return RouteDiagnostics(
      destinationPeerId: route.destinationPeerId,
      nextHopPeerId: route.nextHopPeerId,
      metric: route.metric,
      state: route.state,
      source: route.source,
      expiresAt: route.expiresAt,
    );
  }
}

/// Diagnostics data for a security event.
class SecurityEventDiagnostics {
  const SecurityEventDiagnostics({
    required this.peerId,
    required this.event,
  });

  final String peerId;
  final RoutingSecurityEvent event;
}

/// Computes a read-only snapshot of routing diagnostics.
///
/// Reads from all routing services without modifying any state.
final routingDiagnosticsProvider = Provider<DiagnosticsSnapshot>((ref) {
  final neighborTable = ref.watch(neighborTableProvider);
  final reachability = ref.watch(peerReachabilityProvider);
  final repository = ref.watch(topologyRepositoryProvider);
  final routingTable = ref.watch(routingTableProvider);
  final securityValidator = ref.watch(routingSecurityValidatorProvider);
  final recoveryService = ref.watch(routeRecoveryServiceProvider);

  // Neighbors
  final allEntries = neighborTable.allEntries;
  final neighborDiags = allEntries.map((entry) {
    final peerId = entry.peerId;
    return NeighborDiagnostics(
      peerId: peerId,
      isActive: entry.isActive,
      isReachable: reachability.isReachable(peerId),
      reachabilityReason: reachability.getReachability(peerId),
    );
  }).toList();

  // Reachable peers
  final reachablePeers = reachability.getReachableNeighbors();

  // Topology
  final topologyEntries = repository.remoteEntries.map((entry) {
    return TopologyEntryDiagnostics(
      sourceIdentity: entry.sourceIdentity,
      neighborCount: entry.neighborPeerIds.length,
      sequence: entry.sequence,
      receivedAt: entry.receivedAt,
    );
  }).toList();

  // Routes
  final routes = routingTable.allRoutes.map(RouteDiagnostics.fromRoute).toList();

  // Security events
  final securityEvents = securityValidator.eventLog
      .map((entry) => SecurityEventDiagnostics(
            peerId: entry.$1,
            event: entry.$2,
          ))
      .toList();

  // Recovering destinations
  final recoveringDestinations = <String>[];
  for (final route in routingTable.allRoutes) {
    if (recoveryService.isRecovering(route.destinationPeerId)) {
      recoveringDestinations.add(route.destinationPeerId);
    }
  }

  return DiagnosticsSnapshot(
    neighborCount: neighborTable.count,
    reachablePeerCount: reachablePeers.length,
    topologySourceCount: repository.remoteSourceCount,
    activeRouteCount: routingTable.activeRoutes.length,
    securityEventCount: securityValidator.eventLog.length,
    neighbors: neighborDiags,
    reachablePeers: reachablePeers,
    topologyEntries: topologyEntries,
    routes: routes,
    securityEvents: securityEvents,
    recoveringDestinations: recoveringDestinations,
    generatedAt: DateTime.now(),
  );
});
