import 'package:onebit/features/mesh/domain/mesh_route.dart';

/// The route cache: per destination, a sorted list whose first element is
/// the primary route and the rest are alternatives.
///
/// Lookups are `O(1)` (hash by destination). Memory is bounded by
/// `destinations × (1 + maxAlternatives)`. Routes are immutable values; the
/// table replaces them, which keeps every change observable.
final class RouteTable {
  RouteTable({required this.time, this._maxAlternatives = 3});

  final DateTime Function() time;
  final int _maxAlternatives;
  final Map<String, List<MeshRoute>> _byDestination = {};

  /// All known destination node ids.
  Set<String> get destinations => _byDestination.keys.toSet();

  /// Total cached routes.
  int get size =>
      _byDestination.values.fold(0, (sum, routes) => sum + routes.length);

  /// The best route for [destination], or `null`.
  MeshRoute? primary(String destination) {
    final routes = _byDestination[destination];
    return routes == null || routes.isEmpty ? null : routes.first;
  }

  /// All cached routes for [destination], primary first. Unmodifiable.
  List<MeshRoute> forDestination(String destination) =>
      List.unmodifiable(_byDestination[destination] ?? const []);

  /// Alternative (non-primary) routes for [destination].
  List<MeshRoute> alternatives(String destination) {
    final routes = _byDestination[destination];
    if (routes == null || routes.length <= 1) return const [];
    return List.unmodifiable(routes.sublist(1));
  }

  /// The explicit `(destination, nextHop)` route summary, or `null`.
  MeshRoute? routeThrough(String destination, String nextHop) {
    final routes = _byDestination[destination];
    if (routes == null) return null;
    for (final route in routes) {
      if (route.nextHop == nextHop) return route;
    }
    return null;
  }

  /// Installs or refreshes [candidate] and returns `true` whenever it
  /// changed the table (new route, better replacement, or a resort that
  /// flipped the primary).
  bool install(MeshRoute candidate) {
    final existing = _byDestination[candidate.destination];
    if (existing == null) {
      _byDestination[candidate.destination] = [candidate];
      return true;
    }

    var changed = false;
    List<MeshRoute> merged;
    final sameHop = existing
        .where((route) => route.sameNextHop(candidate))
        .toList();
    final index = sameHop.isEmpty ? -1 : existing.indexOf(sameHop.first);
    if (index == -1) {
      merged = [...existing, candidate];
      changed = true;
    } else if (_betterThan(candidate, existing[index])) {
      merged = List.of(existing);
      merged[index] = candidate;
      changed = true;
    } else {
      merged = existing;
    }

    final capped = 1 + _maxAlternatives;
    if (merged.length > capped) {
      merged = List.of(merged.sublist(0, capped));
      changed = true;
    }

    _sort(merged);
    _byDestination[candidate.destination] = merged;
    return changed;
  }

  /// Removes every route that routes through [nextHop] and returns the
  /// destination ids whose primary changed or disappeared — the list the
  /// engine uses to trigger route repair.
  List<String> dissolveThrough(String nextHop) {
    final affected = <String>[];
    final surviving = <String, List<MeshRoute>>{};

    for (final entry in _byDestination.entries) {
      final before = entry.value.first;
      final kept = entry.value
          .where((route) => route.nextHop != nextHop)
          .toList();
      if (kept.isEmpty) {
        affected.add(entry.key);
        continue;
      }
      _sort(kept);
      if (before.nextHop != kept.first.nextHop) {
        affected.add(entry.key);
      }
      surviving[entry.key] = kept;
    }

    _byDestination
      ..clear()
      ..addAll(surviving);
    return affected.toList();
  }

  /// Marks the primary for [destination] failed: it moves to the back of
  /// the queue, so the next best alternative becomes primary. Returns
  /// `false` when [destination] had no alternative.
  bool demotePrimary(String destination) {
    final routes = _byDestination[destination];
    if (routes == null || routes.isEmpty) return false;
    if (routes.length == 1) return true;
    final promoted = routes.sublist(1);
    _byDestination[destination] = [...promoted, routes.first];
    return true;
  }

  /// Touches the primary's `lastUsed` timestamp.
  void touch(String destination) {
    final routes = _byDestination[destination];
    if (routes == null || routes.isEmpty) return;
    routes[0] = routes[0].copyWith(lastUsed: time());
  }

  /// Drops routes whose `lastUsed` is older than [ttl]. Returns the
  /// destination ids that lost their primary.
  List<String> expire(DateTime now, Duration ttl) {
    final lostPrimary = <String>{};
    final surviving = <String, List<MeshRoute>>{};
    for (final entry in _byDestination.entries) {
      final kept = entry.value
          .where((route) => now.difference(route.lastUsed) <= ttl)
          .toList();
      if (kept.isEmpty) {
        lostPrimary.add(entry.key);
        continue;
      }
      if (kept.length != entry.value.length &&
          entry.value.first != kept.first) {
        lostPrimary.add(entry.key);
      }
      _sort(kept);
      surviving[entry.key] = kept;
    }
    _byDestination
      ..clear()
      ..addAll(surviving);
    return lostPrimary.toList();
  }

  /// Drops every route.
  void clear() => _byDestination.clear();

  void _sort(List<MeshRoute> routes) => routes.sort(_compareRoutes);

  int _compareRoutes(MeshRoute a, MeshRoute b) {
    if (a.cost != b.cost) return a.cost < b.cost ? -1 : 1;
    if (a.quality != b.quality) return a.quality > b.quality ? -1 : 1;
    return a.nextHop.compareTo(b.nextHop);
  }

  /// `a` strictly better than `b` for the same (destination, next-hop).
  bool _betterThan(MeshRoute a, MeshRoute b) {
    if (a.cost < b.cost) return true;
    if (a.cost > b.cost) return false;
    return a.quality > b.quality;
  }
}
