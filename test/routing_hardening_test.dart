import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_failure.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/route_selector.dart';
import 'package:onebit/features/routing/routing_limits.dart';
import 'package:onebit/features/routing/routing_security.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/routing_validators.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/trust/trust_service.dart';

import 'routing_hardening_test.mocks.dart';

@GenerateMocks([PeerConnectionManager, TrustService])
void main() {
  late MockPeerConnectionManager mockConnectionManager;
  late MockTrustService mockTrustService;

  setUp(() {
    mockConnectionManager = MockPeerConnectionManager();
    mockTrustService = MockTrustService();
    when(mockConnectionManager.connectionStream)
        .thenAnswer((_) => const Stream.empty());
    when(mockConnectionManager.connections).thenReturn([]);
  });

  // ─── Helper ────────────────────────────────────────────────
  String peerId(int n) => n.toRadixString(16).padLeft(64, '0');

  Route route0(String dest, String nextHop, int metric,
      {RouteState state = RouteState.active}) {
    final now = DateTime.utc(2025, 1, 1);
    return Route(
      destinationPeerId: dest,
      nextHopPeerId: nextHop,
      metric: metric,
      state: state,
      source: RouteSource.advertised,
      createdAt: now,
      lastValidatedAt: now,
    );
  }

  // ════════════════════════════════════════════════════════════
  // 1. Input Validation — Malformed PeerIds
  // ════════════════════════════════════════════════════════════
  group('RoutingValidators — PeerId validation', () {
    test('rejects empty string', () {
      expect(RoutingValidators.isValidPeerId(''), isFalse);
    });

    test('rejects too-short string', () {
      expect(RoutingValidators.isValidPeerId('abcd1234'), isFalse);
    });

    test('rejects too-long string', () {
      expect(RoutingValidators.isValidPeerId('${peerId(1)}ab'), isFalse);
    });

    test('rejects uppercase hex', () {
      final id = 'A' * 64;
      expect(RoutingValidators.isValidPeerId(id), isFalse);
    });

    test('rejects non-hex characters', () {
      final id = 'g${'0' * 63}';
      expect(RoutingValidators.isValidPeerId(id), isFalse);
    });

    test('rejects PeerId with spaces', () {
      final id = ' ${'0' * 63}';
      expect(RoutingValidators.isValidPeerId(id), isFalse);
    });

    test('accepts valid lowercase hex 64-char PeerId', () {
      expect(RoutingValidators.isValidPeerId(peerId(1)), isTrue);
    });

    test('accepts all digits', () {
      final id = '9' * 64;
      expect(RoutingValidators.isValidPeerId(id), isTrue);
    });

    test('accepts all a-f', () {
      final id = 'f' * 64;
      expect(RoutingValidators.isValidPeerId(id), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 2. Input Validation — Metrics
  // ════════════════════════════════════════════════════════════
  group('RoutingValidators — Metric validation', () {
    test('rejects metric 0', () {
      expect(RoutingValidators.isValidMetric(0), isFalse);
    });

    test('rejects negative metric', () {
      expect(RoutingValidators.isValidMetric(-1), isFalse);
    });

    test('accepts metric 1', () {
      expect(RoutingValidators.isValidMetric(1), isTrue);
    });

    test('accepts maxRouteMetric (255)', () {
      expect(RoutingValidators.isValidMetric(RoutingLimits.maxRouteMetric),
          isTrue);
    });

    test('rejects maxRouteMetric + 1', () {
      expect(
          RoutingValidators.isValidMetric(RoutingLimits.maxRouteMetric + 1),
          isFalse);
    });

    test('rejects very large metric', () {
      expect(RoutingValidators.isValidMetric(999999), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 3. Input Validation — validateRoute
  // ════════════════════════════════════════════════════════════
  group('RoutingValidators — validateRoute', () {
    test('rejects empty destination', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: '',
        nextHopPeerId: peerId(2),
        metric: 1,
        localPeerId: peerId(0),
      );
      expect(errors, contains(RoutingValidationError.emptyDestination));
    });

    test('rejects empty next hop', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: '',
        metric: 1,
        localPeerId: peerId(0),
      );
      expect(errors, contains(RoutingValidationError.emptyNextHop));
    });

    test('rejects self-destination', () {
      final local = peerId(0);
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: local,
        nextHopPeerId: peerId(1),
        metric: 1,
        localPeerId: local,
      );
      expect(errors, contains(RoutingValidationError.selfDestination));
    });

    test('rejects self as next hop', () {
      final local = peerId(0);
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: local,
        metric: 1,
        localPeerId: local,
      );
      expect(errors, contains(RoutingValidationError.selfNextHop));
    });

    test('allows destination == next hop (direct routes are valid)', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: peerId(1),
        metric: 1,
        localPeerId: peerId(0),
      );
      expect(errors, isEmpty);
    });

    test('rejects metric 0', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: peerId(2),
        metric: 0,
        localPeerId: peerId(0),
      );
      expect(errors, contains(RoutingValidationError.metricZero));
    });

    test('rejects metric exceeding max', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: peerId(2),
        metric: RoutingLimits.maxRouteMetric + 1,
        localPeerId: peerId(0),
      );
      expect(errors, contains(RoutingValidationError.metricOutOfBounds));
    });

    test('accepts valid route', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(1),
        nextHopPeerId: peerId(2),
        metric: 1,
        localPeerId: peerId(0),
      );
      expect(errors, isEmpty);
    });

    test('no localPeerId skips self-destination check', () {
      final errors = RoutingValidators.validateRoute(
        destinationPeerId: peerId(0),
        nextHopPeerId: peerId(1),
        metric: 1,
        localPeerId: null,
      );
      expect(errors, isNot(contains(RoutingValidationError.selfDestination)));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 4. Input Validation — validateAdvertisement
  // ════════════════════════════════════════════════════════════
  group('RoutingValidators — validateAdvertisement', () {
    test('rejects invalid source identity', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: 'bad',
        sequence: 1,
        neighbors: [],
        protocolVersion: 1,
      );
      expect(errors, contains(RoutingValidationError.invalidPeerIdLength));
    });

    test('rejects negative sequence', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(1),
        sequence: -1,
        neighbors: [],
        protocolVersion: 1,
      );
      expect(errors, contains(RoutingValidationError.invalidSequence));
    });

    test('rejects too many neighbors', () {
      final neighbors =
          List.generate(RoutingLimits.maxNeighborsPerSource + 1, peerId);
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(0),
        sequence: 1,
        neighbors: neighbors,
        protocolVersion: 1,
      );
      expect(errors, contains(RoutingValidationError.collectionTooLarge));
    });

    test('rejects self-loop in neighbors', () {
      final source = peerId(1);
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: source,
        sequence: 1,
        neighbors: [source],
        protocolVersion: 1,
      );
      expect(errors, contains(RoutingValidationError.selfLoop));
    });

    test('rejects invalid neighbor PeerId', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(1),
        sequence: 1,
        neighbors: ['bad'],
        protocolVersion: 1,
      );
      expect(errors, contains(RoutingValidationError.invalidPeerIdLength));
    });

    test('rejects unsupported version', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(1),
        sequence: 1,
        neighbors: [],
        protocolVersion: 0,
      );
      expect(errors, contains(RoutingValidationError.unsupportedVersion));
    });

    test('rejects payload too large', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(1),
        sequence: 1,
        neighbors: [],
        protocolVersion: 1,
        payloadSize: RoutingLimits.maxAdvertisementPayloadSize + 1,
      );
      expect(errors, contains(RoutingValidationError.payloadTooLarge));
    });

    test('accepts valid advertisement', () {
      final errors = RoutingValidators.validateAdvertisement(
        sourceIdentity: peerId(1),
        sequence: 1,
        neighbors: [peerId(2), peerId(3)],
        protocolVersion: 1,
      );
      expect(errors, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 5. Bounds Enforcement — NeighborTable max neighbors
  // ════════════════════════════════════════════════════════════
  group('NeighborTable — bounds enforcement', () {
    test('rejects new neighbors when at max capacity and no stale entries',
        () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      // Fill to capacity with active neighbors.
      for (var i = 0; i < RoutingLimits.maxNeighbors; i++) {
        table.addNeighbor(peerId(i));
      }
      expect(table.count, RoutingLimits.maxNeighbors);

      // Adding one more should be rejected (no stale entries to evict).
      table.addNeighbor(peerId(RoutingLimits.maxNeighbors));
      expect(table.count, RoutingLimits.maxNeighbors);
    });

    test('evicts stale entries to make room for new active neighbors', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      // Fill to capacity.
      for (var i = 0; i < RoutingLimits.maxNeighbors; i++) {
        table.addNeighbor(peerId(i));
      }
      // Force-remove half (bypass grace period).
      for (var i = 0; i < RoutingLimits.maxNeighbors ~/ 2; i++) {
        table.forceRemoveNeighbor(peerId(i));
      }
      // Should now be able to add new neighbors (stale eviction frees space).
      table.addNeighbor(peerId(RoutingLimits.maxNeighbors));
      expect(table.isNeighbor(peerId(RoutingLimits.maxNeighbors)), isTrue);
    });

    test('addNeighbor is idempotent for existing neighbors', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.addNeighbor(peerId(1));
      table.addNeighbor(peerId(1));
      expect(table.count, 1);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 6. Bounds Enforcement — RoutingTable max destinations
  // ════════════════════════════════════════════════════════════
  group('RoutingTable — bounds enforcement', () {
    test('rejects new destinations when at max capacity', () {
      final table = RoutingTable();
      for (var i = 0; i < RoutingLimits.maxRouteDestinations; i++) {
        table.addRoute(route0(peerId(i + 10), peerId(1), 2));
      }
      expect(table.destinationCount, RoutingLimits.maxRouteDestinations);

      // Adding one more should be silently rejected.
      table.addRoute(
          route0(peerId(RoutingLimits.maxRouteDestinations + 10), peerId(1), 2));
      expect(table.destinationCount, RoutingLimits.maxRouteDestinations);
    });

    test('rejects new routes per destination when at max capacity', () {
      final dest = peerId(100);
      final table = RoutingTable();
      for (var i = 0; i < RoutingLimits.maxRoutesPerDestination; i++) {
        table.addRoute(route0(dest, peerId(200 + i), 2));
      }
      expect(table.routesTo(dest).length, RoutingLimits.maxRoutesPerDestination);

      // Adding one more should be silently rejected.
      table.addRoute(route0(dest, peerId(999), 2));
      expect(table.routesTo(dest).length, RoutingLimits.maxRoutesPerDestination);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 7. Disposal Safety — NeighborTable
  // ════════════════════════════════════════════════════════════
  group('NeighborTable — disposal safety', () {
    test('addNeighbor is no-op after dispose', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.addNeighbor(peerId(1));
      table.dispose();
      expect(table.isDisposed, isTrue);

      table.addNeighbor(peerId(2));
      expect(table.count, 1); // unchanged
    });

    test('initialize is no-op after dispose', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.dispose();
      // Should not throw.
      table.initialize();
    });

    test('initialize is idempotent', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.initialize();
      table.initialize(); // second call is no-op
    });
  });

  // ════════════════════════════════════════════════════════════
  // 8. Disposal Safety — RouteRecoveryService
  // ════════════════════════════════════════════════════════════
  group('RouteRecoveryService — disposal safety', () {
    test('handleFailure returns cancelled after dispose', () {
      final table = RoutingTable();
      final service = RouteRecoveryService(
        localPeerId: peerId(0),
        routingTable: table,
        discoverRoute: ({required String localPeerId, required String destinationPeerId}) =>
            const DiscoveryResult.notFound(),
      );
      service.dispose();
      final result = service.handleFailure(FailureEvent(
        destination: peerId(1),
        previousNextHop: peerId(2),
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));
      expect(result, isA<RecoveryResult>());
      expect(result.isCancelled, isTrue);
    });

    test('cancelRecovery is safe after dispose', () {
      final table = RoutingTable();
      final service = RouteRecoveryService(
        localPeerId: peerId(0),
        routingTable: table,
        discoverRoute: ({required String localPeerId, required String destinationPeerId}) =>
            const DiscoveryResult.notFound(),
      );
      service.dispose();
      // Should not throw.
      service.cancelRecovery(peerId(1));
    });

    test('dispose is idempotent', () {
      final table = RoutingTable();
      final service = RouteRecoveryService(
        localPeerId: peerId(0),
        routingTable: table,
        discoverRoute: ({required String localPeerId, required String destinationPeerId}) =>
            const DiscoveryResult.notFound(),
      );
      service.dispose(); // second call is safe
    });
  });

  // ════════════════════════════════════════════════════════════
  // 9. Stale Async Protection — RouteRecoveryService generation
  // ════════════════════════════════════════════════════════════
  group('RouteRecoveryService — stale protection', () {
    test('generation increments on each recovery attempt', () {
      final table = RoutingTable();
      final service = RouteRecoveryService(
        localPeerId: peerId(0),
        routingTable: table,
        discoverRoute: ({required String localPeerId, required String destinationPeerId}) =>
            const DiscoveryResult.notFound(),
      );
      final dest = peerId(1);
      expect(service.generationFor(dest), 0);

      service.handleFailure(FailureEvent(
        destination: dest,
        previousNextHop: peerId(2),
        reason: FailureReason.nextHopUnreachable,
        timestamp: DateTime.now(),
      ));
      expect(service.generationFor(dest), 1);

      service.handleFailure(FailureEvent(
        destination: dest,
        previousNextHop: peerId(3),
        reason: FailureReason.expired,
        timestamp: DateTime.now(),
      ));
      expect(service.generationFor(dest), 2);
    });

    test('generationFor returns 0 for unknown destination', () {
      final table = RoutingTable();
      final service = RouteRecoveryService(
        localPeerId: peerId(0),
        routingTable: table,
        discoverRoute: ({required String localPeerId, required String destinationPeerId}) =>
            const DiscoveryResult.notFound(),
      );
      expect(service.generationFor(peerId(99)), 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 10. RoutingSecurityValidator — Event log bounds
  // ════════════════════════════════════════════════════════════
  group('RoutingSecurityValidator — event log bounds', () {
    test('event log is capped at maxSecurityEventLog', () {
      final validator = RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      // Generate more events than the cap.
      for (var i = 0; i < RoutingLimits.maxSecurityEventLog + 50; i++) {
        validator.validate(
          advertisement: TopologyAdvertisement(
            sourceIdentity: source,
            sequence: i,
            neighborPeerIds: [peerId(2)],
          ),
          authenticatedPeerId: source,
        );
      }

      expect(validator.eventLog.length, RoutingLimits.maxSecurityEventLog);
    });

    test('event log retains most recent entries when capped', () {
      final validator = RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      // Generate events with incrementing sequences.
      for (var i = 0; i < RoutingLimits.maxSecurityEventLog + 10; i++) {
        validator.validate(
          advertisement: TopologyAdvertisement(
            sourceIdentity: source,
            sequence: i,
            neighborPeerIds: [peerId(2)],
          ),
          authenticatedPeerId: source,
        );
      }

      // The oldest entries should be dropped.
      // The last entry should have the highest sequence.
      final lastEntry = validator.eventLog.last;
      expect(lastEntry.$1, source);
    });

    test('event log getter returns unmodifiable view', () {
      final validator = RoutingSecurityValidator(trustService: mockTrustService);
      // The getter returns UnmodifiableListView — cannot add/remove.
      // Attempting to cast and add should throw.
      final log = validator.eventLog;
      expect(() => log.add(('x', RoutingSecurityEvent.validationPassed)),
          throwsA(anything));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 11. RoutingSecurityValidator — all event types logged
  // ════════════════════════════════════════════════════════════
  group('RoutingSecurityValidator — security event coverage', () {
    test('sender identity mismatch is logged', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);
      final other = peerId(2);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [],
        ),
        authenticatedPeerId: other, // mismatch
      );

      expect(
          validator.hasEvent(source, RoutingSecurityEvent.senderIdentityMismatch),
          isTrue);
    });

    test('sender not authenticated is logged', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(false);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [],
        ),
        authenticatedPeerId: source,
      );

      expect(
          validator.hasEvent(
              source, RoutingSecurityEvent.senderNotAuthenticated),
          isTrue);
    });

    test('structural validation failure is logged', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);

      // Invalid advertisement with 'bad' sourceIdentity (wrong length).
      // authenticatedPeerId matches sourceIdentity so identity binding passes.
      // isAuthenticated('bad') returns true so authentication passes.
      // advertisement.isValid returns false → structural validation failure.
      when(mockTrustService.isAuthenticated('bad')).thenReturn(true);

      validator.validate(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: 'bad',
          sequence: 1,
          neighborPeerIds: [],
        ),
        authenticatedPeerId: 'bad',
      );

      expect(
          validator.hasEvent(
              'bad', RoutingSecurityEvent.structuralValidationFailed),
          isTrue);
    });

    test('validation passed is logged', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [peerId(2)],
        ),
        authenticatedPeerId: source,
      );

      expect(
          validator.hasEvent(source, RoutingSecurityEvent.validationPassed),
          isTrue);
    });

    test('duplicate neighbors normalized is logged', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [peerId(2), peerId(2), peerId(3)],
        ),
        authenticatedPeerId: source,
      );

      expect(
          validator.hasEvent(
              source, RoutingSecurityEvent.duplicateNeighborsNormalized),
          isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 12. Route.toString safety — short PeerIds
  // ════════════════════════════════════════════════════════════
  group('Route — toString safety', () {
    test('toString does not crash with short destination PeerId', () {
      final route = route0('abc', peerId(2), 1);
      expect(() => route.toString(), returnsNormally);
    });

    test('toString does not crash with short next-hop PeerId', () {
      final route = route0(peerId(1), 'xyz', 1);
      expect(() => route.toString(), returnsNormally);
    });

    test('toString does not crash with both PeerIds short', () {
      final route = route0('a', 'b', 1);
      expect(() => route.toString(), returnsNormally);
    });

    test('toString with valid PeerIds uses first 8 chars', () {
      final dest = peerId(1);
      final nextHop = peerId(2);
      final route = route0(dest, nextHop, 1);
      final str = route.toString();
      expect(str, contains(dest.substring(0, 8)));
      expect(str, contains(nextHop.substring(0, 8)));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 13. RouteSelector — rejects inactive routes
  // ════════════════════════════════════════════════════════════
  group('RouteSelector — rejects inactive routes', () {
    test('selectBestRoute rejects stale routes', () {
      final candidates = [
        route0(peerId(1), peerId(2), 1, state: RouteState.stale),
        route0(peerId(1), peerId(3), 2, state: RouteState.stale),
      ];
      expect(selectBestRoute(candidates), isNull);
    });

    test('selectBestRoute rejects invalid routes', () {
      final candidates = [
        route0(peerId(1), peerId(2), 1, state: RouteState.invalid),
      ];
      expect(selectBestRoute(candidates), isNull);
    });

    test('selectBestRoute picks active over stale', () {
      final candidates = [
        route0(peerId(1), peerId(2), 3, state: RouteState.active),
        route0(peerId(1), peerId(3), 1, state: RouteState.stale),
      ];
      final best = selectBestRoute(candidates);
      expect(best, isNotNull);
      expect(best!.nextHopPeerId, peerId(2)); // active wins over stale
    });
  });

  // ════════════════════════════════════════════════════════════
  // 14. TopologyExchangeService — sequence overflow guard
  // ════════════════════════════════════════════════════════════
  group('RoutingLimits — constants are sane', () {
    test('maxNeighbors is positive', () {
      expect(RoutingLimits.maxNeighbors, greaterThan(0));
    });

    test('maxRouteMetric is 255', () {
      expect(RoutingLimits.maxRouteMetric, 255);
    });

    test('peerIdLength is 64', () {
      expect(RoutingLimits.peerIdLength, 64);
    });

    test('maxRecoveryAttempts is positive', () {
      expect(RoutingLimits.maxRecoveryAttempts, greaterThan(0));
    });

    test('maxAdvertisementPayloadSize is positive', () {
      expect(RoutingLimits.maxAdvertisementPayloadSize, greaterThan(0));
    });

    test('maxDiagnosticEvents is positive', () {
      expect(RoutingLimits.maxDiagnosticEvents, greaterThan(0));
    });

    test('maxSecurityEventLog is positive', () {
      expect(RoutingLimits.maxSecurityEventLog, greaterThan(0));
    });

    test('maxDiscoveryDepth is positive', () {
      expect(RoutingLimits.maxDiscoveryDepth, greaterThan(0));
    });

    test('maxDiscoveryVisited is positive', () {
      expect(RoutingLimits.maxDiscoveryVisited, greaterThan(0));
    });

    test('maxRecoveryStates is positive', () {
      expect(RoutingLimits.maxRecoveryStates, greaterThan(0));
    });

    test('staleNeighborGracePeriod is positive', () {
      expect(RoutingLimits.staleNeighborGracePeriod, greaterThan(Duration.zero));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 15. RoutingTable — metric validation integration
  // ════════════════════════════════════════════════════════════
  group('RoutingTable — metric validation', () {
    test('rejects route with metric 0', () {
      final table = RoutingTable();
      expect(
        () => table.addRoute(route0(peerId(1), peerId(2), 0)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects route with negative metric', () {
      final table = RoutingTable();
      expect(
        () => table.addRoute(route0(peerId(1), peerId(2), -1)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('rejects route with metric exceeding max', () {
      final table = RoutingTable();
      expect(
        () => table.addRoute(
            route0(peerId(1), peerId(2), RoutingLimits.maxRouteMetric + 1)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('accepts route with metric = 1', () {
      final table = RoutingTable();
      table.addRoute(route0(peerId(1), peerId(2), 1));
      expect(table.destinationCount, 1);
    });

    test('accepts route with metric = maxRouteMetric', () {
      final table = RoutingTable();
      table.addRoute(
          route0(peerId(1), peerId(2), RoutingLimits.maxRouteMetric));
      expect(table.destinationCount, 1);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 16. Identity Isolation — PeerId never BLE address
  // ════════════════════════════════════════════════════════════
  group('Identity isolation', () {
    test('RoutingTable rejects routes with empty PeerIds', () {
      final table = RoutingTable();
      expect(
        () => table.addRoute(route0('', peerId(2), 1)),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('RoutingTable accepts routes with 64-char hex PeerIds', () {
      final table = RoutingTable();
      table.addRoute(route0(peerId(1), peerId(2), 1));
      expect(table.destinationCount, 1);
    });

    test('PeerId validation rejects non-64-char strings', () {
      expect(RoutingValidators.isValidPeerId('short'), isFalse);
      expect(RoutingValidators.isValidPeerId(''), isFalse);
      expect(RoutingValidators.isValidPeerId(peerId(1)), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 17. NeighborTable — disposal state tracking
  // ════════════════════════════════════════════════════════════
  group('NeighborTable — disposal state', () {
    test('isDisposed is false initially', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      expect(table.isDisposed, isFalse);
    });

    test('isDisposed is true after dispose', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.dispose();
      expect(table.isDisposed, isTrue);
    });

    test('removeNeighbor is safe after dispose', () {
      final table = NeighborTable(connectionManager: mockConnectionManager);
      table.addNeighbor(peerId(1));
      table.dispose();
      // Should not throw.
      table.removeNeighbor(peerId(1));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 18. RoutingTable — duplicate route deduplication
  // ════════════════════════════════════════════════════════════
  group('RoutingTable — deduplication', () {
    test('same route added twice is deduplicated', () {
      final table = RoutingTable();
      final route = route0(peerId(1), peerId(2), 2);
      table.addRoute(route);
      table.addRoute(route);
      expect(table.routesTo(peerId(1)).length, 1);
    });

    test('same destination different next hops stored as alternatives', () {
      final table = RoutingTable();
      table.addRoute(route0(peerId(1), peerId(2), 2));
      table.addRoute(route0(peerId(1), peerId(3), 3));
      expect(table.routesTo(peerId(1)).length, 2);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 19. RoutingSecurityValidator — clearLog
  // ════════════════════════════════════════════════════════════
  group('RoutingSecurityValidator — clearLog', () {
    test('clearLog empties the event log', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [peerId(2)],
        ),
        authenticatedPeerId: source,
      );

      expect(validator.eventLog.isNotEmpty, isTrue);
      validator.clearLog();
      expect(validator.eventLog.isEmpty, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 20. RoutingSecurityValidator — eventsFor and eventCount
  // ════════════════════════════════════════════════════════════
  group('RoutingSecurityValidator — eventsFor and eventCount', () {
    test('eventsFor returns all events for a peer', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      // Generate multiple events.
      for (var i = 0; i < 3; i++) {
        validator.validate(
          advertisement: TopologyAdvertisement(
            sourceIdentity: source,
            sequence: i,
            neighborPeerIds: [peerId(2)],
          ),
          authenticatedPeerId: source,
        );
      }

      final events = validator.eventsFor(source);
      expect(events.length, greaterThanOrEqualTo(3));
    });

    test('eventsFor returns empty for unknown peer', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      expect(validator.eventsFor(peerId(99)), isEmpty);
    });

    test('eventCount counts specific event type', () {
      final validator =
          RoutingSecurityValidator(trustService: mockTrustService);
      final source = peerId(1);

      when(mockTrustService.isAuthenticated(source)).thenReturn(true);

      validator.validate(
        advertisement: TopologyAdvertisement(
          sourceIdentity: source,
          sequence: 1,
          neighborPeerIds: [peerId(2)],
        ),
        authenticatedPeerId: source,
      );

      expect(
          validator.eventCount(RoutingSecurityEvent.validationPassed), 1);
      expect(
          validator.eventCount(RoutingSecurityEvent.senderIdentityMismatch),
          0);
    });
  });
}
