import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/peer_connection_providers.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';
import 'package:onebit/features/routing/mesh_router.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/route_failure.dart';
import 'package:onebit/features/routing/routing_security.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology_exchange_service.dart';
import 'package:onebit/features/routing/topology_repository.dart';
import 'package:onebit/features/trust/trust_providers.dart';

/// Provides the runtime neighbor table for the routing layer.
///
/// Derives neighbor state from I7's PeerConnectionManager.
final neighborTableProvider = Provider<NeighborTable>((ref) {
  final manager = ref.watch(peerConnectionManagerProvider);
  final table = NeighborTable(connectionManager: manager);
  table.initialize();
  ref.onDispose(table.dispose);
  return table;
});

/// Provides the topology repository for storing local and remote topology.
final topologyRepositoryProvider = Provider<TopologyRepository>((ref) {
  final repo = TopologyRepository();
  ref.onDispose(repo.clear);
  return repo;
});

/// Provides direct peer reachability evaluation.
final peerReachabilityProvider = Provider<PeerReachability>((ref) {
  final registry = ref.watch(peerRegistryProvider);
  final manager = ref.watch(peerConnectionManagerProvider);
  final table = ref.watch(neighborTableProvider);
  return PeerReachability(
    registry: registry,
    connectionManager: manager,
    neighborTable: table,
  );
});

/// Provides the topology exchange service.
final topologyExchangeServiceProvider = Provider<TopologyExchangeService>((ref) {
  final table = ref.watch(neighborTableProvider);
  final reachability = ref.watch(peerReachabilityProvider);
  final repository = ref.watch(topologyRepositoryProvider);
  return TopologyExchangeService(
    neighborTable: table,
    reachability: reachability,
    repository: repository,
  );
});

/// Provides the routing table.
///
/// Uses the local peer ID for self-route validation.
final routingTableProvider = Provider<RoutingTable>((ref) {
  final identityAsync = ref.watch(localIdentityProvider);
  final localPeerId = identityAsync.valueOrNull?.identityId;
  final table = RoutingTable(localPeerId: localPeerId);
  ref.onDispose(table.clear);
  return table;
});

/// Provides the routing security validator.
final routingSecurityValidatorProvider = Provider<RoutingSecurityValidator>((ref) {
  final trustService = ref.watch(trustServiceProvider);
  return RoutingSecurityValidator(trustService: trustService);
});

/// Provides route discovery.
final routeDiscoveryProvider = Provider<RouteDiscovery>((ref) {
  final topology = ref.watch(topologyRepositoryProvider);
  final reachability = ref.watch(peerReachabilityProvider);
  return RouteDiscovery(
    topologyRepository: topology,
    getReachableNeighbors: () => reachability.getReachableNeighbors().toSet(),
  );
});

/// Provides the route recovery service.
final routeRecoveryServiceProvider = Provider<RouteRecoveryService>((ref) {
  final identityAsync = ref.watch(localIdentityProvider);
  final localPeerId = identityAsync.valueOrNull?.identityId ?? '';
  final discovery = ref.watch(routeDiscoveryProvider);
  final table = ref.watch(routingTableProvider);
  final service = RouteRecoveryService(
    localPeerId: localPeerId,
    discoverRoute: discovery.discoverRoute,
    routingTable: table,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the routing table in sync with the live topology.
///
/// Riverpod providers are lazy, so this must be watched from the app
/// root — otherwise nothing ever installs a route and every non-local
/// send resolves to `NoRoute`. The router stays inert until the local
/// identity loads, at which point the identity dependency changes and
/// the provider is recreated with a usable peer ID.
final meshRouterProvider = Provider<MeshRouter>((ref) {
  final localPeerId =
      ref.watch(localIdentityProvider).valueOrNull?.identityId ?? '';
  final reachability = ref.watch(peerReachabilityProvider);
  final discovery = ref.watch(routeDiscoveryProvider);

  final router = MeshRouter(
    localPeerId: localPeerId,
    neighborTable: ref.watch(neighborTableProvider),
    topologyExchange: ref.watch(topologyExchangeServiceProvider),
    topologyRepository: ref.watch(topologyRepositoryProvider),
    routingTable: ref.watch(routingTableProvider),
    bleService: ref.watch(bleServiceProvider),
    getReachableNeighbors: reachability.getReachableNeighbors,
    discoverRoute: discovery.discoverRoute,
  );
  router.start();
  ref.onDispose(router.dispose);
  return router;
});
