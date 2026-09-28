import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/mesh_router.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/route.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology_advertisement.dart';
import 'package:onebit/features/routing/topology_advertisement_codec.dart';
import 'package:onebit/features/routing/topology_exchange_service.dart';
import 'package:onebit/features/routing/topology_repository.dart';

import 'mesh_router_test.mocks.dart';

/// The wiring that makes OneBit reach peers it is not directly talking to:
///
/// * [MeshRouter] installs direct routes from live neighbour state,
///   publishes our local edges, pushes advertisements onto the wire and
///   turns a neighbour's advertisement into an indirect route.
/// * [MessageTransport] prefers a routed I9 envelope over a direct send,
///   and persists an inbound envelope instead of dropping it.
/// * [MessageRelayService] honours the relay-participation setting.
@GenerateMocks([BleService, PeerConnectionManager, PeerReachability])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const peerB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const peerC =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const deviceB = 'AA:BB:CC:DD:02';

  /// Decode a captured `sendReliable` payload as a OneBit packet.
  OneBitPacket packetOf(Object captured) =>
      PacketCodec.decode(Uint8List.fromList(captured as List<int>));

  group('MeshRouter', () {
    late MockBleService ble;
    late MockPeerConnectionManager connectionManager;
    late MockPeerReachability reachability;
    late StreamController<ReliableDataReceived> inbound;
    late NeighborTable neighborTable;
    late TopologyRepository repository;
    late TopologyExchangeService exchange;
    late RouteDiscovery discovery;
    late RoutingTable routingTable;
    late MeshRouter router;

    List<String> reachableNow() =>
        neighborTable.neighbors.map((n) => n.peerId).toList();

    setUp(() {
      ble = MockBleService();
      connectionManager = MockPeerConnectionManager();
      reachability = MockPeerReachability();
      inbound = StreamController<ReliableDataReceived>.broadcast();

      when(ble.reliableDataReceived).thenAnswer((_) => inbound.stream);
      when(ble.sendReliable(any, any))
          .thenAnswer((_) async => TransferResult.delivered);
      when(reachability.getReachableNeighbors())
          .thenAnswer((_) => reachableNow());

      neighborTable = NeighborTable(connectionManager: connectionManager);
      repository = TopologyRepository();
      exchange = TopologyExchangeService(
        neighborTable: neighborTable,
        reachability: reachability,
        repository: repository,
      );
      discovery = RouteDiscovery(
        topologyRepository: repository,
        getReachableNeighbors: () => reachableNow().toSet(),
      );
      routingTable = RoutingTable(localPeerId: localId);

      router = MeshRouter(
        localPeerId: localId,
        neighborTable: neighborTable,
        topologyExchange: exchange,
        topologyRepository: repository,
        routingTable: routingTable,
        bleService: ble,
        getReachableNeighbors: reachableNow,
        discoverRoute: discovery.discoverRoute,
        // Never fire during a test; each case drives advertiseNow itself.
        advertisementInterval: const Duration(hours: 1),
      );
    });

    tearDown(() {
      router.dispose();
      neighborTable.dispose();
      inbound.close();
    });

    Future<void> connectPeerB() async {
      neighborTable.addNeighbor(peerB, bleDeviceId: deviceB);
      await pumpEventQueue();
    }

    test('installs a direct route as soon as a peer connects', () async {
      router.start();
      expect(routingTable.routeCount, 0);

      await connectPeerB();

      final route = routingTable.bestRoute(peerB);
      expect(route, isNotNull);
      expect(route!.nextHopPeerId, peerB);
      expect(route.metric, 1);
      expect(route.source, RouteSource.direct);
    });

    test('retires the route when the peer leaves', () async {
      router.start();
      await connectPeerB();
      expect(routingTable.hasRouteTo(peerB), isTrue);

      neighborTable.forceRemoveNeighbor(peerB);
      await pumpEventQueue();

      expect(routingTable.hasRouteTo(peerB), isFalse);
    });

    test('publishes local edges so route discovery can see them', () async {
      router.start();
      await connectPeerB();

      expect(repository.localNeighborIds, contains(peerB));
    });

    test('pushes a topology advertisement to the connected neighbour',
        () async {
      router.start();
      await connectPeerB();

      final captured = verify(ble.sendReliable(captureAny, captureAny)).captured;
      expect(captured, hasLength(2));
      expect(captured.first, deviceB);

      final packet = packetOf(captured.last);
      expect(packet.type, PacketType.topologyAdvertisement);

      final ad = TopologyAdvertisementCodec.decode(
        Uint8List.fromList(packet.payload),
      );
      expect(ad.sourceIdentity, localId);
      expect(ad.neighborPeerIds, contains(peerB));
    });

    test('learns an indirect route from a neighbour advertisement', () async {
      router.start();
      await connectPeerB();

      // peerB tells us it is directly connected to peerC.
      final packet = OneBitPacket(
        type: PacketType.topologyAdvertisement,
        packetId: 9,
        payload: TopologyAdvertisementCodec.encode(
          const TopologyAdvertisement(
            sourceIdentity: peerB,
            sequence: 1,
            neighborPeerIds: [peerC],
          ),
        ),
      );
      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(packet),
        transferId: 1,
      ));
      await pumpEventQueue();

      final route = routingTable.bestRoute(peerC);
      expect(route, isNotNull);
      expect(route!.nextHopPeerId, peerB);
      expect(route.metric, 2);
      expect(route.source, RouteSource.advertised);
    });

    test('forgets the route once the advertising neighbour leaves',
        () async {
      router.start();
      await connectPeerB();

      final packet = OneBitPacket(
        type: PacketType.topologyAdvertisement,
        packetId: 9,
        payload: TopologyAdvertisementCodec.encode(
          const TopologyAdvertisement(
            sourceIdentity: peerB,
            sequence: 1,
            neighborPeerIds: [peerC],
          ),
        ),
      );
      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(packet),
        transferId: 1,
      ));
      await pumpEventQueue();
      expect(routingTable.hasRouteTo(peerC), isTrue);

      neighborTable.forceRemoveNeighbor(peerB);
      await pumpEventQueue();

      expect(routingTable.hasRouteTo(peerC), isFalse);
      expect(routingTable.hasRouteTo(peerB), isFalse);
    });

    test('stays inert until the local identity is a valid peer ID', () async {
      final inert = MeshRouter(
        localPeerId: 'not-a-peer-id',
        neighborTable: neighborTable,
        topologyExchange: exchange,
        topologyRepository: repository,
        routingTable: routingTable,
        bleService: ble,
        getReachableNeighbors: reachableNow,
        discoverRoute: discovery.discoverRoute,
      );
      addTearDown(inert.dispose);

      inert.start();
      expect(inert.isStarted, isFalse);

      await connectPeerB();

      expect(routingTable.routeCount, 0);
      verifyNever(ble.sendReliable(any, any));
    });

    test('ignores a malformed advertisement without throwing', () async {
      router.start();
      await connectPeerB();

      final packet = OneBitPacket(
        type: PacketType.topologyAdvertisement,
        packetId: 3,
        payload: Uint8List.fromList([0x02, 0x03, 0x04]),
      );
      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(packet),
        transferId: 1,
      ));

      await expectLater(pumpEventQueue(), completes);
      expect(routingTable.hasRouteTo(peerC), isFalse);
    });
  });

  group('MessageTransport over the mesh', () {
    late AppDatabase db;
    late MockBleService ble;
    late StreamController<ReliableDataReceived> inbound;
    MessageTransport? transport;

    setUp(() async {
      db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      ble = MockBleService();
      inbound = StreamController<ReliableDataReceived>.broadcast();

      when(ble.reliableDataReceived).thenAnswer((_) => inbound.stream);
      when(ble.sendReliable(any, any))
          .thenAnswer((_) async => TransferResult.delivered);
    });

    tearDown(() async {
      transport?.dispose();
      await inbound.close();
      await db.close();
    });

    MessageTransport buildTransport({bool withRoute = true}) {
      final transmission = MessageTransmissionService(
        localPeerId: localId,
        bleService: ble,
        routeLookup: (dest) => withRoute && dest == peerB
            ? Route(
                destinationPeerId: peerB,
                nextHopPeerId: peerB,
                metric: 1,
                state: RouteState.active,
                source: RouteSource.direct,
                createdAt: DateTime.now(),
                lastValidatedAt: DateTime.now(),
              )
            : null,
        deviceResolver: (peer) => peer == peerB ? deviceB : null,
        isPeerConnected: (peer) => peer == peerB,
      );

      final built = MessageTransport(
        bleService: ble,
        database: db,
        localPeerId: localId,
        identityForDevice: (device) => device == deviceB ? peerB : null,
        deviceForPeer: (peer) => peer == peerB ? deviceB : null,
        routeLookup: (dest) => withRoute && dest == peerB
            ? Route(
                destinationPeerId: peerB,
                nextHopPeerId: peerB,
                metric: 1,
                state: RouteState.active,
                source: RouteSource.direct,
                createdAt: DateTime.now(),
                lastValidatedAt: DateTime.now(),
              )
            : null,
        transmissionService: transmission,
      );
      built.startListening();
      return built;
    }

    test('sends a routed envelope and re-keys the conversation', () async {
      transport = buildTransport();
      final convId = await db.createConversationWithPeer('Peer B', deviceB);

      final result = await transport!.sendMessage(
        peerDeviceId: deviceB,
        conversationId: convId,
        content: 'hello mesh',
      );
      expect(result, TransferResult.delivered);

      final captured = verify(ble.sendReliable(captureAny, captureAny)).captured;
      expect(captured, hasLength(2));
      expect(captured.first, deviceB);

      final packet = packetOf(captured.last);
      // An I9 envelope announces itself with version byte 0x01; a legacy
      // MessageCodec frame starts with the 2-byte length of "m_1".
      expect(packet.payload.first, 0x01);

      final envelope = MessageEnvelopeCodec.decode(
        Uint8List.fromList(packet.payload),
      );
      expect(envelope.sourcePeerId, localId);
      expect(envelope.destinationPeerId, peerB);
      expect(MessageCodec.decode(envelope.payload).content, 'hello mesh');

      // One peer, one thread: the BLE address gave way to the identity.
      final byIdentity = await db.getConversationByPeerDevice(peerB);
      expect(byIdentity, isNotNull);
      expect(byIdentity!.id, convId);
      expect(await db.getConversationByPeerDevice(deviceB), isNull);

      final messages = await db.getMessages(convId);
      expect(messages.single.content, 'hello mesh');
      expect(messages.single.status, 'sent');
    });

    test('falls back to a direct send when no route exists', () async {
      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Peer B', deviceB);

      final result = await transport!.sendMessage(
        peerDeviceId: deviceB,
        conversationId: convId,
        content: 'no route yet',
      );
      expect(result, TransferResult.delivered);

      final captured = verify(ble.sendReliable(captureAny, captureAny)).captured;
      final packet = packetOf(captured.last);
      expect(packet.payload.first, isNot(0x01));
      expect(
        MessageCodec.decode(Uint8List.fromList(packet.payload)).content,
        'no route yet',
      );
    });

    test('reports failure when the peer cannot be reached at all', () async {
      when(ble.sendReliable('ZZ:ZZ', any))
          .thenAnswer((_) async => TransferResult.failed);

      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Ghost', 'ZZ:ZZ');

      final result = await transport!.sendMessage(
        peerDeviceId: 'ZZ:ZZ',
        conversationId: convId,
        content: 'into the void',
      );
      expect(result, TransferResult.failed);

      final messages = await db.getMessages(convId);
      expect(messages.single.status, 'failed');
    });

    test('persists an inbound envelope addressed to us', () async {
      transport = buildTransport();

      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerB,
        destinationPeerId: localId,
        payload: MessageCodec.encode(
          externalMessageId: 'm_remote_1',
          content: 'from the mesh',
          timestampMs: 1700000000000,
        ),
      );
      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(
          OneBitPacket(
            type: PacketType.message,
            packetId: 1,
            payload: MessageEnvelopeCodec.encode(envelope),
          ),
        ),
        transferId: 1,
      ));
      await pumpEventQueue();

      final conversation = await db.getConversationByPeerDevice(peerB);
      expect(conversation, isNotNull);

      final messages = await db.getMessages(conversation!.id);
      expect(messages.single.content, 'from the mesh');
      expect(messages.single.status, 'received');
    });

    test('re-keys a legacy BLE-address conversation on inbound', () async {
      transport = buildTransport();
      final convId = await db.createConversationWithPeer('Legacy', deviceB);

      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: peerB,
        destinationPeerId: localId,
        payload: MessageCodec.encode(
          externalMessageId: 'm_remote_2',
          content: 'after rotation',
          timestampMs: 1700000000000,
        ),
      );
      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(
          OneBitPacket(
            type: PacketType.message,
            packetId: 1,
            payload: MessageEnvelopeCodec.encode(envelope),
          ),
        ),
        transferId: 1,
      ));
      await pumpEventQueue();

      // Same thread, new key — not a second conversation.
      final rekeyed = await db.getConversationByPeerDevice(peerB);
      expect(rekeyed, isNotNull);
      expect(rekeyed!.id, convId);
      expect(await db.getConversationByPeerDevice(deviceB), isNull);

      final messages = await db.getMessages(convId);
      expect(messages.single.content, 'after rotation');
    });

    test('deduplicates a replayed envelope', () async {
      transport = buildTransport();

      Future<void> deliver() async {
        final envelope = MessageEnvelope(
          protocolVersion: messageProtocolVersion,
          messageId: MessageId(),
          sourcePeerId: peerB,
          destinationPeerId: localId,
          payload: MessageCodec.encode(
            externalMessageId: 'm_dup',
            content: 'only once',
            timestampMs: 1700000000000,
          ),
        );
        inbound.add(ReliableDataReceived(
          deviceId: deviceB,
          payload: PacketCodec.encode(
            OneBitPacket(
              type: PacketType.message,
              packetId: 1,
              payload: MessageEnvelopeCodec.encode(envelope),
            ),
          ),
          transferId: 1,
        ));
        await pumpEventQueue();
      }

      await deliver();
      await deliver();

      final conversation = await db.getConversationByPeerDevice(peerB);
      final messages = await db.getMessages(conversation!.id);
      expect(messages, hasLength(1));
    });
  });

  group('relay participation setting', () {
    late MockBleService ble;

    setUp(() {
      ble = MockBleService();
      when(ble.sendReliable(any, any))
          .thenAnswer((_) async => TransferResult.delivered);
    });

    MessageRelayService buildRelay({required bool allowed}) {
      final transmission = MessageTransmissionService(
        localPeerId: localId,
        bleService: ble,
        routeLookup: (dest) => dest == peerC
            ? Route(
                destinationPeerId: peerC,
                nextHopPeerId: peerC,
                metric: 1,
                state: RouteState.active,
                source: RouteSource.direct,
                createdAt: DateTime.now(),
                lastValidatedAt: DateTime.now(),
              )
            : null,
        deviceResolver: (peer) => peer == peerC ? 'CC:CC:CC:CC:CC' : null,
        isPeerConnected: (peer) => peer == peerC,
      );
      return MessageRelayService(
        localPeerId: localId,
        transmissionService: transmission,
        forwardingAllowed: () => allowed,
      );
    }

    MessageEnvelope forPeerC() => MessageEnvelope(
          protocolVersion: messageProtocolVersion,
          messageId: MessageId(),
          sourcePeerId: peerB,
          destinationPeerId: peerC,
          payload: Uint8List.fromList([1, 2, 3]),
        );

    test('carries traffic when relaying is on', () async {
      final relay = buildRelay(allowed: true);
      final result = await relay.receiveAndRelay(forPeerC());
      expect(result, isA<Forwarded>());
    });

    test('refuses to carry traffic when relaying is off', () async {
      final relay = buildRelay(allowed: false);
      final result = await relay.receiveAndRelay(forPeerC());
      expect(result, isA<RelayFailed>());
      expect((result as RelayFailed).reason, 'Relaying disabled');
      verifyNever(ble.sendReliable(any, any));
    });
  });
}
