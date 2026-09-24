/// I8.8 — Route validation and expiration.
///
/// Routes have limited lifetimes based on their source. Direct routes
/// (to neighbors) live longer than advertised routes (learned from
/// topology advertisements). This module provides:
///
/// - **Expiration policy** — configurable TTLs per route source
/// - **Expiration service** — checks routes against live neighbor state
/// - **Helper function** — single-route expiration check
///
/// ## What This Does NOT Do
///
/// - Does not create BLE connections
/// - Does not establish sessions
/// - Does not authenticate peers
/// - Does not propagate trust
/// - Does not forward messages
/// - Does not implement route failure handling (I8.9)
/// - Does not implement routing security (I8.10)
library;

import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_table.dart';

/// Default TTL for direct routes (to directly connected neighbors).
///
/// Direct routes are valid as long as the neighbor is reachable.
/// The TTL acts as a safety net for stale neighbor detection.
const Duration defaultDirectRouteTtl = Duration(minutes: 10);

/// Default TTL for advertised routes (learned from topology advertisements).
///
/// Advertised routes are less trusted than direct routes and expire faster.
const Duration defaultAdvertisedRouteTtl = Duration(minutes: 5);

/// Default TTL for static routes (manually configured).
///
/// Static routes have the longest TTL since they are explicitly configured.
const Duration defaultStaticRouteTtl = Duration(hours: 1);

/// Default validation interval for route checks.
const Duration defaultValidationInterval = Duration(seconds: 30);

/// Configurable TTL per route source.
///
/// Controls how long routes from each source type remain valid.
/// Different sources have different risk profiles:
/// - Direct routes: high trust (direct observation), longer TTL
/// - Advertised routes: lower trust (learned from neighbors), shorter TTL
/// - Static routes: highest trust (manual config), longest TTL
class RouteExpirationPolicy {
  const RouteExpirationPolicy({
    this.directRouteTtl = defaultDirectRouteTtl,
    this.advertisedRouteTtl = defaultAdvertisedRouteTtl,
    this.staticRouteTtl = defaultStaticRouteTtl,
  });

  /// TTL for direct routes.
  final Duration directRouteTtl;

  /// TTL for advertised routes.
  final Duration advertisedRouteTtl;

  /// TTL for static routes.
  final Duration staticRouteTtl;

  /// Get the TTL for a specific route source.
  Duration ttlForSource(RouteSource source) {
    switch (source) {
      case RouteSource.direct:
        return directRouteTtl;
      case RouteSource.advertised:
        return advertisedRouteTtl;
      case RouteSource.static:
        return staticRouteTtl;
    }
  }

  /// Default policy with standard TTLs.
  static const defaultPolicy = RouteExpirationPolicy();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteExpirationPolicy &&
          runtimeType == other.runtimeType &&
          directRouteTtl == other.directRouteTtl &&
          advertisedRouteTtl == other.advertisedRouteTtl &&
          staticRouteTtl == other.staticRouteTtl;

  @override
  int get hashCode => Object.hash(directRouteTtl, advertisedRouteTtl, staticRouteTtl);

  @override
  String toString() =>
      'RouteExpirationPolicy('
      'direct: ${directRouteTtl.inMinutes}min, '
      'advertised: ${advertisedRouteTtl.inMinutes}min, '
      'static: ${staticRouteTtl.inMinutes}min)';
}

/// Check whether a route has expired based on its [expiresAt] field.
///
/// Returns `true` if the route has a non-null `expiresAt` and the
/// expiration time is in the past. Returns `false` if the route has
/// no expiration set.
///
/// This is a pure, side-effect-free function.
bool isRouteExpired(Route route, {DateTime? now}) {
  if (route.expiresAt == null) return false;
  return (now ?? DateTime.now()).isAfter(route.expiresAt!);
}

/// Compute the absolute expiration time for a route based on policy.
///
/// Returns `createdAt + ttl` where ttl is determined by the route's source.
///
/// This is a pure, side-effect-free function.
DateTime computeRouteExpiration(
  Route route,
  RouteExpirationPolicy policy,
) {
  final ttl = policy.ttlForSource(route.source);
  return route.createdAt.add(ttl);
}

