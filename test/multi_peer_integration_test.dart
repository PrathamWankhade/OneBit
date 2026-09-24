import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:onebit/features/trust/trust_state.dart';

import 'multi_peer_integration_test.mocks.dart';

@GenerateMocks([BleService, IdentityAssociationResolver, PeerRegistryService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const deviceA = 'AA:BB:CC:DD:01';
  const deviceB = 'AA:BB:CC:DD:02';
  const deviceC = 'AA:BB:CC:DD:03';

  PeerInfo peerInfo(String id, String name) {
    return PeerInfo(
      id: id.hashCode,
      identityId: id,
      displayName: name,
      createdAt: DateTime(2025),
    );
  }

  /// Helper: fully verify + authenticate + trust a peer.
  void fullyTrust(TrustService svc, String id) {
    svc.verifyIdentity(
      peerIdentityId: id,
      at: DateTime(2025),
      publicKeyHex: id,
      method: VerificationMethod.qrScan,
    );
    svc.markAuthenticated(peerIdentityId: id);
    svc.establishTrust(peerIdentityId: id, at: DateTime(2025));
  }

  group('I7.12 Multi-Peer Integration — Peer Lifecycle', () {
    late MockBleService bleService;
    late MockIdentityAssociationResolver resolver;
    late MockPeerRegistryService registry;
    late PeerConnectionManager connectionManager;
    late TrustService trustService;

    setUp(() {
      bleService = MockBleService();
      resolver = MockIdentityAssociationResolver();
      registry = MockPeerRegistryService();

      when(bleService.current).thenReturn(const BleState());
      when(bleService.stateStream).thenAnswer((_) => const Stream.empty());
      when(resolver.deviceToPeerId).thenReturn({});
      when(resolver.resolveDevice(any)).thenReturn(null);
      when(resolver.removeAssociation(any)).thenReturn(false);

      connectionManager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );
      trustService = TrustService();
    });

    tearDown(() {
      connectionManager.dispose();
      trustService.dispose();
    });

    test('three peers coexist with independent states', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
        deviceC: peerC,
      });

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceB)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceB, state: BleConnectionState.connected,
        ),
      );

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);

      expect(connectionManager.isPeerConnected(peerA), true);
      expect(connectionManager.isPeerConnected(peerB), true);
      expect(connectionManager.lifecycleStateFor(peerC), PeerLifecycleState.disconnected);
      expect(connectionManager.connectedPeerCount, 2);

      when(bleService.disconnect(deviceB)).thenAnswer((_) async {});
      await connectionManager.disconnectFromPeer(peerB);

      expect(connectionManager.isPeerConnected(peerA), true);
      expect(connectionManager.isPeerConnected(peerB), false);
      expect(connectionManager.connectedPeerCount, 1);
    });

    test('trust states are independent across peers', () {
      // Fully trust A (verify + authenticate + trust).
      fullyTrust(trustService, peerA);

      // Only verify B (no trust).
      trustService.verifyIdentity(
        peerIdentityId: peerB,
        at: DateTime(2025),
        publicKeyHex: peerB,
        method: VerificationMethod.fingerprintComparison,
      );

      // Verify C, then revoke it.
      trustService.verifyIdentity(
        peerIdentityId: peerC,
        at: DateTime(2025),
        publicKeyHex: peerC,
        method: VerificationMethod.fingerprintComparison,
      );
      trustService.revoke(
        peerIdentityId: peerC,
        at: DateTime(2025),
      );

      // A is trusted.
      expect(trustService.isTrusted(peerA), true);
      expect(trustService.getTrust(peerA).state, TrustState.trusted);

      // B is verified only.
      expect(trustService.isTrusted(peerB), false);
      expect(trustService.getTrust(peerB).state, TrustState.verified);

      // C is revoked.
      expect(trustService.isTrusted(peerC), false);
      expect(trustService.getTrust(peerC).isRevoked, true);

      // Revoke A — B and C unchanged.
      trustService.revoke(peerIdentityId: peerA, at: DateTime(2025));
      expect(trustService.getTrust(peerA).isRevoked, true);
      expect(trustService.getTrust(peerB).state, TrustState.verified);
      expect(trustService.getTrust(peerC).isRevoked, true);
    });

    test('verification state is independent per peer', () {
      trustService.verifyIdentity(
        peerIdentityId: peerA,
        at: DateTime(2025),
        publicKeyHex: peerA,
        method: VerificationMethod.qrScan,
      );

      expect(trustService.isVerified(peerA), true);
      expect(trustService.getVerification(peerA).isVerified, true);
      expect(trustService.getVerification(peerA).method, VerificationMethod.qrScan);

      expect(trustService.isVerified(peerB), false);
    });

    test('disconnecting one peer does not affect others', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
        deviceC: peerC,
      });

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceB)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceB, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceC)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceC, state: BleConnectionState.connected,
        ),
      );

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      await connectionManager.connectToPeer(peerC);
      expect(connectionManager.connectedPeerCount, 3);

      when(bleService.disconnect(deviceB)).thenAnswer((_) async {});
      await connectionManager.disconnectFromPeer(peerB);

      expect(connectionManager.isPeerConnected(peerA), true);
      expect(connectionManager.isPeerConnected(peerB), false);
      expect(connectionManager.isPeerConnected(peerC), true);
      expect(connectionManager.connectedPeerCount, 2);
    });

    test('Bluetooth OFF clears all connections, ON allows rediscovery', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
      });

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceB)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceB, state: BleConnectionState.connected,
        ),
      );

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      expect(connectionManager.connectedPeerCount, 2);

      when(bleService.disconnect(deviceA)).thenAnswer((_) async {});
      when(bleService.disconnect(deviceB)).thenAnswer((_) async {});
      await connectionManager.disconnectFromPeer(peerA);
      await connectionManager.disconnectFromPeer(peerB);

      expect(connectionManager.connectedPeerCount, 0);

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceB)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceB, state: BleConnectionState.connected,
        ),
      );

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      expect(connectionManager.connectedPeerCount, 2);
    });

    test('rapid connect/disconnect cycles do not leak resources', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
      });

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.disconnect(deviceA)).thenAnswer((_) async {});

      for (var i = 0; i < 20; i++) {
        await connectionManager.connectToPeer(peerA);
        await connectionManager.disconnectFromPeer(peerA);
      }

      expect(connectionManager.connectedPeerCount, 0);
      expect(connectionManager.hasActiveConnections, false);
    });
  });

  group('I7.12 Multi-Peer Integration — Trust Revocation Isolation', () {
    late TrustService trustService;

    setUp(() {
      trustService = TrustService();
    });

    tearDown(() {
      trustService.dispose();
    });

    test('revoke(A) does not affect B or C', () {
      // Fully trust A.
      fullyTrust(trustService, peerA);

      // Verify B only.
      trustService.verifyIdentity(
        peerIdentityId: peerB,
        at: DateTime(2025),
        publicKeyHex: peerB,
        method: VerificationMethod.fingerprintComparison,
      );

      // Verify C, then revoke it.
      trustService.verifyIdentity(
        peerIdentityId: peerC,
        at: DateTime(2025),
        publicKeyHex: peerC,
        method: VerificationMethod.fingerprintComparison,
      );
      trustService.revoke(
        peerIdentityId: peerC,
        at: DateTime(2025),
      );

      expect(trustService.isTrusted(peerA), true);
      expect(trustService.getTrust(peerB).state, TrustState.verified);
      expect(trustService.getTrust(peerC).isRevoked, true);

      // Revoke A.
      trustService.revoke(peerIdentityId: peerA, at: DateTime(2025));

      expect(trustService.getTrust(peerA).isRevoked, true);
      expect(trustService.getTrust(peerB).state, TrustState.verified);
      expect(trustService.getTrust(peerC).isRevoked, true);
    });

    test('connected != trusted, authenticated != trusted', () {
      // Verify identity and mark authenticated — but NOT trusted yet.
      trustService.verifyIdentity(
        peerIdentityId: peerA,
        at: DateTime(2025),
        publicKeyHex: peerA,
        method: VerificationMethod.qrScan,
      );
      trustService.markAuthenticated(peerIdentityId: peerA);

      expect(trustService.isAuthenticated(peerA), true);
      expect(trustService.isVerified(peerA), true);
      expect(trustService.isTrusted(peerA), false);

      // Now establish trust.
      trustService.establishTrust(
        peerIdentityId: peerA,
        at: DateTime(2025),
      );
      expect(trustService.isTrusted(peerA), true);
    });
  });

  group('I7.12 Multi-Peer Integration — Peer Registry', () {
    late MockPeerRegistryService registry;

    setUp(() {
      registry = MockPeerRegistryService();
    });

    test('registry stores independent peer entries', () {
      when(registry.peerStream).thenAnswer((_) => const Stream.empty());

      final peers = <PeerEntry>[
        PeerEntry(
          identityId: peerA,
          peer: peerInfo(peerA, 'Peer A'),
          trustState: TrustState.trusted,
          isVerified: true,
          isAuthenticated: true,
          lifecycleState: PeerLifecycleState.connected,
          connectionState: BleConnectionState.connected,
          bleDeviceId: deviceA,
        ),
        PeerEntry(
          identityId: peerB,
          peer: peerInfo(peerB, 'Peer B'),
          trustState: TrustState.verified,
          isVerified: true,
          isAuthenticated: false,
          lifecycleState: PeerLifecycleState.disconnected,
          connectionState: BleConnectionState.disconnected,
        ),
        PeerEntry(
          identityId: peerC,
          peer: peerInfo(peerC, 'Peer C'),
          trustState: TrustState.revoked,
          isVerified: false,
          isAuthenticated: false,
          lifecycleState: PeerLifecycleState.disconnected,
          connectionState: BleConnectionState.disconnected,
        ),
      ];

      expect(peers[0].trustState, TrustState.trusted);
      expect(peers[0].lifecycleState, PeerLifecycleState.connected);
      expect(peers[0].bleDeviceId, deviceA);

      expect(peers[1].trustState, TrustState.verified);
      expect(peers[1].lifecycleState, PeerLifecycleState.disconnected);
      expect(peers[1].bleDeviceId, isNull);

      expect(peers[2].trustState, TrustState.revoked);
      expect(peers[2].lifecycleState, PeerLifecycleState.disconnected);
    });
  });

  group('I7.12 Multi-Peer Integration — Identity Consistency', () {
    late TrustService trustService;

    setUp(() {
      trustService = TrustService();
    });

    tearDown(() {
      trustService.dispose();
    });

    test('peer identity is consistent across trust and verification dimensions', () {
      const identityId = peerA;

      trustService.verifyIdentity(
        peerIdentityId: identityId,
        at: DateTime(2025),
        publicKeyHex: identityId,
        method: VerificationMethod.qrScan,
      );

      final trust = trustService.getTrust(identityId);
      expect(trust.peerIdentityId, identityId);

      final verification = trustService.getVerification(identityId);
      expect(verification.peerIdentityId, identityId);
    });

    test('identity change does not transfer trust', () {
      fullyTrust(trustService, peerA);

      expect(trustService.isTrusted(peerA), true);
      expect(trustService.isTrusted(peerB), false);
      expect(trustService.getTrust(peerB).state, TrustState.unknown);
    });
  });

  group('I7.12 Multi-Peer Integration — Stress Testing', () {
    late MockBleService bleService;
    late MockIdentityAssociationResolver resolver;
    late MockPeerRegistryService registry;
    late PeerConnectionManager connectionManager;

    setUp(() {
      bleService = MockBleService();
      resolver = MockIdentityAssociationResolver();
      registry = MockPeerRegistryService();

      when(bleService.current).thenReturn(const BleState());
      when(bleService.stateStream).thenAnswer((_) => const Stream.empty());
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
        deviceC: peerC,
      });
      when(resolver.resolveDevice(any)).thenReturn(null);
      when(resolver.removeAssociation(any)).thenReturn(false);

      connectionManager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );
    });

    tearDown(() {
      connectionManager.dispose();
    });

    test('repeated multi-peer connect/disconnect cycles', () async {
      when(bleService.connect(any)).thenAnswer(
        (invocation) async => BleConnectionInfo(
          deviceId: invocation.positionalArguments[0] as String,
          state: BleConnectionState.connected,
        ),
      );
      when(bleService.disconnect(any)).thenAnswer((_) async {});

      for (var i = 0; i < 10; i++) {
        await connectionManager.connectToPeer(peerA);
        await connectionManager.connectToPeer(peerB);
        await connectionManager.connectToPeer(peerC);

        await connectionManager.disconnectFromPeer(i.isEven ? peerA : peerB);
        await connectionManager.disconnectFromPeer(peerC);
        await connectionManager.disconnectFromPeer(i.isEven ? peerB : peerA);
      }

      expect(connectionManager.connectedPeerCount, 0);
      expect(connectionManager.hasActiveConnections, false);
    });

    test('concurrent connect operations on different peers', () async {
      when(bleService.connect(any)).thenAnswer(
        (invocation) async => BleConnectionInfo(
          deviceId: invocation.positionalArguments[0] as String,
          state: BleConnectionState.connected,
        ),
      );

      await Future.wait([
        connectionManager.connectToPeer(peerA),
        connectionManager.connectToPeer(peerB),
        connectionManager.connectToPeer(peerC),
      ]);

      expect(connectionManager.connectedPeerCount, 3);
    });

    test('connect A, disconnect B, reconnect B, verify isolation', () async {
      when(bleService.connect(any)).thenAnswer(
        (invocation) async => BleConnectionInfo(
          deviceId: invocation.positionalArguments[0] as String,
          state: BleConnectionState.connected,
        ),
      );
      when(bleService.disconnect(any)).thenAnswer((_) async {});

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      expect(connectionManager.connectedPeerCount, 2);

      await connectionManager.disconnectFromPeer(peerB);
      expect(connectionManager.isPeerConnected(peerA), true);
      expect(connectionManager.isPeerConnected(peerB), false);

      await connectionManager.connectToPeer(peerB);
      expect(connectionManager.connectedPeerCount, 2);
      expect(connectionManager.isPeerConnected(peerA), true);
      expect(connectionManager.isPeerConnected(peerB), true);
    });
  });

  group('I7.12 Multi-Peer Integration — Cleanup & Isolation', () {
    late MockBleService bleService;
    late MockIdentityAssociationResolver resolver;
    late MockPeerRegistryService registry;
    late PeerConnectionManager connectionManager;

    setUp(() {
      bleService = MockBleService();
      resolver = MockIdentityAssociationResolver();
      registry = MockPeerRegistryService();

      when(bleService.current).thenReturn(const BleState());
      when(bleService.stateStream).thenAnswer((_) => const Stream.empty());
      when(resolver.deviceToPeerId).thenReturn({});
      when(resolver.resolveDevice(any)).thenReturn(null);
      when(resolver.removeAssociation(any)).thenReturn(false);

      connectionManager = PeerConnectionManager(
        bleService: bleService,
        resolver: resolver,
        registry: registry,
      );
    });

    tearDown(() {
      connectionManager.dispose();
    });

    test('dispose cleans up all internal state', () {
      connectionManager.dispose();

      expect(connectionManager.connectedPeerCount, 0);
      expect(connectionManager.trackedPeerCount, 0);
      expect(connectionManager.hasActiveConnections, false);
    });

    test('disconnectAll disconnects all peers independently', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
        deviceC: peerC,
      });

      when(bleService.connect(any)).thenAnswer(
        (invocation) async => BleConnectionInfo(
          deviceId: invocation.positionalArguments[0] as String,
          state: BleConnectionState.connected,
        ),
      );
      when(bleService.disconnect(any)).thenAnswer((_) async {});

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      await connectionManager.connectToPeer(peerC);
      expect(connectionManager.connectedPeerCount, 3);

      await connectionManager.disconnectAll();
      expect(connectionManager.connectedPeerCount, 0);
    });

    test('lifecycle states persist during connection, clear on disconnect', () async {
      when(resolver.deviceToPeerId).thenReturn({
        deviceA: peerA,
        deviceB: peerB,
      });

      when(bleService.connect(deviceA)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceA, state: BleConnectionState.connected,
        ),
      );
      when(bleService.connect(deviceB)).thenAnswer(
        (_) async => const BleConnectionInfo(
          deviceId: deviceB, state: BleConnectionState.connected,
        ),
      );

      await connectionManager.connectToPeer(peerA);
      await connectionManager.connectToPeer(peerB);
      expect(connectionManager.lifecycleStateFor(peerA), PeerLifecycleState.connected);
      expect(connectionManager.lifecycleStateFor(peerB), PeerLifecycleState.connected);

      when(bleService.disconnect(deviceA)).thenAnswer((_) async {});
      when(bleService.disconnect(deviceB)).thenAnswer((_) async {});
      await connectionManager.disconnectFromPeer(peerA);
      await connectionManager.disconnectFromPeer(peerB);

      // After disconnect, lifecycle returns default (disconnected).
      expect(connectionManager.lifecycleStateFor(peerA), PeerLifecycleState.disconnected);
      expect(connectionManager.lifecycleStateFor(peerB), PeerLifecycleState.disconnected);
      expect(connectionManager.connectedPeerCount, 0);
    });
  });
}
