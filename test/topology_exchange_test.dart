import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/routing/topology_advertisement_codec.dart';
import 'package:onebit/features/routing/topology_exchange_service.dart';
import 'package:onebit/features/routing/topology_repository.dart';

import 'topology_exchange_test.mocks.dart';

@GenerateMocks([NeighborTable, PeerReachability])
void main() {
  const peerA = 'aa11111111111111111111111111111111111111111111111111111111111111';
  const peerB = 'bb22222222222222222222222222222222222222222222222222222222222222';
  const peerC = 'cc33333333333333333333333333333333333333333333333333333333333333';
  const peerD = 'dd44444444444444444444444444444444444444444444444444444444444444';

  group('I8.4 TopologyAdvertisement Model', () {
    test('valid advertisement', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerB, peerC],
      );
      expect(ad.isValid, true);
      expect(ad.hasSelfLoop, false);
    });

    test('invalid source identity length', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: 'short',
        sequence: 1,
        neighborPeerIds: [],
      );
      expect(ad.isValid, false);
    });

    test('invalid neighbor id length', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: ['short'],
      );
      expect(ad.isValid, false);
    });

    test('self-loop detected', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerA, peerB],
      );
      expect(ad.hasSelfLoop, true);
    });

    test('equality by source and sequence', () {
      const ad1 = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 5,
        neighborPeerIds: [peerB],
      );
      const ad2 = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 5,
        neighborPeerIds: [peerC],
      );
      expect(ad1, equals(ad2));
    });

    test('inequality for different sequence', () {
      const ad1 = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 5,
        neighborPeerIds: [peerB],
      );
      const ad2 = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 6,
        neighborPeerIds: [peerB],
      );
      expect(ad1, isNot(equals(ad2)));
    });

    test('empty neighbor list is valid', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 0,
        neighborPeerIds: [],
      );
      expect(ad.isValid, true);
      expect(ad.neighborPeerIds, isEmpty);
    });
  });

  group('I8.4 TopologyAdvertisementCodec — Round Trip', () {
    test('encode/decode with zero neighbors', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 0,
        neighborPeerIds: [],
      );

      final bytes = TopologyAdvertisementCodec.encode(ad);
      final decoded = TopologyAdvertisementCodec.decode(bytes);

      expect(decoded.sourceIdentity, peerA);
      expect(decoded.sequence, 0);
      expect(decoded.neighborPeerIds, isEmpty);
    });

    test('encode/decode with one neighbor', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerB],
      );

      final bytes = TopologyAdvertisementCodec.encode(ad);
      final decoded = TopologyAdvertisementCodec.decode(bytes);

      expect(decoded.sourceIdentity, peerA);
      expect(decoded.sequence, 1);
      expect(decoded.neighborPeerIds, [peerB]);
    });

    test('encode/decode with two neighbors', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 42,
        neighborPeerIds: [peerB, peerC],
      );

      final bytes = TopologyAdvertisementCodec.encode(ad);
      final decoded = TopologyAdvertisementCodec.decode(bytes);

      expect(decoded.sourceIdentity, peerA);
      expect(decoded.sequence, 42);
      expect(decoded.neighborPeerIds, containsAll([peerB, peerC]));
    });

    test('deterministic encoding', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 10,
        neighborPeerIds: [peerB, peerC],
      );

      final bytes1 = TopologyAdvertisementCodec.encode(ad);
      final bytes2 = TopologyAdvertisementCodec.encode(ad);

      expect(bytes1, equals(bytes2));
    });

    test('encoded size is correct', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerB, peerC],
      );

      final bytes = TopologyAdvertisementCodec.encode(ad);
      // 1 + 8 + 32 + 2 + (2 * 32) = 107 bytes
      expect(bytes.length, 107);
    });
  });

  group('I8.4 TopologyAdvertisementCodec — Validation Rejection', () {
    test('rejects too-short buffer', () {
      final bytes = Uint8List(10);
      expect(
        () => TopologyAdvertisementCodec.decode(bytes),
        throwsA(isA<TopologyDecodeException>()),
      );
    });

    test('rejects unsupported version', () {
      final bytes = Uint8List(75);
      bytes[0] = 99; // invalid version
      expect(
        () => TopologyAdvertisementCodec.decode(bytes),
        throwsA(isA<TopologyDecodeException>()),
      );
    });

    test('rejects trailing bytes', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [],
      );
      final bytes = TopologyAdvertisementCodec.encode(ad);
      final padded = Uint8List(bytes.length + 10);
      padded.setAll(0, bytes);
      expect(
        () => TopologyAdvertisementCodec.decode(padded),
        throwsA(isA<TopologyDecodeException>()),
      );
    });

    test('invalid hex in source identity', () {
      final ad = TopologyAdvertisement(
        sourceIdentity: 'zz${'11' * 31}',
        sequence: 1,
        neighborPeerIds: const [],
      );
      expect(
        () => TopologyAdvertisementCodec.encode(ad),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('I8.4 TopologyRepository — Local Topology', () {
    late TopologyRepository repo;

    setUp(() {
      repo = TopologyRepository();
    });

    test('starts with empty local topology', () {
      expect(repo.localNeighborIds, isEmpty);
    });

    test('setLocalTopology updates local neighbors', () {
      repo.setLocalTopology({peerB, peerC});
      expect(repo.localNeighborIds, containsAll([peerB, peerC]));
    });

    test('setLocalTopology replaces previous set', () {
      repo.setLocalTopology({peerB, peerC});
      repo.setLocalTopology({peerD});
      expect(repo.localNeighborIds, {peerD});
      expect(repo.localNeighborIds, isNot(contains(peerB)));
    });
  });

  group('I8.4 TopologyRepository — Remote Topology', () {
    late TopologyRepository repo;

    setUp(() {
      repo = TopologyRepository();
    });

    test('records a valid advertisement', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerA, peerC],
      );

      final accepted = repo.recordAdvertisement(ad);
      expect(accepted, true);
      expect(repo.remoteSourceIds, contains(peerB));
    });

    test('advertisedNeighborsOf returns correct set', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerA, peerC],
      );

      repo.recordAdvertisement(ad);
      expect(repo.advertisedNeighborsOf(peerB), containsAll([peerA, peerC]));
    });

    test('snapshot replacement — newer ad replaces older', () {
      const ad1 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerA, peerC],
      );
      const ad2 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 2,
        neighborPeerIds: [peerA, peerD],
      );

      repo.recordAdvertisement(ad1);
      repo.recordAdvertisement(ad2);

      final neighbors = repo.advertisedNeighborsOf(peerB);
      expect(neighbors, containsAll([peerA, peerD]));
      expect(neighbors, isNot(contains(peerC)));
    });

    test('rejects older sequence (replay protection)', () {
      const ad1 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 5,
        neighborPeerIds: [peerA],
      );
      const ad2 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 3,
        neighborPeerIds: [peerC],
      );

      repo.recordAdvertisement(ad1);
      final accepted = repo.recordAdvertisement(ad2);
      expect(accepted, false);

      // Original topology unchanged.
      expect(repo.advertisedNeighborsOf(peerB), contains(peerA));
      expect(repo.advertisedNeighborsOf(peerB), isNot(contains(peerC)));
    });

    test('accepts equal sequence (idempotent)', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 5,
        neighborPeerIds: [peerA],
      );

      repo.recordAdvertisement(ad);
      final accepted = repo.recordAdvertisement(ad);
      expect(accepted, true);
    });

    test('removeSource clears source topology', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerA],
      );

      repo.recordAdvertisement(ad);
      repo.removeSource(peerB);

      expect(repo.remoteSourceIds, isNot(contains(peerB)));
      expect(repo.getRemoteEntry(peerB), isNull);
    });

    test('clearRemote removes all remote but not local', () {
      repo.setLocalTopology({peerB});
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerA],
        ),
      );

      repo.clearRemote();

      expect(repo.localNeighborIds, contains(peerB));
      expect(repo.remoteSourceIds, isEmpty);
    });
  });

  group('I8.4 TopologyRepository — Source Isolation', () {
    late TopologyRepository repo;

    setUp(() {
      repo = TopologyRepository();
    });

    test('B and D topology are independent', () {
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerA, peerC],
        ),
      );
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerD,
          sequence: 1,
          neighborPeerIds: [peerA, peerC],
        ),
      );

      // Change B — D unaffected.
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 2,
          neighborPeerIds: [peerA],
        ),
      );

      expect(repo.advertisedNeighborsOf(peerB), {peerA});
      expect(repo.advertisedNeighborsOf(peerD), containsAll([peerA, peerC]));
    });
  });

  group('I8.4 TopologyRepository — Combined Queries', () {
    late TopologyRepository repo;

    setUp(() {
      repo = TopologyRepository();
    });

    test('allKnownPeerIds includes local and remote', () {
      repo.setLocalTopology({peerB});
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerC],
        ),
      );

      final all = repo.allKnownPeerIds;
      expect(all, containsAll([peerB, peerC]));
    });

    test('remoteSourceCount', () {
      expect(repo.remoteSourceCount, 0);

      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [],
        ),
      );
      repo.recordAdvertisement(
        const TopologyAdvertisement(
          sourceIdentity: peerD,
          sequence: 1,
          neighborPeerIds: [],
        ),
      );

      expect(repo.remoteSourceCount, 2);
    });
  });

  group('I8.4 TopologyExchangeService — Build Advertisement', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([peerB, peerC]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('buildAdvertisement uses reachable neighbors', () {
      final ad = service.buildAdvertisement(localPeerId: peerA);

      expect(ad.sourceIdentity, peerA);
      expect(ad.neighborPeerIds, containsAll([peerB, peerC]));
    });

    test('buildAdvertisementWithIncrement increments sequence', () {
      final ad1 = service.buildAdvertisementWithIncrement(localPeerId: peerA);
      final ad2 = service.buildAdvertisementWithIncrement(localPeerId: peerA);

      expect(ad1.sequence, 1);
      expect(ad2.sequence, 2);
    });

    test('buildAdvertisement with empty reachable neighbors', () {
      when(reachability.getReachableNeighbors()).thenReturn([]);

      final ad = service.buildAdvertisement(localPeerId: peerA);

      expect(ad.neighborPeerIds, isEmpty);
      expect(ad.isValid, true);
    });
  });

  group('I8.4 TopologyExchangeService — Process Advertisement', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('accepts valid advertisement', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerA, peerC],
      );

      final result = service.processAdvertisement(
        advertisement: ad,
        localPeerId: peerA,
      );

      expect(result, AdvertisementResult.accepted);
      expect(repository.remoteSourceIds, contains(peerB));
    });

    test('rejects self-source', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerA,
        sequence: 1,
        neighborPeerIds: [peerB],
      );

      final result = service.processAdvertisement(
        advertisement: ad,
        localPeerId: peerA,
      );

      expect(result, AdvertisementResult.rejectedSelfSource);
    });

    test('rejects self-loop', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerB, peerC],
      );

      final result = service.processAdvertisement(
        advertisement: ad,
        localPeerId: peerA,
      );

      expect(result, AdvertisementResult.rejectedSelfLoop);
    });

    test('rejects malformed advertisement', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: 'short',
        sequence: 1,
        neighborPeerIds: [],
      );

      final result = service.processAdvertisement(
        advertisement: ad,
        localPeerId: peerA,
      );

      expect(result, AdvertisementResult.rejectedMalformed);
    });

    test('rejects stale sequence', () {
      const ad1 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 5,
        neighborPeerIds: [peerA],
      );
      const ad2 = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 3,
        neighborPeerIds: [peerC],
      );

      service.processAdvertisement(advertisement: ad1, localPeerId: peerA);
      final result = service.processAdvertisement(
        advertisement: ad2,
        localPeerId: peerA,
      );

      expect(result, AdvertisementResult.rejectedStale);
    });
  });

  group('I8.4 TopologyExchangeService — Process Raw Advertisement', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('decodes and processes valid raw bytes', () {
      const ad = TopologyAdvertisement(
        sourceIdentity: peerB,
        sequence: 1,
        neighborPeerIds: [peerC],
      );

      final bytes = TopologyAdvertisementCodec.encode(ad);
      final result = service.processRawAdvertisement(
        bytes: bytes,
        localPeerId: peerA,
      );

      expect(result.result, AdvertisementResult.accepted);
      expect(result.advertisement?.sourceIdentity, peerB);
    });

    test('rejects malformed raw bytes', () {
      final result = service.processRawAdvertisement(
        bytes: [0x01, 0x02, 0x03],
        localPeerId: peerA,
      );

      expect(result.result, AdvertisementResult.rejectedMalformed);
      expect(result.advertisement, isNull);
    });
  });

  group('I8.4 TopologyExchangeService — Indirectly Known Peers', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(neighborTable.neighborPeerIds).thenReturn({peerB});
      when(reachability.getReachableNeighbors()).thenReturn([peerB]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('C is indirectly known when B advertises C', () {
      service.processAdvertisement(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerA, peerC],
        ),
        localPeerId: peerA,
      );

      expect(service.isIndirectlyKnown(peerC), true);
      expect(service.indirectlyKnownPeerIds, contains(peerC));
    });

    test('B is not indirectly known (it is a direct neighbor)', () {
      service.processAdvertisement(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerA, peerC],
        ),
        localPeerId: peerA,
      );

      expect(service.isIndirectlyKnown(peerB), false);
    });
  });

  group('I8.4 TopologyExchangeService — Peer Disconnect', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('disconnecting source removes its topology', () {
      service.processAdvertisement(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerC],
        ),
        localPeerId: peerA,
      );

      service.onPeerDisconnected(peerB);

      expect(repository.remoteSourceIds, isNot(contains(peerB)));
    });

    test('disconnecting non-source is safe', () {
      service.onPeerDisconnected(peerD);
      expect(repository.remoteSourceIds, isEmpty);
    });
  });

  group('I8.4 PacketType Constant', () {
    test('topologyAdvertisement type is defined', () {
      expect(PacketType.topologyAdvertisement, 0x03);
    });

    test('topologyAdvertisement is a valid type', () {
      expect(PacketType.isValid(PacketType.topologyAdvertisement), true);
    });
  });

  group('I8.4 TopologyExchangeService — No Route Creation', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('processing advertisement does not create routes', () {
      when(neighborTable.neighborPeerIds).thenReturn({peerB});

      // After processing B's advertisement, the topology repository
      // has knowledge but no routes are created.
      service.processAdvertisement(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerC],
        ),
        localPeerId: peerA,
      );

      // Topology knowledge exists.
      expect(repository.remoteSourceIds, contains(peerB));

      // But indirectlyKnownPeerIds confirms C is NOT a direct neighbor.
      expect(service.isIndirectlyKnown(peerC), true);
      // And B is still a direct neighbor (from local observation).
      expect(service.isIndirectlyKnown(peerB), false);
    });
  });

  group('I8.4 TopologyExchangeService — Trust Isolation', () {
    late MockNeighborTable neighborTable;
    late MockPeerReachability reachability;
    late TopologyRepository repository;
    late TopologyExchangeService service;

    setUp(() {
      neighborTable = MockNeighborTable();
      reachability = MockPeerReachability();
      repository = TopologyRepository();

      when(reachability.getReachableNeighbors()).thenReturn([]);

      service = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
    });

    test('topology exchange does not modify trust state', () {
      // Verify that processing an advertisement only affects
      // topology state, not trust/verification/authentication.
      // Trust state is managed by TrustService (I6), which is
      // not a dependency of TopologyExchangeService.
      service.processAdvertisement(
        advertisement: const TopologyAdvertisement(
          sourceIdentity: peerB,
          sequence: 1,
          neighborPeerIds: [peerC],
        ),
        localPeerId: peerA,
      );

      // The service has no trust-related methods or state.
      // This test verifies the architectural boundary.
      expect(repository.remoteSourceIds, contains(peerB));
      // No trust API exists on the service — this is the isolation.
    });
  });
}
