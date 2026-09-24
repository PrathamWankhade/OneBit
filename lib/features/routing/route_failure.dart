/// I8.9 — Route failure detection and recovery.
///
/// When a currently selected route becomes unusable, this service
/// detects the failure, invalidates the route, and attempts controlled
/// recovery using existing I8.6 discovery and I8.7 selection.
///
/// ## Recovery Lifecycle
///
/// ```text
/// Failure detected
///       ↓
/// Invalidate/remove failed route
///       ↓
/// Attempt recovery (I8.6 discovery → I8.7 selection)
///       ↓
/// Install replacement route (I8.5 table)
///       or
/// No valid replacement found
/// ```
///
/// ## What This Does NOT Do
///
/// - Does not create BLE connections
/// - Does not establish sessions
/// - Does not authenticate peers
/// - Does not propagate trust
/// - Does not forward messages
/// - Does not implement routing security (I8.10)
/// - Does not implement store-and-forward
/// - Does not implement multipath routing
library;

import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/route_selector.dart';
import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/routing_table.dart';

/// Why a route was invalidated.
enum FailureReason {
  /// The route's next hop is no longer reachable.
  nextHopUnreachable,

  /// The route has expired (TTL exceeded).
  expired,

  /// The route failed structural validation.
  invalid,

  /// A topology change rendered the route unusable.
  topologyChanged,
}

/// An event representing a route failure.
///
/// Emitted when a route is invalidated and needs recovery.
/// Contains enough information for the recovery service to know
/// which destination requires recovery.
class FailureEvent {
  const FailureEvent({
    required this.destination,
    required this.previousNextHop,
    required this.reason,
    required this.timestamp,
  });

  /// The destination that lost its route.
  final String destination;

  /// The next hop that was previously used.
  final String previousNextHop;

  /// Why the route failed.
  final FailureReason reason;

  /// When the failure was detected.
  final DateTime timestamp;

  @override
  String toString() =>
      'FailureEvent(dest=${destination.substring(0, 8)}..., '
      'next=${previousNextHop.substring(0, 8)}..., '
      'reason=${reason.name})';
}

/// The outcome of a recovery attempt.
enum RecoveryStatus {
  /// A replacement route was found and installed.
  recovered,

  /// No valid replacement route exists.
  noRoute,

  /// Recovery is already in progress for this destination.
  alreadyRecovering,

  /// Recovery was cancelled (e.g., disposal or superseded).
  cancelled,
}

/// Result of a recovery attempt.
class RecoveryResult {
  /// Recovery succeeded — a replacement route was installed.
  const RecoveryResult.recovered(this.destination, this.route)
      : status = RecoveryStatus.recovered;

  /// No valid replacement route exists.
  const RecoveryResult.noRoute(this.destination)
      : status = RecoveryStatus.noRoute,
        route = null;

  /// Recovery is already in progress for this destination.
  const RecoveryResult.alreadyRecovering(this.destination)
      : status = RecoveryStatus.alreadyRecovering,
        route = null;

  /// Recovery was cancelled.
  const RecoveryResult.cancelled(this.destination)
      : status = RecoveryStatus.cancelled,
        route = null;

  /// The destination that was being recovered.
  final String destination;

  /// The recovered route, if successful.
  final Route? route;

  /// The recovery status.
  final RecoveryStatus status;

  /// Whether recovery succeeded.
  bool get isRecovered => status == RecoveryStatus.recovered;

  /// Whether no route was found.
  bool get isNoRoute => status == RecoveryStatus.noRoute;

  /// Whether recovery was already running.
  bool get isAlreadyRecovering => status == RecoveryStatus.alreadyRecovering;

  /// Whether recovery was cancelled.
  bool get isCancelled => status == RecoveryStatus.cancelled;
}

/// Per-destination recovery tracking state.
class _RecoveryState {
  _RecoveryState({required this.generation});

  /// Current recovery generation for this destination.
  ///
  /// Incremented on each new recovery attempt. Used to detect
  /// stale recovery results.
  int generation;

  /// Whether recovery is currently in progress.
  bool inProgress = false;
}

/// Route failure and recovery service.
///
/// Accepts route failure events, deduplicates recovery attempts,
/// uses I8.6 discovery and I8.7 selection to find replacements,
/// and installs replacement routes into the I8.5 route table.
///
/// ## Does NOT Own
///
/// - Topology (I8.4)
/// - BLE connections (I7)
/// - Sessions (I7)
/// - Trust (I6)
/// - Identity generation (I5)
/// - Message delivery (I9)
class RouteRecoveryService {
  RouteRecoveryService({
    required this._localPeerId,
    required this.discoverRoute,
    required this._routingTable,
  });

  final String _localPeerId;
  final DiscoveryResult Function({
    required String localPeerId,
    required String destinationPeerId,
  }) discoverRoute;
  final RoutingTable _routingTable;

  /// Whether this service has been disposed.
  bool _isDisposed = false;

  /// Per-destination recovery state.
  final Map<String, _RecoveryState> _states = {};

