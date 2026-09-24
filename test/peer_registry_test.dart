import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_registry.dart';
import 'package:onebit/features/trust/trust_state.dart';

PeerInfo _peer({
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

void main() {
  group('PeerEntry', () {
    test('construction holds all fields', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        trustState: TrustState.trusted,
        isVerified: true,
        isAuthenticated: true,
      );

      expect(entry.identityId, 'aabb');
      expect(entry.trustState, TrustState.trusted);
      expect(entry.isVerified, isTrue);
      expect(entry.isAuthenticated, isTrue);
    });

    test('defaults are unknown', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(identityId: 'aabb', peer: peer);

      expect(entry.trustState, TrustState.unknown);
      expect(entry.isVerified, isFalse);
      expect(entry.isAuthenticated, isFalse);
    });

    test('copyWith preserves unspecified fields', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        trustState: TrustState.trusted,
        isVerified: true,
      );

      final updated = entry.copyWith(isAuthenticated: true);
      expect(updated.trustState, TrustState.trusted);
      expect(updated.isVerified, isTrue);
      expect(updated.isAuthenticated, isTrue);
    });

    test('equality based on identity and state', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final a = PeerEntry(identityId: 'aabb', peer: peer);
      final b = PeerEntry(identityId: 'aabb', peer: peer);
      final c = PeerEntry(
        identityId: 'aabb',
        peer: peer,
        trustState: TrustState.trusted,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString shows truncated identity', () {
      final peer = _peer(id: 1, identityId: 'aabb');
      final entry = PeerEntry(identityId: 'aabb', peer: peer);
      expect(entry.toString(), contains('aabb'));
    });
  });

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

    test('get returns peer by identity ID', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa', displayName: 'Alice'),
      ]);

      final entry = registry.get('aaaa');
      expect(entry, isNotNull);
      expect(entry!.identityId, 'aaaa');
      expect(entry.peer.displayName, 'Alice');
    });

    test('get returns null for unknown identity', () {
      expect(registry.get('zzzz'), isNull);
    });

    test('contains returns true for registered peer', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);

      expect(registry.contains('aaaa'), isTrue);
      expect(registry.contains('zzzz'), isFalse);
    });

    test('getAll returns all registered peers', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bbbb', displayName: 'Bob'),
      ]);

      final all = registry.getAll();
      expect(all, hasLength(2));
    });

    test('upsert adds new peer', () {
      final peer = _peer(id: 1, identityId: 'aaaa', displayName: 'Alice');
      registry.upsert(PeerEntry(identityId: 'aaaa', peer: peer));

      expect(registry.count, 1);
      expect(registry.get('aaaa')!.peer.displayName, 'Alice');
    });

    test('upsert updates existing peer', () {
      final peer1 = _peer(id: 1, identityId: 'aaaa', displayName: 'Alice');
      final peer2 = _peer(id: 1, identityId: 'aaaa', displayName: 'Alice Updated');

      registry.upsert(PeerEntry(identityId: 'aaaa', peer: peer1));
      registry.upsert(PeerEntry(identityId: 'aaaa', peer: peer2));

      expect(registry.count, 1);
      expect(registry.get('aaaa')!.peer.displayName, 'Alice Updated');
    });

    test('upsert preserves trust fields on update', () {
      final peer1 = _peer(id: 1, identityId: 'aaaa');
      registry.upsert(PeerEntry(
        identityId: 'aaaa',
        peer: peer1,
        trustState: TrustState.trusted,
        isVerified: true,
      ));

      final peer2 = _peer(id: 1, identityId: 'aaaa', displayName: 'Alice Updated');
      registry.upsert(PeerEntry(identityId: 'aaaa', peer: peer2));

      final entry = registry.get('aaaa')!;
      expect(entry.peer.displayName, 'Alice Updated');
      expect(entry.trustState, TrustState.trusted);
      expect(entry.isVerified, isTrue);
    });

    test('remove deletes peer from registry', () {
      registry.upsert(PeerEntry(
        identityId: 'aaaa',
        peer: _peer(id: 1, identityId: 'aaaa'),
      ));

      registry.remove('aaaa');

      expect(registry.count, 0);
      expect(registry.get('aaaa'), isNull);
    });

    test('remove ignores unknown identity', () {
      registry.upsert(PeerEntry(
        identityId: 'aaaa',
        peer: _peer(id: 1, identityId: 'aaaa'),
      ));

      registry.remove('zzzz');

      expect(registry.count, 1);
    });

    test('updateFromIdentities adds peers', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bbbb', displayName: 'Bob'),
      ]);

      expect(registry.count, 2);
      expect(registry.get('aaaa'), isNotNull);
      expect(registry.get('bbbb'), isNotNull);
    });

    test('updateFromIdentities updates existing peers', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa', displayName: 'Alice'),
      ]);

      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa', displayName: 'Alice Updated'),
      ]);

      expect(registry.count, 1);
      expect(registry.get('aaaa')!.peer.displayName, 'Alice Updated');
    });

    test('updateFromIdentities skips peers with no identity', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: '', displayName: 'No ID'),
      ]);

      expect(registry.count, 0);
    });

    test('updateTrust updates trust state', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);

      registry.updateTrust(
        'aaaa',
        trustState: TrustState.trusted,
        isVerified: true,
        isAuthenticated: true,
      );

      final entry = registry.get('aaaa')!;
      expect(entry.trustState, TrustState.trusted);
      expect(entry.isVerified, isTrue);
      expect(entry.isAuthenticated, isTrue);
    });

    test('updateTrust ignores unknown identity', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);

      registry.updateTrust('zzzz', trustState: TrustState.trusted);

      expect(registry.get('aaaa')!.trustState, TrustState.unknown);
    });

    test('clear removes all peers', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
        _peer(id: 2, identityId: 'bbbb'),
        _peer(id: 3, identityId: 'cccc'),
      ]);

      registry.clear();

      expect(registry.count, 0);
    });

    test('peerStream emits on updates', () async {
      final events = <List<PeerEntry>>[];
      registry.peerStream.listen(events.add);

      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0], hasLength(1));
    });

    test('peerStream emits on upsert', () async {
      final events = <List<PeerEntry>>[];
      registry.peerStream.listen(events.add);

      registry.upsert(PeerEntry(
        identityId: 'aaaa',
        peer: _peer(id: 1, identityId: 'aaaa'),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].first.identityId, 'aaaa');
    });

    test('peerStream emits on remove', () async {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);

      final events = <List<PeerEntry>>[];
      registry.peerStream.listen(events.add);

      registry.remove('aaaa');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0], isEmpty);
    });

    test('peerStream emits on trust change', () async {
      final events = <List<PeerEntry>>[];
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'aaaa'),
      ]);
      registry.peerStream.listen(events.add);

      registry.updateTrust('aaaa', trustState: TrustState.trusted);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].first.trustState, TrustState.trusted);
    });
  });

  group('Multi-peer isolation', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('three peers with different trust states coexist', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
        _peer(id: 3, identityId: 'charlie', displayName: 'Charlie'),
      ]);

      registry.updateTrust('alice', trustState: TrustState.trusted);
      registry.updateTrust('bob', trustState: TrustState.verified);

      final alice = registry.get('alice')!;
      final bob = registry.get('bob')!;
      final charlie = registry.get('charlie')!;

      expect(alice.trustState, TrustState.trusted);
      expect(bob.trustState, TrustState.verified);
      expect(charlie.trustState, TrustState.unknown);
    });

    test('trust of A does not affect B', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
      ]);

      registry.updateTrust('alice', trustState: TrustState.trusted);

      final bob = registry.get('bob')!;
      expect(bob.trustState, TrustState.unknown);
    });

    test('revoke B while A remains trusted', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
      ]);

      registry.updateTrust('alice', trustState: TrustState.trusted);
      registry.updateTrust('bob', trustState: TrustState.trusted);

      registry.updateTrust('bob', trustState: TrustState.revoked);

      expect(registry.get('alice')!.trustState, TrustState.trusted);
      expect(registry.get('bob')!.trustState, TrustState.revoked);
    });

    test('remove only removes specified peer', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
      ]);

      registry.remove('alice');

      expect(registry.count, 1);
      expect(registry.get('alice'), isNull);
      expect(registry.get('bob'), isNotNull);
    });
  });

  group('Authentication isolation', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('authentication of A does not affect B', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
      ]);

      registry.updateTrust(
        'alice',
        trustState: TrustState.verified,
        isAuthenticated: true,
      );

      final alice = registry.get('alice')!;
      final bob = registry.get('bob')!;

      expect(alice.isAuthenticated, isTrue);
      expect(bob.isAuthenticated, isFalse);
    });

    test('verification of A does not affect B', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
      ]);

      registry.updateTrust(
        'alice',
        trustState: TrustState.verified,
        isVerified: true,
      );

      final alice = registry.get('alice')!;
      final bob = registry.get('bob')!;

      expect(alice.isVerified, isTrue);
      expect(bob.isVerified, isFalse);
    });
  });

  group('Peer lifecycle', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('full lifecycle: discovered → verified → trusted', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
      ]);

      // Initially unknown.
      var alice = registry.get('alice')!;
      expect(alice.trustState, TrustState.unknown);

      // Verify.
      registry.updateTrust(
        'alice',
        trustState: TrustState.verified,
        isVerified: true,
      );
      alice = registry.get('alice')!;
      expect(alice.trustState, TrustState.verified);

      // Trust.
      registry.updateTrust(
        'alice',
        trustState: TrustState.trusted,
        isVerified: true,
        isAuthenticated: true,
      );
      alice = registry.get('alice')!;
      expect(alice.trustState, TrustState.trusted);
    });

    test('peer remains after trust change', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
      ]);

      registry.updateTrust('alice', trustState: TrustState.trusted);
      registry.updateTrust('alice', trustState: TrustState.revoked);

      expect(registry.count, 1);
      expect(registry.get('alice')!.trustState, TrustState.revoked);
    });

    test('BLE address change does not create duplicate peer', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
      ]);

      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice (updated)'),
      ]);

      expect(registry.count, 1);
      expect(registry.get('alice')!.peer.displayName, 'Alice (updated)');
    });
  });

  group('No state leaks', () {
    late PeerRegistryService registry;

    setUp(() {
      registry = PeerRegistryService();
    });

    tearDown(() {
      registry.dispose();
    });

    test('trust state does not leak across peers', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
        _peer(id: 2, identityId: 'bob', displayName: 'Bob'),
        _peer(id: 3, identityId: 'charlie', displayName: 'Charlie'),
      ]);

      registry.updateTrust('alice', trustState: TrustState.trusted);
      registry.updateTrust('bob', trustState: TrustState.verified);
      registry.updateTrust('charlie', trustState: TrustState.revoked);

      expect(registry.get('alice')!.trustState, TrustState.trusted);
      expect(registry.get('bob')!.trustState, TrustState.verified);
      expect(registry.get('charlie')!.trustState, TrustState.revoked);
    });

    test('no secrets in peer entries', () {
      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice', displayName: 'Alice'),
      ]);

      final entry = registry.get('alice')!;
      final str = entry.toString();

      expect(str, isNot(contains('private')));
      expect(str, isNot(contains('seed')));
      expect(str, isNot(contains('secret')));
    });
  });

  group('Resource cleanup', () {
    test('dispose closes stream', () {
      final registry = PeerRegistryService();
      var emitted = false;
      registry.peerStream.listen((_) => emitted = true);

      registry.dispose();

      registry.updateFromIdentities([
        _peer(id: 1, identityId: 'alice'),
      ]);

      expect(emitted, isFalse);
    });

    test('multiple dispose calls are safe', () {
      final registry = PeerRegistryService();
      registry.dispose();
      registry.dispose(); // Should not throw.
    });
  });
}
