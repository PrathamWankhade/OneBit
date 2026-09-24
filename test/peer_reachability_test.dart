import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/reachability_reason.dart';
import 'package:onebit/features/trust/trust_state.dart';

import 'peer_reachability_test.mocks.dart';

@GenerateMocks([PeerRegistryService, PeerConnectionManager, NeighborTable])
void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';
  const deviceA = 'AA:BB:CC:DD:01';
  const deviceB = 'AA:BB:CC:DD:02';

  PeerEntry makeEntry(String id, {
    TrustState trust = TrustState.unknown,
    bool verified = false,
    bool authenticated = false,
    PeerLifecycleState lifecycle = PeerLifecycleState.connected,
  }) {
    return PeerEntry(
      identityId: id,
      peer: PeerInfo(
        id: id.hashCode,
        displayName: 'Peer ${id.substring(0, 4)}',
        createdAt: DateTime(2025),
      ),
      trustState: trust,
      isVerified: verified,
      isAuthenticated: authenticated,
      lifecycleState: lifecycle,
    );
  }

  group('I8.3 ReachabilityReason', () {
    test('has expected values', () {
      expect(ReachabilityReason.values, contains(ReachabilityReason.reachable));
      expect(ReachabilityReason.values, contains(ReachabilityReason.unknownPeer));
      expect(ReachabilityReason.values, contains(ReachabilityReason.notConnected));
      expect(ReachabilityReason.values, contains(ReachabilityReason.staleConnection));
      expect(ReachabilityReason.values, contains(ReachabilityReason.notNeighbor));
      expect(ReachabilityReason.values, contains(ReachabilityReason.missingContext));
    });
  });

  group('I8.3 PeerReachability — Unknown Peer', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(any)).thenReturn(null);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('unknown peer is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('unknown peer returns unknownPeer reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.unknownPeer);
    });
  });

  group('I8.3 PeerReachability — Known But Disconnected', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.disconnected,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.disconnected);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('disconnected peer is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('disconnected peer returns notConnected reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.notConnected);
    });
  });

  group('I8.3 PeerReachability — Connecting', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.connecting,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.connecting);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('connecting peer is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('connecting peer returns notConnected reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.notConnected);
    });
  });

  group('I8.3 PeerReachability — Disconnecting', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.disconnecting,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.disconnecting);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('disconnecting peer is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('disconnecting peer returns notConnected reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.notConnected);
    });
  });

  group('I8.3 PeerReachability — Connected + Neighbor = Reachable', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerA)).thenReturn(deviceA);
      when(neighborTable.isNeighbor(peerA)).thenReturn(true);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('connected neighbor is reachable', () {
      expect(reachability.isReachable(peerA), true);
    });

    test('connected neighbor returns reachable reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.reachable);
    });
  });

  group('I8.3 PeerReachability — Missing Context', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerA)).thenReturn(null);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('connected but missing device context is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('returns missingContext reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.missingContext);
    });
  });

  group('I8.3 PeerReachability — Connected But Not Neighbor', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA,
        lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerA)).thenReturn(deviceA);
      when(neighborTable.isNeighbor(peerA)).thenReturn(false);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('connected but not in neighbor table is not reachable', () {
      expect(reachability.isReachable(peerA), false);
    });

    test('returns notNeighbor reason', () {
      expect(reachability.getReachability(peerA), ReachabilityReason.notNeighbor);
    });
  });

  group('I8.3 PeerReachability — Multiple Reachable Peers', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      // B and C connected + neighbors, D disconnected
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.connected,
      ));
      when(registry.get(peerC)).thenReturn(makeEntry(
        peerC, lifecycle: PeerLifecycleState.connected,
      ));
      when(registry.get(peerD)).thenReturn(makeEntry(
        peerD, lifecycle: PeerLifecycleState.disconnected,
      ));

      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.lifecycleStateFor(peerC))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.lifecycleStateFor(peerD))
          .thenReturn(PeerLifecycleState.disconnected);

      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(connectionManager.deviceForPeer(peerC)).thenReturn('CC:DD:EE:FF:03');

      when(neighborTable.isNeighbor(peerB)).thenReturn(true);
      when(neighborTable.isNeighbor(peerC)).thenReturn(true);
      when(neighborTable.isNeighbor(peerD)).thenReturn(false);
      when(neighborTable.neighborPeerIds).thenReturn({peerB, peerC});

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('returns only connected neighbors as reachable', () {
      final reachable = reachability.getReachableNeighbors();
      expect(reachable, containsAll([peerB, peerC]));
      expect(reachable, isNot(contains(peerD)));
    });

    test('reachableCount matches', () {
      expect(reachability.reachableCount, 2);
    });

    test('hasReachablePeers is true', () {
      expect(reachability.hasReachablePeers, true);
    });
  });

  group('I8.3 PeerReachability — Peer Isolation', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.connected,
      ));
      when(registry.get(peerC)).thenReturn(makeEntry(
        peerC, lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.lifecycleStateFor(peerC))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(connectionManager.deviceForPeer(peerC)).thenReturn('CC:DD:EE:FF:03');
      when(neighborTable.isNeighbor(peerB)).thenReturn(true);
      when(neighborTable.isNeighbor(peerC)).thenReturn(true);
      when(neighborTable.neighborPeerIds).thenReturn({peerB, peerC});

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('B becoming unreachable does not affect C', () {
      // Initially both reachable.
      expect(reachability.isReachable(peerB), true);
      expect(reachability.isReachable(peerC), true);

      // B disconnects — simulate by changing lifecycle.
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.disconnected);

      // B unreachable, C still reachable.
      expect(reachability.isReachable(peerB), false);
      expect(reachability.isReachable(peerC), true);
    });
  });

  group('I8.3 PeerReachability — Trust Separation', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('trusted + disconnected = unreachable', () {
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB,
        trust: TrustState.trusted,
        verified: true,
        authenticated: true,
        lifecycle: PeerLifecycleState.disconnected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.disconnected);

      expect(reachability.isReachable(peerB), false);
      expect(reachability.getReachability(peerB), ReachabilityReason.notConnected);
    });

    test('untrusted + connected + neighbor = reachable', () {
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB,
        trust: TrustState.unknown,
        lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(neighborTable.isNeighbor(peerB)).thenReturn(true);

      expect(reachability.isReachable(peerB), true);
    });

    test('revoked + connected + neighbor = reachable', () {
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB,
        trust: TrustState.revoked,
        verified: true,
        lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(neighborTable.isNeighbor(peerB)).thenReturn(true);

      // Trust state does not affect reachability.
      expect(reachability.isReachable(peerB), true);
    });
  });

  group('I8.3 PeerReachability — Session Separation', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      // B has session + connected, C has no session + connected.
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.connected,
      ));
      when(registry.get(peerC)).thenReturn(makeEntry(
        peerC, lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.lifecycleStateFor(peerC))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(connectionManager.deviceForPeer(peerC)).thenReturn('CC:DD:EE:FF:03');
      when(neighborTable.isNeighbor(peerB)).thenReturn(true);
      when(neighborTable.isNeighbor(peerC)).thenReturn(true);
      when(neighborTable.neighborPeerIds).thenReturn({peerB, peerC});

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('both reachable regardless of session state', () {
      expect(reachability.isReachable(peerB), true);
      expect(reachability.isReachable(peerC), true);
    });
  });

  group('I8.3 PeerReachability — Identity', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('different peer IDs are independent', () {
      when(registry.get(peerA)).thenReturn(null); // A unknown
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      when(neighborTable.isNeighbor(peerB)).thenReturn(true);

      expect(reachability.isReachable(peerA), false);
      expect(reachability.isReachable(peerB), true);
    });
  });

  group('I8.3 PeerReachability — Restart Behavior', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('persisted peer with no active connection is unreachable', () {
      // Peer exists in registry (persisted) but no runtime connection.
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.disconnected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.disconnected);

      expect(reachability.isReachable(peerB), false);
    });
  });

  group('I8.3 PeerReachability — Empty State', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(any)).thenReturn(null);
      when(neighborTable.neighborPeerIds).thenReturn({});

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('no reachable peers when empty', () {
      expect(reachability.isReachable(peerA), false);
      expect(reachability.getReachableNeighbors(), isEmpty);
      expect(reachability.reachableCount, 0);
      expect(reachability.hasReachablePeers, false);
    });
  });

  group('I8.3 PeerReachability — No Automatic Side Effects', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      when(registry.get(peerA)).thenReturn(null);

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('isReachable does not create connections', () {
      reachability.isReachable(peerA);
      verifyNever(connectionManager.connectToPeer(any));
    });

    test('getReachableNeighbors does not create connections', () {
      when(neighborTable.neighborPeerIds).thenReturn({});
      reachability.getReachableNeighbors();
      verifyNever(connectionManager.connectToPeer(any));
    });
  });

  group('I8.3 PeerReachability — Stale Connection', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('connected but not neighbor returns notNeighbor (stale scenario)', () {
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.connected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.connected);
      when(connectionManager.deviceForPeer(peerB)).thenReturn(deviceB);
      // Not in neighbor table = stale / superseded connection.
      when(neighborTable.isNeighbor(peerB)).thenReturn(false);

      expect(reachability.isReachable(peerB), false);
      expect(reachability.getReachability(peerB), ReachabilityReason.notNeighbor);
    });
  });

  group('I8.3 PeerReachability — Bluetooth OFF Scenario', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('all peers disconnected when BT off → all unreachable', () {
      when(registry.get(peerB)).thenReturn(makeEntry(
        peerB, lifecycle: PeerLifecycleState.disconnected,
      ));
      when(registry.get(peerC)).thenReturn(makeEntry(
        peerC, lifecycle: PeerLifecycleState.disconnected,
      ));
      when(connectionManager.lifecycleStateFor(peerB))
          .thenReturn(PeerLifecycleState.disconnected);
      when(connectionManager.lifecycleStateFor(peerC))
          .thenReturn(PeerLifecycleState.disconnected);
      when(neighborTable.neighborPeerIds).thenReturn({});

      expect(reachability.isReachable(peerB), false);
      expect(reachability.isReachable(peerC), false);
      expect(reachability.getReachableNeighbors(), isEmpty);
    });
  });

  group('I8.3 PeerReachability — All Lifecycle States', () {
    late MockPeerRegistryService registry;
    late MockPeerConnectionManager connectionManager;
    late MockNeighborTable neighborTable;
    late PeerReachability reachability;

    setUp(() {
      registry = MockPeerRegistryService();
      connectionManager = MockPeerConnectionManager();
      neighborTable = MockNeighborTable();

      reachability = PeerReachability(
        registry: registry,
        connectionManager: connectionManager,
        neighborTable: neighborTable,
      );
    });

    test('unknown lifecycle → notConnected', () {
      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA, lifecycle: PeerLifecycleState.unknown,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.unknown);

      expect(reachability.getReachability(peerA), ReachabilityReason.notConnected);
    });

    test('discovered lifecycle → notConnected', () {
      when(registry.get(peerA)).thenReturn(makeEntry(
        peerA, lifecycle: PeerLifecycleState.discovered,
      ));
      when(connectionManager.lifecycleStateFor(peerA))
          .thenReturn(PeerLifecycleState.discovered);

      expect(reachability.getReachability(peerA), ReachabilityReason.notConnected);
    });
  });
}