  /// Whether recovery is in progress for a destination.
  bool isRecovering(String destinationPeerId) {
    if (_isDisposed) return false;
    final state = _states[destinationPeerId];
    return state != null && state.inProgress;
  }

  /// Handle a route failure event.
  ///
  /// Deduplicates concurrent failures for the same destination.
  /// Invalidates the failed route and attempts recovery using
  /// I8.6 discovery and I8.7 selection.
  ///
  /// Returns the recovery result.
  RecoveryResult handleFailure(FailureEvent event) {
    if (_isDisposed) return RecoveryResult.cancelled(event.destination);
    final destination = event.destination;

    // Validate destination.
    if (destination.isEmpty) {
      return const RecoveryResult.cancelled('');
    }

    // Deduplicate: if recovery is already running, skip.
    if (isRecovering(destination)) {
      return RecoveryResult.alreadyRecovering(destination);
    }

    // Enforce bounds: evict completed states if at capacity.
    if (_states.length >= RoutingLimits.maxRecoveryStates) {
      _cleanupCompletedStates();
    }

    // Get or create recovery state.
    final state = _states.putIfAbsent(
      destination,
      () => _RecoveryState(generation: 0),
    );

    // Increment generation for this recovery attempt.
    state.generation++;
    state.inProgress = true;

    // Remember the old route metric before invalidation (for downgrade protection).
    final oldMetric = _routingTable.bestRoute(destination)?.metric;

    // Invalidate the failed route.
    _invalidateRoute(destination, event.previousNextHop);

    // Attempt recovery.
    final result = _attemptRecovery(
      destination,
      state.generation,
      failedRouteMetric: oldMetric,
    );

    // Mark recovery as complete.
    state.inProgress = false;

    return result;
  }

  /// Cancel recovery for a destination.
  ///
  /// Used during disposal or when a destination is no longer relevant.
  void cancelRecovery(String destinationPeerId) {
    final state = _states[destinationPeerId];
    if (state != null) {
      state.inProgress = false;
    }
  }

  /// Get the current recovery generation for a destination.
  ///
  /// Returns 0 if no recovery has been attempted.
  int generationFor(String destinationPeerId) {
    return _states[destinationPeerId]?.generation ?? 0;
  }

  /// Invalidate a failed route in the routing table.
  ///
  /// Removes the route with the matching next hop from the table.
  void _invalidateRoute(String destination, String nextHop) {
    final routes = _routingTable.routesTo(destination);
    for (final route in routes) {
      if (route.nextHopPeerId == nextHop) {
        _routingTable.removeRoute(route);
        break;
      }
    }
  }

  /// Attempt to discover and install a replacement route.
  ///
  /// Uses I8.6 discovery and I8.7 selection. Validates that the
  /// discovered route's first hop is currently reachable.
  RecoveryResult _attemptRecovery(
    String destination,
    int currentGeneration, {
    int? failedRouteMetric,
  }) {
    // Discover candidate route.
    final discovery = discoverRoute(
      localPeerId: _localPeerId,
      destinationPeerId: destination,
    );

    if (!discovery.isFound || discovery.route == null) {
      return RecoveryResult.noRoute(destination);
    }

    final candidate = discovery.route!;

    // Verify the generation is still current (stale protection).
    final state = _states[destination];
    if (state == null || state.generation != currentGeneration) {
      return RecoveryResult.cancelled(destination);
    }

    // Downgrade protection: if the failed route was better than the
    // candidate, do not install the worse route.
    if (failedRouteMetric != null) {
      final comparison = failedRouteMetric.compareTo(candidate.metric);
      if (comparison < 0) {
        // Old route had a lower metric — candidate is worse, do not install.
        return RecoveryResult.noRoute(destination);
      }
    }

    // Also check against any route that another recovery may have installed.
    final existingBest = _routingTable.bestRoute(destination);
    if (existingBest != null) {
      final comparison = compareRoutesForSelection(existingBest, candidate);
      if (comparison <= 0) {
        // Existing route is better or equal — do not downgrade.
        return RecoveryResult.recovered(destination, existingBest);
      }
    }

    // Install the replacement route.
    _routingTable.addRoute(candidate);

    // Verify generation is still current after installation.
    if (state.generation != currentGeneration) {
      return RecoveryResult.cancelled(destination);
    }

    return RecoveryResult.recovered(destination, candidate);
  }

  /// Clear all recovery state.
  ///
  /// Used during disposal or reset.
  void clear() {
    for (final state in _states.values) {
      state.inProgress = false;
    }
    _states.clear();
  }

  /// Remove completed recovery states to free memory.
  void _cleanupCompletedStates() {
    final completed = _states.entries
        .where((e) => !e.value.inProgress)
        .map((e) => e.key)
        .toList();
    for (final dest in completed) {
      _states.remove(dest);
    }
  }

  /// Dispose resources.
  ///
  /// Safe to call multiple times. After disposal, all operations are no-ops.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    clear();
  }
}