/// Result of a route validation check.
///
/// Indicates whether a route is valid, expired, or has an unreachable
/// next hop.
class RouteValidationResult {
  /// Route is still valid.
  const RouteValidationResult.valid(this.route)
      : status = RouteValidationStatus.valid;

  /// Route has expired (TTL exceeded).
  const RouteValidationResult.expired(this.route)
      : status = RouteValidationStatus.expired;

  /// Route's next hop is no longer a reachable neighbor.
  const RouteValidationResult.unreachableNextHop(this.route)
      : status = RouteValidationStatus.unreachableNextHop;

  /// The route being validated.
  final Route route;

  /// The validation status.
  final RouteValidationStatus status;

  /// Whether the route is valid.
  bool get isValid => status == RouteValidationStatus.valid;

  /// Whether the route has expired.
  bool get isExpired => status == RouteValidationStatus.expired;

  /// Whether the next hop is unreachable.
  bool get isUnreachable => status == RouteValidationStatus.unreachableNextHop;
}

/// The possible outcomes of a route validation check.
enum RouteValidationStatus {
  /// Route is valid.
  valid,

  /// Route has expired.
  expired,

  /// Route's next hop is no longer reachable.
  unreachableNextHop,
}

/// Route validation and expiration service.
///
/// Validates routes against:
/// - Expiration policy (TTL)
/// - Current reachable neighbor set (next-hop reachability)
///
/// Does NOT own BLE connections, sessions, trust, or the routing table.
/// Returns validation results — the caller decides how to act.
class RouteExpirationService {
  RouteExpirationService({
    RouteExpirationPolicy? policy,
  }) : policy = policy ?? RouteExpirationPolicy.defaultPolicy;

  /// The expiration policy controlling TTLs.
  final RouteExpirationPolicy policy;

  /// Validate a single route against current state.
  ///
  /// Checks:
  /// 1. Whether the route has expired (TTL)
  /// 2. Whether the next hop is in the reachable neighbor set
  RouteValidationResult validateRoute(
    Route route, {
    required Set<String> reachableNeighbors,
    DateTime? now,
  }) {
    // Check TTL expiration.
    if (isRouteExpired(route, now: now)) {
      return RouteValidationResult.expired(route);
    }

    // Check next-hop reachability (direct routes are their own next hop).
    if (!route.isDirect) {
      if (!reachableNeighbors.contains(route.nextHopPeerId)) {
        return RouteValidationResult.unreachableNextHop(route);
      }
    }

    return RouteValidationResult.valid(route);
  }

  /// Validate all routes in a routing table.
  ///
  /// Returns a list of validation results for all routes.
  List<RouteValidationResult> validateAllRoutes(
    RoutingTable table, {
    required Set<String> reachableNeighbors,
    DateTime? now,
  }) {
    return table.allRoutes
        .map((route) => validateRoute(
              route,
              reachableNeighbors: reachableNeighbors,
              now: now,
            ))
        .toList();
  }

  /// Find all expired routes in a routing table.
  List<Route> findExpiredRoutes(RoutingTable table, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    return table.allRoutes
        .where((route) => isRouteExpired(route, now: currentTime))
        .toList();
  }

  /// Find all routes with unreachable next hops.
  List<Route> findUnreachableRoutes(
    RoutingTable table, {
    required Set<String> reachableNeighbors,
  }) {
    return table.allRoutes
        .where((route) =>
            !route.isDirect &&
            !reachableNeighbors.contains(route.nextHopPeerId))
        .toList();
  }

  /// Compute the number of routes that would expire within [duration] from now.
  ///
  /// Useful for monitoring and diagnostics.
  int countExpiringSoon(
    RoutingTable table, {
    required Duration duration,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final threshold = currentTime.add(duration);
    return table.allRoutes
        .where((route) =>
            route.expiresAt != null &&
            route.expiresAt!.isAfter(currentTime) &&
            route.expiresAt!.isBefore(threshold))
        .length;
  }
}
