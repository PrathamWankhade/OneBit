import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/trust_state.dart';

// ── Constants ──────────────────────────────────────────────────

const _keyA = 'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
const _keyB = '1122334455667788112233445566778811223344556677881122334455667788';

// ── Helpers ────────────────────────────────────────────────────

PeerInfo _peerInfo({
  required int id,
  required String identityId,
  String displayName = 'Peer',
}) {
  return PeerInfo(
    id: id,
    identityId: identityId,
    displayName: displayName,
    createdAt: DateTime(2025),
  );
}

PeerEntry _peerEntry({
  required String identityId,
  String displayName = 'Peer',
  TrustState trustState = TrustState.unknown,
  bool isVerified = false,
  bool isAuthenticated = false,
  PeerLifecycleState lifecycleState = PeerLifecycleState.disconnected,
}) {
  return PeerEntry(
    identityId: identityId,
    peer: _peerInfo(id: 1, identityId: identityId, displayName: displayName),
    trustState: trustState,
    isVerified: isVerified,
    isAuthenticated: isAuthenticated,
    lifecycleState: lifecycleState,
  );
}

// ── PeerEntry Model Tests ──────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeerEntry', () {
    test('equality based on identityId and state fields', () {
      final a = _peerEntry(
        identityId: _keyA,
        trustState: TrustState.trusted,
        lifecycleState: PeerLifecycleState.connected,
      );
      final b = _peerEntry(
        identityId: _keyA,
        trustState: TrustState.trusted,
        lifecycleState: PeerLifecycleState.connected,
      );
      final c = _peerEntry(
        identityId: _keyA,
        trustState: TrustState.revoked,
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('isConnected returns true only when connected', () {
      final connected = _peerEntry(
        identityId: _keyA,
        lifecycleState: PeerLifecycleState.connected,
      );
      final disconnected = _peerEntry(
        identityId: _keyA,
        lifecycleState: PeerLifecycleState.disconnected,
      );

      expect(connected.isConnected, isTrue);
      expect(disconnected.isConnected, isFalse);
    });

    test('isConnecting returns true only when connecting', () {
      final connecting = _peerEntry(
        identityId: _keyA,
        lifecycleState: PeerLifecycleState.connecting,
      );
      final connected = _peerEntry(
        identityId: _keyA,
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(connecting.isConnecting, isTrue);
      expect(connected.isConnecting, isFalse);
    });
  });

  // ── PeerRegistryService ─────────────────────────────────────

  group('PeerRegistryService', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('starts empty', () {
      expect(registry.count, 0);
      expect(registry.getAll(), isEmpty);
    });

    test('upsert adds peer', () {
      final peer = _peerEntry(identityId: _keyA, displayName: 'Alice');
      registry.upsert(peer);

      expect(registry.count, 1);
      expect(registry.get(_keyA)?.peer.displayName, 'Alice');
    });

    test('upsert updates existing peer identity info', () {
      final peer1 = _peerEntry(identityId: _keyA, displayName: 'Alice');
      final peer2 = _peerEntry(identityId: _keyA, displayName: 'Alice Updated');
      registry.upsert(peer1);
      registry.upsert(peer2);

      expect(registry.count, 1);
      expect(registry.get(_keyA)?.peer.displayName, 'Alice Updated');
    });

    test('multiple peers coexist', () {
      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      registry.upsert(_peerEntry(identityId: _keyB, displayName: 'Bob'));

      expect(registry.count, 2);
      expect(registry.get(_keyA), isNotNull);
      expect(registry.get(_keyB), isNotNull);
    });

    test('remove deletes peer', () {
      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      registry.remove(_keyA);

      expect(registry.count, 0);
      expect(registry.get(_keyA), isNull);
    });

    test('clear removes all peers', () {
      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      registry.upsert(_peerEntry(identityId: _keyB, displayName: 'Bob'));
      registry.clear();

      expect(registry.count, 0);
    });

    test('peerStream emits on changes', () async {
      final events = <List<PeerEntry>>[];
      registry.peerStream.listen(events.add);

      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      await Future<void>.delayed(Duration.zero);

      registry.upsert(_peerEntry(identityId: _keyB, displayName: 'Bob'));
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0].length, 1);
      expect(events[1].length, 2);
    });

    test('updateLifecycle updates lifecycle state', () {
      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      registry.updateLifecycle(_keyA, lifecycleState: PeerLifecycleState.connected);

      final peer = registry.get(_keyA);
      expect(peer?.lifecycleState, PeerLifecycleState.connected);
    });

    test('updateTrust updates trust state', () {
      registry.upsert(_peerEntry(identityId: _keyA, displayName: 'Alice'));
      registry.updateTrust(
        _keyA,
        trustState: TrustState.trusted,
        isVerified: true,
      );

      final peer = registry.get(_keyA);
      expect(peer?.trustState, TrustState.trusted);
      expect(peer?.isVerified, isTrue);
    });
  });

  // ── TrustState Independence ──────────────────────────────────

  group('TrustState Independence', () {
    test('trust state is independent of connection state', () {
      final trusted = _peerEntry(
        identityId: _keyA,
        trustState: TrustState.trusted,
        lifecycleState: PeerLifecycleState.disconnected,
      );
      final untrusted = _peerEntry(
        identityId: _keyB,
        trustState: TrustState.unknown,
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(trusted.trustState, TrustState.trusted);
      expect(trusted.lifecycleState, PeerLifecycleState.disconnected);

      expect(untrusted.trustState, TrustState.unknown);
      expect(untrusted.lifecycleState, PeerLifecycleState.connected);
    });

    test('verification is independent of trust', () {
      final verified = _peerEntry(
        identityId: _keyA,
        trustState: TrustState.verified,
        isVerified: true,
      );
      final trusted = _peerEntry(
        identityId: _keyB,
        trustState: TrustState.trusted,
        isVerified: false,
      );

      expect(verified.isVerified, isTrue);
      expect(trusted.isVerified, isFalse);
    });
  });

  // ── Per-Peer Isolation ──────────────────────────────────────

  group('Per-Peer Isolation', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('changing one peer does not affect another', () {
      registry.upsert(_peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
        trustState: TrustState.unknown,
      ));
      registry.upsert(_peerEntry(
        identityId: _keyB,
        displayName: 'Bob',
        trustState: TrustState.unknown,
      ));

      // Update Alice to trusted
      registry.updateTrust(_keyA, trustState: TrustState.trusted);

      final alice = registry.get(_keyA);
      final bob = registry.get(_keyB);

      expect(alice?.trustState, TrustState.trusted);
      expect(bob?.trustState, TrustState.unknown);
    });

    test('connection changes are per-peer', () {
      registry.upsert(_peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
      ));
      registry.upsert(_peerEntry(
        identityId: _keyB,
        displayName: 'Bob',
      ));

      registry.updateLifecycle(_keyA, lifecycleState: PeerLifecycleState.connected);

      final alice = registry.get(_keyA);
      final bob = registry.get(_keyB);

      expect(alice?.lifecycleState, PeerLifecycleState.connected);
      expect(bob?.lifecycleState, PeerLifecycleState.disconnected);
    });

    test('stream updates per-peer independently', () async {
      final events = <List<PeerEntry>>[];
      registry.peerStream.listen(events.add);

      registry.upsert(_peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
        trustState: TrustState.unknown,
      ));
      registry.upsert(_peerEntry(
        identityId: _keyB,
        displayName: 'Bob',
        trustState: TrustState.unknown,
      ));
      await Future<void>.delayed(Duration.zero);

      // Only update Alice
      registry.updateTrust(_keyA, trustState: TrustState.trusted);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 3);

      final lastEvent = events.last;
      expect(lastEvent.length, 2);

      final alice = lastEvent.firstWhere((p) => p.identityId == _keyA);
      final bob = lastEvent.firstWhere((p) => p.identityId == _keyB);

      expect(alice.trustState, TrustState.trusted);
      expect(bob.trustState, TrustState.unknown);
    });
  });

  // ── Status Hierarchy Display ────────────────────────────────

  group('Status Hierarchy', () {
    test('connected + trusted peer shows both states independently', () {
      final peer = _peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
        trustState: TrustState.trusted,
        isVerified: true,
        lifecycleState: PeerLifecycleState.connected,
      );

      expect(peer.isConnected, isTrue);
      expect(peer.trustState, TrustState.trusted);
      expect(peer.isVerified, isTrue);
    });

    test('disconnected + revoked peer shows both states independently', () {
      final peer = _peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
        trustState: TrustState.revoked,
        lifecycleState: PeerLifecycleState.disconnected,
      );

      expect(peer.isConnected, isFalse);
      expect(peer.trustState, TrustState.revoked);
    });

    test('connecting + verified peer shows both states independently', () {
      final peer = _peerEntry(
        identityId: _keyA,
        displayName: 'Alice',
        trustState: TrustState.verified,
        isVerified: true,
        lifecycleState: PeerLifecycleState.connecting,
      );

      expect(peer.isConnecting, isTrue);
      expect(peer.trustState, TrustState.verified);
      expect(peer.isVerified, isTrue);
    });
  });
}
