/// I8.7 — Route selection policy.
///
/// Chooses the best usable route from candidate routes to the same
/// destination. The selection is deterministic: lowest hop-count metric
/// wins, with `PeerId` string comparison as tie-breaker.
///
/// ## Selection Rules
///
/// 1. Reject invalid candidates (empty PeerIds, invalid metric).
/// 2. Among valid candidates, lowest metric wins.
/// 3. If metrics are equal, lexicographic `PeerId` comparison on
///    `nextHopPeerId` determines the winner.
///
/// ## What This Does NOT Do
///
/// - Does not create BLE connections
/// - Does not establish sessions
/// - Does not authenticate peers
/// - Does not propagate trust
/// - Does not forward messages
/// - Does not expire routes (I8.8)
/// - Does not handle route failure (I8.9)
/// - Does not implement routing security (I8.10)
library;

import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/routing_validators.dart';

/// Compare two routes for selection ordering.
///
/// Returns a negative value if [a] is preferred over [b], zero if they
/// are equivalent, and a positive value if [b] is preferred.
///
/// Comparison order:
/// 1. Lower metric wins.
/// 2. If metric is equal, lexicographic `nextHopPeerId` wins.
int compareRoutesForSelection(Route a, Route b) {
  final metricCompare = a.metric.compareTo(b.metric);
  if (metricCompare != 0) return metricCompare;
  return a.nextHopPeerId.compareTo(b.nextHopPeerId);
}

/// Select the best route from a list of candidate routes.
///
/// Filters invalid candidates, then applies the selection policy:
/// lowest metric, with `PeerId` tie-breaking on `nextHopPeerId`.
///
/// Returns `null` if no valid candidate exists.
///
/// This is a pure, side-effect-free function. It does not modify
/// the route table, create connections, or perform any I/O.
Route? selectBestRoute(List<Route> candidates) {
  if (candidates.isEmpty) return null;

  final valid = candidates.where(_isValidCandidate).toList();
  if (valid.isEmpty) return null;

  valid.sort(compareRoutesForSelection);
  return valid.first;
}

/// Check whether a candidate route satisfies structural validation.
///
/// A valid candidate must have:
/// - Active state
/// - Non-empty destination PeerId
/// - Non-empty next-hop PeerId
/// - Positive metric within bounds
bool _isValidCandidate(Route route) {
  if (!route.isActive) return false;
  if (!RoutingValidators.isValidPeerId(route.destinationPeerId)) return false;
  if (!RoutingValidators.isValidPeerId(route.nextHopPeerId)) return false;
  if (!RoutingValidators.isValidMetric(route.metric)) return false;
  return true;
}
