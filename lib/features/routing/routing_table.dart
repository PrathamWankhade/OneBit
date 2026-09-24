/// I8.5 — The routing table.
///
/// The routing table is the runtime collection of routes.
/// It provides lookup, insertion, expiration, and best-route selection.
///
/// Key principles:
/// - Routes are keyed by destination peer ID
/// - Multiple routes to the same destination are supported
/// - Duplicate route advertisements are deduplicated
/// - Stale routes are detected and expired
/// - The table does not create connections or sessions
library;

import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_selector.dart';
import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/routing_validators.dart';

/// Maximum allowed metric value for routes.
///
/// Prevents unrealistic/unbounded route metrics.
const int maxRouteMetric = RoutingLimits.maxRouteMetric;

/// Thrown when a route fails validation during insertion.
class RouteValidationException implements Exception {
  const RouteValidationException(this.message);
  final String message;

  @override
  String toString() => 'RouteValidationException: $message';
}

/// The routing table — a collection of routes indexed by destination.
///
/// Provides:
/// - Route lookup by destination
/// - Best route selection (lowest metric)
/// - Route insertion and removal
/// - Stale route detection
/// - Bulk operations for topology changes
///
/// If [localPeerId] is provided, self-destination and self-as-next-hop
/// routes are rejected on insertion.
class RoutingTable {
  RoutingTable({this.localPeerId});

  /// The local node's peer ID, if known.
  ///
  /// When set, routes targeting the local node as destination or
  /// using the local node as next hop are rejected.
  final String? localPeerId;

  /// Routes indexed by destination peer ID.
  /// Each destination may have multiple routes (from different next hops).
  final Map<String, List<Route>> _routesByDestination = {};

  /// All routes, flattened as an immutable copy.
  List<Route> get allRoutes =>
      _routesByDestination.values.expand((r) => r).toList();

  /// All active routes.
  List<Route> get activeRoutes =>
      allRoutes.where((r) => r.isActive).toList();

  /// Number of destinations with at least one route.
  int get destinationCount => _routesByDestination.length;

  /// Total number of route entries (including stale/invalid).
  int get routeCount => allRoutes.length;

  /// Get all routes to a specific destination.
  List<Route> routesTo(String destinationPeerId) =>
      _routesByDestination[destinationPeerId] ?? [];

  /// Get the best active route to a destination.
  ///
  /// Uses the I8.7 selection policy: lowest metric wins,
  /// with `PeerId` tie-breaking on `nextHopPeerId`.
  ///
  /// Returns null if no active route exists.
  Route? bestRoute(String destinationPeerId) {
    final routes = routesTo(destinationPeerId)
        .where((r) => r.isActive)
        .toList();
    return selectBestRoute(routes);
  }

  /// Get the best next hop for a destination.
  ///
  /// Returns the next hop peer ID from the best active route,
  /// or null if no route exists.
  String? nextHopFor(String destinationPeerId) =>
      bestRoute(destinationPeerId)?.nextHopPeerId;

  /// Validate a route before insertion.
  ///
  /// Throws [RouteValidationException] if the route is invalid.
  void _validateRoute(Route route) {
    final errors = RoutingValidators.validateRoute(
      destinationPeerId: route.destinationPeerId,
      nextHopPeerId: route.nextHopPeerId,
      metric: route.metric,
      localPeerId: localPeerId,
    );
    if (errors.isNotEmpty) {
      throw RouteValidationException(errors.first.name);
    }
  }

  /// Add a route to the table.
  ///
  /// If an equivalent route already exists, updates the existing entry.
  /// If a better route exists, the new route is added but not used
  /// for best-route selection until the better route expires.
  ///
  /// Throws [RouteValidationException] if the route is invalid.
  void addRoute(Route route) {
    _validateRoute(route);
    final destination = route.destinationPeerId;
    final existing = _routesByDestination[destination];

    if (existing == null) {
      // Enforce bounds: reject if at max destinations.
      if (_routesByDestination.length >= RoutingLimits.maxRouteDestinations) {
        return;
      }
      _routesByDestination[destination] = [route];
      return;
    }

    // Check for equivalent route (same next hop and metric).
    final equivalentIndex = existing.indexWhere(
      (r) =>
          r.nextHopPeerId == route.nextHopPeerId &&
          r.metric == route.metric,
    );

    if (equivalentIndex >= 0) {
      // Update existing route (keep the newer one).
      existing[equivalentIndex] = route;
    } else {
      // Enforce bounds: reject if at max routes per destination.
      if (existing.length >= RoutingLimits.maxRoutesPerDestination) {
        return;
      }
      // Add as alternative route.
      existing.add(route);
    }
  }

  /// Remove a specific route.
  ///
  /// Returns true if the route was found and removed.
  bool removeRoute(Route route) {
    final routes = _routesByDestination[route.destinationPeerId];
    if (routes == null) return false;

    final removed = routes.remove(route);
    if (routes.isEmpty) {
      _routesByDestination.remove(route.destinationPeerId);
    }
    return removed;
  }

  /// Remove all routes through a specific next hop.
  ///
  /// Used when a neighbor becomes unreachable.
  /// Returns the number of routes removed.
  int removeRoutesVia(String nextHopPeerId) {
    var count = 0;
    final destinations = _routesByDestination.keys.toList();

    for (final destination in destinations) {
      final routes = _routesByDestination[destination]!;
      routes.removeWhere((r) {
        if (r.nextHopPeerId == nextHopPeerId) {
          count++;
          return true;
        }
        return false;
      });

      if (routes.isEmpty) {
        _routesByDestination.remove(destination);
      }
    }

    return count;
  }

  /// Remove all routes to a specific destination.
  ///
  /// Used when a destination is confirmed unreachable.
  void removeRoutesTo(String destinationPeerId) {
    _routesByDestination.remove(destinationPeerId);
  }

  /// Mark stale routes based on age.
  ///
  /// Routes older than [maxAge] are marked as stale.
  /// Returns the number of routes marked stale.
  int markStaleRoutes({required DateTime cutoff}) {
    var count = 0;

    for (final routes in _routesByDestination.values) {
      for (var i = 0; i < routes.length; i++) {
        final route = routes[i];
        if (route.isActive && route.lastValidatedAt.isBefore(cutoff)) {
          routes[i] = route.copyWith(state: RouteState.stale);
          count++;
        }
      }
    }

    return count;
  }

  /// Remove all invalid and stale routes.
  ///
  /// Returns the number of routes removed.
  int cleanup() {
    var count = 0;

    final destinations = _routesByDestination.keys.toList();
    for (final destination in destinations) {
      final routes = _routesByDestination[destination]!;
      final before = routes.length;
      routes.removeWhere((r) => r.isInvalid || r.isStale);
      count += before - routes.length;

      if (routes.isEmpty) {
        _routesByDestination.remove(destination);
      }
    }

    return count;
  }

  /// Get all destinations reachable from a specific next hop.
  List<String> destinationsVia(String nextHopPeerId) =>
      _routesByDestination.entries
          .where((e) => e.value.any((r) => r.nextHopPeerId == nextHopPeerId))
          .map((e) => e.key)
          .toList();

  /// Check if a route exists to a destination.
  bool hasRouteTo(String destinationPeerId) =>
      routesTo(destinationPeerId).any((r) => r.isActive);

  /// Clear all routes.
  void clear() {
    _routesByDestination.clear();
  }

  @override
  String toString() =>
      'RoutingTable(destinations=$destinationCount, '
      'routes=$routeCount, '
      'active=${activeRoutes.length})';
}
