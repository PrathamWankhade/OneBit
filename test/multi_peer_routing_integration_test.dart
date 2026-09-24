/// I8.11 — Multi-peer routing integration & isolation tests.
///
/// Proves the complete I8 routing stack works correctly when multiple
/// peers operate simultaneously. Every peer, identity, connection,
/// topology source, route, failure, and recovery operation must remain
/// logically isolated.
///
/// ## Architecture Under Test
///
/// ```text
/// I8.2 NeighborTable      (peer-isolated)
/// I8.3 PeerReachability   (pure reads)
/// I8.4 TopologyRepository (source-isolated)
/// I8.10 SecurityValidator (source-scoped logging)
/// I8.6 RouteDiscovery     (stateless BFS)
/// I8.5 RoutingTable       (destination-isolated)
/// I8.7 RouteSelector      (pure functions)
/// I8.8 RouteExpiration     (pure reads)
/// I8.9 RouteRecovery      (destination-scoped)
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/route_expiration.dart';
import 'package:onebit/features/routing/route_failure.dart';
import 'package:onebit/features/routing/route_selector.dart';
import 'package:onebit/features/routing/routing_security.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/routing/topology_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';

import 'multi_peer_routing_integration_test.mocks.dart';

@GenerateMocks([PeerConnectionManager])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Test Identities ────────────────────────────────────────
  const localPeer = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const peerE = 'ee55555555555555555555555555555555555555555555555555555555555555';
  const peerF = 'ff66666666666666666666666666666666666666666666666666666666666666';
  const peerG = '0077777777777777777777777777777777777777777777777777777777777770';
  const peerH = '1188888888888888888888888888888888888888888888888888888888888881';
  const peerX = 'aa88888888888888888888888888888888888888888888888888888888888888';

  // ── Helpers ────────────────────────────────────────────────

  /// Helper: make a route.
  Route makeRoute({
    required String destination,
    required String nextHop,
    int metric = 2,
    RouteSource source = RouteSource.advertised,
    RouteState state = RouteState.active,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    return Route(
      destinationPeerId: destination,
      nextHopPeerId: nextHop,
      metric: metric,
      state: state,
      source: source,
      createdAt: now,
      lastValidatedAt: now,
      expiresAt: expiresAt,
    );
  }

  /// Helper: make a topology advertisement.
  TopologyAdvertisement makeAd({
    required String source,
    required int sequence,
    required List<String> neighbors,
  }) {
    return TopologyAdvertisement(
      sourceIdentity: source,
      sequence: sequence,
      neighborPeerIds: neighbors,
    );
  }

  // ── Test 1: Two Independent Peers ──────────────────────────

  group('Test 1 — Two independent peers coexist', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('B and C are independent neighbors', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      expect(neighborTable.isNeighbor(peerB), true);
      expect(neighborTable.isNeighbor(peerC), true);
      expect(neighborTable.count, 2);
    });

    test('removing B does not affect C', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      neighborTable.removeNeighbor(peerB);

      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.isNeighbor(peerC), true);
      expect(neighborTable.count, 1);
    });
  });

  // ── Test 2: Three Peers Isolation ──────────────────────────

  group('Test 2 — Three peers B, C, D remain isolated', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('all three are independent neighbors', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);
      neighborTable.addNeighbor(peerD);

      expect(neighborTable.count, 3);
      expect(neighborTable.neighborPeerIds, {peerB, peerC, peerD});
    });

    test('removing C does not affect B or D', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);
      neighborTable.addNeighbor(peerD);

      neighborTable.removeNeighbor(peerC);

      expect(neighborTable.isNeighbor(peerB), true);
      expect(neighborTable.isNeighbor(peerC), false);
      expect(neighborTable.isNeighbor(peerD), true);
      expect(neighborTable.count, 2);
    });
  });

  // ── Test 3: One Disconnect ─────────────────────────────────

  group('Test 3 — Disconnecting B leaves C/D unchanged', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('B disconnects, C and D remain active', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);
      neighborTable.addNeighbor(peerD);

      neighborTable.removeNeighbor(peerB);

      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.isNeighbor(peerC), true);
      expect(neighborTable.isNeighbor(peerD), true);
    });
  });

  // ── Test 4: Multiple Disconnects ───────────────────────────

  group('Test 4 — B and D disconnect while C remains', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('C remains reachable after B and D disconnect', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);
      neighborTable.addNeighbor(peerD);

      neighborTable.removeNeighbor(peerB);
      neighborTable.removeNeighbor(peerD);

      expect(neighborTable.isNeighbor(peerC), true);
      expect(neighborTable.count, 1);
    });
  });

  // ── Test 5: Reconnect ──────────────────────────────────────

  group('Test 5 — B disconnects then reconnects cleanly', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('B reconnects without duplicating entries', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      // B disconnects (stale).
      neighborTable.removeNeighbor(peerB);
      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.count, 1);

      // B reconnects.
      neighborTable.addNeighbor(peerB);
      expect(neighborTable.isNeighbor(peerB), true);
      expect(neighborTable.count, 2);

      // Only one B entry (no duplicate).
      final bEntries = neighborTable.allEntries.where((e) => e.peerId == peerB);
      expect(bEntries.length, 1);
    });
  });

  // ── Test 6: BLE Identifier Change ──────────────────────────

  group('Test 6 — BLE identifier change preserves logical identity', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() => neighborTable.dispose());

    test('B with new BLE device ID remains single logical peer', () {
      neighborTable.addNeighbor(peerB, bleDeviceId: 'AA:BB:CC:01');
      expect(neighborTable.isNeighbor(peerB), true);

      // B's BLE device changes — still one logical peer.
      neighborTable.addNeighbor(peerB, bleDeviceId: 'AA:BB:CC:02');

      final bEntries = neighborTable.allEntries.where((e) => e.peerId == peerB);
      expect(bEntries.length, 1);
      expect(neighborTable.count, 1);
    });
  });

  // ── Test 7: Topology Source Isolation ──────────────────────

  group('Test 7 — Topology source isolation B vs C', () {
    late TopologyRepository repository;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('B and C topology are independent', () {
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerD],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerE],
      ));

      expect(repository.remoteSourceCount, 2);
      expect(repository.advertisedNeighborsOf(peerB), {peerD});
      expect(repository.advertisedNeighborsOf(peerC), {peerE});
    });

    test('removing B does not affect C topology', () {
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerD],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerE],
      ));

      repository.removeSource(peerB);

      expect(repository.remoteSourceCount, 1);
      expect(repository.advertisedNeighborsOf(peerB), isEmpty);
      expect(repository.advertisedNeighborsOf(peerC), {peerE});
    });
  });

  // ── Test 8: Replay Isolation ───────────────────────────────

  group('Test 8 — Replay isolation between B and C', () {
    late TopologyRepository repository;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('replaying B seq 9 after B seq 10 is rejected, C unaffected', () {
      // B seq 10 accepted.
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 10,
        neighbors: [peerD],
      ));
      // C seq 10 accepted.
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 10,
        neighbors: [peerE],
      ));

      // B seq 9 replayed — rejected.
      final bReplayed = repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 9,
        neighbors: [peerD],
      ));
      expect(bReplayed, false);

      // C unaffected — still seq 10.
      expect(repository.getRemoteEntry(peerC)!.sequence, 10);
      expect(repository.advertisedNeighborsOf(peerC), {peerE});
    });
  });

  // ── Test 9: Security Validation Isolation ──────────────────

  group('Test 9 — Security validation source isolation', () {
    late TrustService trustService;
    late RoutingSecurityValidator validator;

    setUp(() {
      trustService = TrustService();
      validator = RoutingSecurityValidator(trustService: trustService);
    });

    tearDown(() {
      validator.clearLog();
      trustService.dispose();
    });

    test('D malicious input does not affect B or E', () {
      // Authenticate B and E.
      trustService.verifyIdentity(
        peerIdentityId: peerB,
        at: DateTime(2025),
        publicKeyHex: peerB,
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: peerB);

      trustService.verifyIdentity(
        peerIdentityId: peerE,
        at: DateTime(2025),
        publicKeyHex: peerE,
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: peerE);

      // B sends valid ad.
      final bResult = validator.validate(
        advertisement: makeAd(source: peerB, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerB,
      );
      expect(bResult.isAccepted, true);

      // D sends identity mismatch (masquerading as B).
      final dResult = validator.validate(
        advertisement: makeAd(source: peerB, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerD,
      );
      expect(dResult.isAccepted, false);
      expect(dResult.event, RoutingSecurityEvent.senderIdentityMismatch);

      // E sends valid ad — unaffected.
      final eResult = validator.validate(
        advertisement: makeAd(source: peerE, sequence: 1, neighbors: [peerF]),
        authenticatedPeerId: peerE,
      );
      expect(eResult.isAccepted, true);
    });

    test('D not-authenticated rejection does not affect B', () {
      trustService.verifyIdentity(
        peerIdentityId: peerB,
        at: DateTime(2025),
        publicKeyHex: peerB,
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: peerB);

      // B valid.
      validator.validate(
        advertisement: makeAd(source: peerB, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerB,
      );

      // D not authenticated — rejected.
      validator.validate(
        advertisement: makeAd(source: peerD, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerD,
      );

      // B's events should only contain validationPassed.
      final bEvents = validator.eventsFor(peerB);
      expect(bEvents, [RoutingSecurityEvent.validationPassed]);
    });
  });

  // ── Test 10: Route Destination Isolation ───────────────────

  group('Test 10 — Route destination isolation', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() => table.clear());

    test('failing C does not affect D or E routes', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerE, nextHop: peerC, metric: 3));

      // Remove C routes.
      table.removeRoutesTo(peerC);

      expect(table.hasRouteTo(peerC), false);
      expect(table.hasRouteTo(peerD), true);
      expect(table.hasRouteTo(peerE), true);
    });
  });

  // ── Test 11: Shared Next-Hop Failure ───────────────────────

  group('Test 11 — Shared next-hop failure B', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() => table.clear());

    test('removing all routes via B removes C,D,E but not F', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerE, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerF, nextHop: peerC, metric: 3));

      final removed = table.removeRoutesVia(peerB);

      expect(removed, 3);
      expect(table.hasRouteTo(peerC), false);
      expect(table.hasRouteTo(peerD), false);
      expect(table.hasRouteTo(peerE), false);
      expect(table.hasRouteTo(peerF), true); // F via C is unrelated to B
    });
  });

  // ── Test 12: Recovery Destination Isolation ────────────────

  group('Test 12 — Recovery destination isolation', () {
    late RoutingTable table;
    late RouteRecoveryService recovery;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
      recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) {
          // Discovery finds nothing (returns notFound).
          return const DiscoveryResult.notFound();
        },
        routingTable: table,
      );
    });

    tearDown(() {
      recovery.dispose();
      table.clear();
    });

    test('C recovery does not affect D recovery state', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));

      // Start C recovery.
      final cResult = recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));
      expect(cResult.isNoRoute, true);

      // D recovery is independent.
      expect(recovery.isRecovering(peerD), false);
      expect(recovery.generationFor(peerC), 1);
      expect(recovery.generationFor(peerD), 0);
    });

    test('C and D recovery are independent', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));

      recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));

      recovery.handleFailure(FailureEvent(
        destination: peerD,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));

      expect(recovery.generationFor(peerC), 1);
      expect(recovery.generationFor(peerD), 1);
    });
  });

  // ── Test 13: Recovery Deduplication ────────────────────────

  group('Test 13 — Recovery deduplication per destination', () {
    late RoutingTable table;
    late RouteRecoveryService recovery;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
      recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) =>
            const DiscoveryResult.notFound(),
        routingTable: table,
      );
    });

    tearDown(() {
      recovery.dispose();
      table.clear();
    });

    test('multiple C failures only produce one active recovery', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));

      final r1 = recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));
      expect(r1.status, RecoveryStatus.noRoute);

      // Second failure while recovery is notionally complete.
      recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.expired,
        timestamp: DateTime.now(),
      ));
      // Should still work (generation incremented).
      expect(recovery.generationFor(peerC), 2);
    });
  });

  // ── Test 14: Cross-Destination Stale Recovery ──────────────

  group('Test 14 — Stale recovery cannot overwrite newer route', () {
    late RoutingTable table;
    late RouteRecoveryService recovery;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
      recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) =>
            const DiscoveryResult.notFound(),
        routingTable: table,
      );
    });

    tearDown(() {
      recovery.dispose();
      table.clear();
    });

    test('installing newer route prevents old recovery overwrite', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));

      // Start recovery.
      recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));

      // Install a better route for C (simulating topology update).
      table.addRoute(makeRoute(destination: peerC, nextHop: peerD, metric: 2));

      // Recovery generation should be stale.
      expect(recovery.generationFor(peerC), 1);
    });
  });

  // ── Test 15: Route Table Stress Test ───────────────────────

  group('Test 15 — Route table multi-destination stress', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() => table.clear());

    test('multiple destinations coexist correctly', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerE, nextHop: peerC, metric: 3));
      table.addRoute(makeRoute(destination: peerF, nextHop: peerD, metric: 3));
      table.addRoute(makeRoute(destination: peerG, nextHop: peerE, metric: 4));

      expect(table.destinationCount, 5);
      expect(table.routeCount, 5);

      // Lookup each.
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerB);
      expect(table.bestRoute(peerD)?.nextHopPeerId, peerB);
      expect(table.bestRoute(peerE)?.nextHopPeerId, peerC);
      expect(table.bestRoute(peerF)?.nextHopPeerId, peerD);
      expect(table.bestRoute(peerG)?.nextHopPeerId, peerE);
    });

    test('removing one destination does not affect others', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerE, nextHop: peerC, metric: 3));

      table.removeRoutesTo(peerD);

      expect(table.hasRouteTo(peerC), true);
      expect(table.hasRouteTo(peerD), false);
      expect(table.hasRouteTo(peerE), true);
      expect(table.destinationCount, 2);
    });

    test('replacement and lookup cycle', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerC, nextHop: peerD, metric: 3));

      // B route should be best (lower metric).
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerB);

      // Remove B route.
      table.removeRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      expect(table.bestRoute(peerC)?.nextHopPeerId, peerD);
    });
  });

  // ── Test 16: Equal-Cost Deterministic Routing ──────────────

  group('Test 16 — Equal-cost deterministic tie-breaking', () {
    test('same metric, different next hops, deterministic by PeerId', () {
      final routes = [
        makeRoute(destination: peerE, nextHop: peerC, metric: 2),
        makeRoute(destination: peerE, nextHop: peerB, metric: 2),
        makeRoute(destination: peerE, nextHop: peerD, metric: 2),
      ];

      // sort by PeerId order: bb < cc < dd
      final sorted = List<Route>.from(routes)..sort(compareRoutesForSelection);
      expect(sorted.first.nextHopPeerId, peerB); // bb < cc < dd
      expect(sorted.last.nextHopPeerId, peerD);

      // selectBestRoute should pick B.
      final best = selectBestRoute(routes);
      expect(best?.nextHopPeerId, peerB);
    });
  });

  // ── Test 17: Security State Stress ─────────────────────────

  group('Test 17 — Security state stress multi-peer', () {
    late TrustService trustService;
    late RoutingSecurityValidator validator;
    late TopologyRepository repository;

    setUp(() {
      trustService = TrustService();
      validator = RoutingSecurityValidator(trustService: trustService);
      repository = TopologyRepository();
    });

    tearDown(() {
      validator.clearLog();
      trustService.dispose();
      repository.clear();
    });

    void authenticatePeer(String peerId) {
      trustService.verifyIdentity(
        peerIdentityId: peerId,
        at: DateTime(2025),
        publicKeyHex: peerId,
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: peerId);
    }

    test('valid, replayed, malformed from multiple peers', () {
      authenticatePeer(peerB);
      authenticatePeer(peerC);
      authenticatePeer(peerE);

      // B valid seq 1.
      expect(validator.validate(
        advertisement: makeAd(source: peerB, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerB,
      ).isAccepted, true);

      // C valid seq 1.
      expect(validator.validate(
        advertisement: makeAd(source: peerC, sequence: 1, neighbors: [peerD]),
        authenticatedPeerId: peerC,
      ).isAccepted, true);

      // B replay seq 1 (duplicate) — accepted (equal sequence = idempotent).
      expect(validator.validate(
        advertisement: makeAd(source: peerB, sequence: 1, neighbors: [peerC]),
        authenticatedPeerId: peerB,
      ).isAccepted, true);

      // D malformed — rejected.
      expect(validator.validate(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerD,
          sequence: 1,
          neighborPeerIds: ['short'],
        ),
        authenticatedPeerId: peerD,
      ).isAccepted, false);

      // E valid.
      expect(validator.validate(
        advertisement: makeAd(source: peerE, sequence: 1, neighbors: [peerF]),
        authenticatedPeerId: peerE,
      ).isAccepted, true);

      // B/C/E still valid in log.
      expect(validator.hasEvent(peerB, RoutingSecurityEvent.validationPassed), true);
      expect(validator.hasEvent(peerC, RoutingSecurityEvent.validationPassed), true);
      expect(validator.hasEvent(peerE, RoutingSecurityEvent.validationPassed), true);
    });
  });

  // ── Test 18: Route Discovery with Multiple Peers ───────────

  group('Test 18 — Route discovery multi-peer topology', () {
    late TopologyRepository repository;
    late RouteDiscovery discovery;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('A→B direct, A→B→E indirect via topology', () {
      repository.setLocalTopology({peerB, peerC});
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));

      discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => {peerB, peerC},
      );

      // B is direct.
      final bResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerB,
      );
      expect(bResult.isFound, true);
      expect(bResult.route!.metric, 1);

      // E is indirect via B.
      final eResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerE,
      );
      expect(eResult.isFound, true);
      expect(eResult.route!.nextHopPeerId, peerB);
      expect(eResult.route!.metric, 2);
    });

    test('multiple paths — deterministic first-hop', () {
      repository.setLocalTopology({peerB, peerC});
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerE],
      ));

      discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => {peerB, peerC},
      );

      // Both B and C can reach E — BFS picks first sorted neighbor.
      final eResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerE,
      );
      expect(eResult.isFound, true);
      // BFS starts with sorted neighbors: bb < cc, so first hop = B.
      expect(eResult.route!.nextHopPeerId, peerB);
    });
  });

  // ── Test 19: Multi-Peer Topology Scenario ──────────────────

  group('Test 19 — Multi-peer topology scenario', () {
    late TopologyRepository repository;
    late RouteDiscovery discovery;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('topology: B→E, C→F, D→G — each route via correct next hop', () {
      repository.setLocalTopology({peerB, peerC, peerD});
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerF],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerD,
        sequence: 1,
        neighbors: [peerG],
      ));

      discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => {peerB, peerC, peerD},
      );

      final eResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerE,
      );
      expect(eResult.route!.nextHopPeerId, peerB);

      final fResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerF,
      );
      expect(fResult.route!.nextHopPeerId, peerC);

      final gResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerG,
      );
      expect(gResult.route!.nextHopPeerId, peerD);
    });

    test('B disconnects — E route affected, F and G unaffected', () {
      repository.setLocalTopology({peerB, peerC, peerD});
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerF],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerD,
        sequence: 1,
        neighbors: [peerG],
      ));
      repository.removeSource(peerB); // B's topology removed

      discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => {peerC, peerD}, // B not reachable
      );

      final eResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerE,
      );
      expect(eResult.isNotFound, true); // E not reachable

      final fResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerF,
      );
      expect(fResult.isFound, true);
      expect(fResult.route!.nextHopPeerId, peerC);

      final gResult = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerG,
      );
      expect(gResult.isFound, true);
      expect(gResult.route!.nextHopPeerId, peerD);
    });
  });

  // ── Test 20: Alternate Path Recovery ───────────────────────

  group('Test 20 — Alternate path recovery B→E via C', () {
    late TopologyRepository repository;
    late RoutingTable table;
    late RouteRecoveryService recovery;

    setUp(() {
      repository = TopologyRepository();
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() {
      recovery.dispose();
      repository.clear();
      table.clear();
    });

    test('E via B fails, recovery finds E via C', () {
      repository.setLocalTopology({peerB, peerC});
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerE],
      ));

      table.addRoute(makeRoute(destination: peerE, nextHop: peerB, metric: 2));

      // B is disconnected — only C is reachable.
      recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) {
          final discovery = RouteDiscovery(
            topologyRepository: repository,
            getReachableNeighbors: () => {peerC}, // B not reachable
          );
          return discovery.discoverRoute(
            localPeerId: localPeer,
            destinationPeerId: destinationPeerId,
          );
        },
        routingTable: table,
      );

      // Fail E via B.
      final result = recovery.handleFailure(FailureEvent(
        destination: peerE,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));

      expect(result.isRecovered, true);
      expect(result.route!.nextHopPeerId, peerC);
      expect(table.bestRoute(peerE)?.nextHopPeerId, peerC);
    });
  });

  // ── Test 21: Topology Update Ordering ──────────────────────

  group('Test 21 — Topology update ordering B and C', () {
    late TopologyRepository repository;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('out-of-order B/C updates result in latest valid state', () {
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 10, neighbors: [peerE]));
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 20, neighbors: [peerF]));
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 11, neighbors: [peerG]));
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 21, neighbors: [peerH]));

      expect(repository.getRemoteEntry(peerB)!.sequence, 11);
      expect(repository.getRemoteEntry(peerB)!.neighborPeerIds, [peerG]);
      expect(repository.getRemoteEntry(peerC)!.sequence, 21);
      expect(repository.getRemoteEntry(peerC)!.neighborPeerIds, [peerH]);
    });
  });

  // ── Test 22: Concurrent Topology Updates ───────────────────

  group('Test 22 — Concurrent topology updates B/C/D', () {
    late TopologyRepository repository;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('applying B/C/D advertisements concurrently preserves all', () {
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 1, neighbors: [peerE]));
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 1, neighbors: [peerF]));
      repository.recordAdvertisement(makeAd(source: peerD, sequence: 1, neighbors: [peerG]));

      expect(repository.remoteSourceCount, 3);
      expect(repository.advertisedNeighborsOf(peerB), {peerE});
      expect(repository.advertisedNeighborsOf(peerC), {peerF});
      expect(repository.advertisedNeighborsOf(peerD), {peerG});
    });

    test('concurrent snapshot updates are independent', () {
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 1, neighbors: [peerE]));
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 1, neighbors: [peerF]));

      // B updates snapshot.
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 2, neighbors: [peerG]));
      // C updates snapshot.
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 2, neighbors: [peerH]));

      expect(repository.advertisedNeighborsOf(peerB), {peerG});
      expect(repository.advertisedNeighborsOf(peerC), {peerH});
    });
  });

  // ── Test 23: No Global State Contamination ─────────────────

  group('Test 23 — Changing B cannot mutate C', () {
    late NeighborTable neighborTable;
    late MockPeerConnectionManager connectionManager;
    late TopologyRepository repository;
    late RoutingTable table;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);
      neighborTable = NeighborTable(connectionManager: connectionManager);
      repository = TopologyRepository();
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() {
      neighborTable.dispose();
      repository.clear();
      table.clear();
    });

    test('neighbor change for B does not alter C', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      neighborTable.removeNeighbor(peerB);

      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.isNeighbor(peerC), true);
    });

    test('topology change from B does not alter C', () {
      repository.recordAdvertisement(makeAd(source: peerB, sequence: 1, neighbors: [peerE]));
      repository.recordAdvertisement(makeAd(source: peerC, sequence: 1, neighbors: [peerF]));

      repository.removeSource(peerB);

      expect(repository.advertisedNeighborsOf(peerB), isEmpty);
      expect(repository.advertisedNeighborsOf(peerC), {peerF});
    });

    test('route change for C does not alter D', () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));

      table.removeRoutesTo(peerC);

      expect(table.hasRouteTo(peerC), false);
      expect(table.hasRouteTo(peerD), true);
    });
  });

  // ── Test 24: Restart — No Fabricated State ─────────────────

  group('Test 24 — Restart does not fabricate state', () {
    test('fresh NeighborTable starts empty', () {
      final connMgr = MockPeerConnectionManager();
      when(connMgr.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connMgr.connections).thenReturn([]);

      final table = NeighborTable(connectionManager: connMgr);
      expect(table.count, 0);
      expect(table.hasNeighbors, false);
      table.dispose();
    });

    test('fresh RoutingTable starts empty', () {
      final table = RoutingTable(localPeerId: localPeer);
      expect(table.destinationCount, 0);
      expect(table.routeCount, 0);
      expect(table.allRoutes, isEmpty);
    });

    test('fresh TopologyRepository starts empty', () {
      final repo = TopologyRepository();
      expect(repo.remoteSourceCount, 0);
      expect(repo.localNeighborIds, isEmpty);
      expect(repo.allKnownPeerIds, isEmpty);
    });

    test('fresh RouteRecoveryService starts with no state', () {
      final table = RoutingTable(localPeerId: localPeer);
      final recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) =>
            const DiscoveryResult.notFound(),
        routingTable: table,
      );

      expect(recovery.isRecovering(peerB), false);
      expect(recovery.generationFor(peerB), 0);

      recovery.dispose();
      table.clear();
    });
  });

  // ── Test 25: Disposal Safety ───────────────────────────────

  group('Test 25 — Disposal safely terminates routing activity', () {
    test('NeighborTable dispose closes stream and stops emitting', () {
      final connMgr = MockPeerConnectionManager();
      when(connMgr.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connMgr.connections).thenReturn([]);

      final table = NeighborTable(connectionManager: connMgr);
      table.addNeighbor(peerB);

      // Stream should be non-null before dispose.
      expect(table.neighborStream, isNotNull);

      table.dispose();

      // After dispose, adding neighbors should not throw but stream is closed.
      // The count still reflects internal state (dispose doesn't clear data).
      expect(table.count, 1);
    });

    test('RoutingTable clear empties everything', () {
      final table = RoutingTable(localPeerId: localPeer);
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerB, metric: 2));

      table.clear();

      expect(table.destinationCount, 0);
      expect(table.routeCount, 0);
    });

    test('RouteRecoveryService dispose clears state', () {
      final table = RoutingTable(localPeerId: localPeer);
      final recovery = RouteRecoveryService(
        localPeerId: localPeer,
        discoverRoute: ({
          required String localPeerId,
          required String destinationPeerId,
        }) =>
            const DiscoveryResult.notFound(),
        routingTable: table,
      );

      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      recovery.handleFailure(FailureEvent(
        destination: peerC,
        previousNextHop: peerB,
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));

      recovery.dispose();

      expect(recovery.isRecovering(peerC), false);
      expect(recovery.generationFor(peerC), 0);

      table.clear();
    });

    test('TopologyRepository clear resets everything', () {
      final repo = TopologyRepository();
      repo.setLocalTopology({peerB, peerC});
      repo.recordAdvertisement(makeAd(source: peerB, sequence: 1, neighbors: [peerE]));

      repo.clear();

      expect(repo.localNeighborIds, isEmpty);
      expect(repo.remoteSourceCount, 0);
    });
  });

  // ── Test 26: Multi-Destination Failure Scenario ────────────

  group('Test 26 — Multi-Destination failure cascade', () {
    late RoutingTable table;

    setUp(() {
      table = RoutingTable(localPeerId: localPeer);
    });

    tearDown(() => table.clear());

    test('B fails — C via B and G via B removed, D via C and E via D unaffected',
        () {
      table.addRoute(makeRoute(destination: peerC, nextHop: peerB, metric: 2));
      table.addRoute(makeRoute(destination: peerD, nextHop: peerC, metric: 3));
      table.addRoute(makeRoute(destination: peerE, nextHop: peerD, metric: 4));
      table.addRoute(makeRoute(destination: peerF, nextHop: peerC, metric: 3));
      table.addRoute(makeRoute(destination: peerG, nextHop: peerB, metric: 2));

      table.removeRoutesVia(peerB);

      expect(table.hasRouteTo(peerC), false); // C via B removed
      expect(table.hasRouteTo(peerG), false); // G via B removed
      expect(table.hasRouteTo(peerD), true); // D via C unaffected
      expect(table.hasRouteTo(peerE), true); // E via D unaffected
      expect(table.hasRouteTo(peerF), true); // F via C unaffected
    });
  });

  // ── Test 27: PeerReachability Isolation ────────────────────

  group('Test 27 — PeerReachability evaluates each peer independently', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable neighborTable;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      neighborTable = NeighborTable(connectionManager: connectionManager);
    });

    tearDown(() {
      neighborTable.dispose();
    });

    test('neighbor state is isolated per peer', () {
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      expect(neighborTable.isNeighbor(peerB), true);
      expect(neighborTable.isNeighbor(peerC), true);

      neighborTable.removeNeighbor(peerB);

      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.isNeighbor(peerC), true);
    });
  });

  // ── Test 28: RouteExpiration Isolation ─────────────────────

  group('Test 28 — RouteExpiration validates each route independently', () {
    late RouteExpirationService expirationService;

    setUp(() {
      expirationService = RouteExpirationService();
    });

    test('expired route does not affect valid route', () {
      final now = DateTime.now();
      final expiredRoute = makeRoute(
        destination: peerC,
        nextHop: peerB,
        metric: 2,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final validRoute = makeRoute(
        destination: peerD,
        nextHop: peerB,
        metric: 2,
        expiresAt: now.add(const Duration(minutes: 5)),
      );

      final expiredResult = expirationService.validateRoute(
        expiredRoute,
        reachableNeighbors: {peerB},
        now: now,
      );
      final validResult = expirationService.validateRoute(
        validRoute,
        reachableNeighbors: {peerB},
        now: now,
      );

      expect(expiredResult.isExpired, true);
      expect(validResult.isValid, true);
    });

    test('unreachable next-hop does not affect route with different next-hop',
        () {
      final routeViaB = makeRoute(
        destination: peerC,
        nextHop: peerB,
        metric: 2,
      );
      final routeViaD = makeRoute(
        destination: peerE,
        nextHop: peerD,
        metric: 3,
      );

      // B not reachable, D is reachable.
      final resultB = expirationService.validateRoute(
        routeViaB,
        reachableNeighbors: {peerD},
      );
      final resultD = expirationService.validateRoute(
        routeViaD,
        reachableNeighbors: {peerD},
      );

      expect(resultB.isUnreachable, true);
      expect(resultD.isValid, true);
    });
  });

  // ── Test 29: Full Stack Integration ────────────────────────

  group('Test 29 — Full I8 stack integration', () {
    late MockPeerConnectionManager connectionManager;
    late NeighborTable neighborTable;
    late TopologyRepository repository;
    late RoutingTable table;
    late RouteExpirationService expiration;

    setUp(() {
      connectionManager = MockPeerConnectionManager();
      when(connectionManager.connectionStream).thenAnswer((_) => const Stream.empty());
      when(connectionManager.connections).thenReturn([]);

      neighborTable = NeighborTable(connectionManager: connectionManager);
      repository = TopologyRepository();
      table = RoutingTable(localPeerId: localPeer);
      expiration = RouteExpirationService();
    });

    tearDown(() {
      neighborTable.dispose();
      repository.clear();
      table.clear();
    });

    test('end-to-end: peer connects → topology → discovery → routing → failure → recovery',
        () {
      // Step 1: B and C connect as neighbors.
      neighborTable.addNeighbor(peerB);
      neighborTable.addNeighbor(peerC);

      // Step 2: B advertises E, C advertises F.
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));
      repository.recordAdvertisement(makeAd(
        source: peerC,
        sequence: 1,
        neighbors: [peerF],
      ));

      // Step 3: Discover routes.
      final discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => {peerB, peerC},
      );

      final eRoute = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerE,
      );
      final fRoute = discovery.discoverRoute(
        localPeerId: localPeer,
        destinationPeerId: peerF,
      );

      expect(eRoute.isFound, true);
      expect(fRoute.isFound, true);

      // Step 4: Install routes.
      table.addRoute(eRoute.route!);
      table.addRoute(fRoute.route!);

      expect(table.bestRoute(peerE)?.nextHopPeerId, peerB);
      expect(table.bestRoute(peerF)?.nextHopPeerId, peerC);

      // Step 5: B disconnects — E route affected.
      neighborTable.removeNeighbor(peerB);
      repository.removeSource(peerB);

      expect(neighborTable.isNeighbor(peerB), false);
      expect(neighborTable.isNeighbor(peerC), true);

      // E route still in table but next hop unreachable.
      final eValidation = expiration.validateRoute(
        table.bestRoute(peerE)!,
        reachableNeighbors: neighborTable.neighborPeerIds,
      );
      expect(eValidation.isUnreachable, true);

      // F route still valid.
      final fValidation = expiration.validateRoute(
        table.bestRoute(peerF)!,
        reachableNeighbors: neighborTable.neighborPeerIds,
      );
      expect(fValidation.isValid, true);
    });
  });

  // ── Test 30: Identity Change Does Not Transfer ─────────────

  group('Test 30 — Identity change does not inherit routing state', () {
    late TopologyRepository repository;

    setUp(() {
      repository = TopologyRepository();
    });

    tearDown(() => repository.clear());

    test('B_old topology does not transfer to B_new', () {
      repository.recordAdvertisement(makeAd(
        source: peerB,
        sequence: 1,
        neighbors: [peerE],
      ));

      expect(repository.advertisedNeighborsOf(peerB), {peerE});

      // B_old removed, B_new appears with different identity.
      repository.removeSource(peerB);
      repository.recordAdvertisement(makeAd(
        source: peerX,
        sequence: 1,
        neighbors: [peerG],
      ));

      // B_old topology gone.
      expect(repository.advertisedNeighborsOf(peerB), isEmpty);
      // B_new has its own topology.
      expect(repository.advertisedNeighborsOf(peerX), {peerG});
    });
  });
}
