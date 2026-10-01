import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/crypto/e2ee_frame.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/protocol/key_announcement.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/protocol/message_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/protocol/receipt_tag.dart';
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
  const deviceC = 'AA:BB:CC:DD:03';

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

    test('announces route recomputation so an outbox can retry', () async {
      router.start();
      var recomputations = 0;
      final sub = router.routesChanged.listen((_) => recomputations++);
      addTearDown(sub.cancel);

      await connectPeerB();
      await pumpEventQueue();
      expect(recomputations, greaterThan(0));

      final afterConnect = recomputations;
      neighborTable.forceRemoveNeighbor(peerB);
      await pumpEventQueue();
      expect(recomputations, greaterThan(afterConnect));
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

    /// Whether a route exists to peerB. peerB is always directly
    /// connected, so only its *route* is optional here.
    var routeIsUp = true;

    /// Whether peerC is reachable at all — route and device together.
    /// peerC starts out of reach; the outbox tests bring it within
    /// reach mid-flight.
    var peerCUp = false;

    Route routeToPeer(String peer) => Route(
          destinationPeerId: peer,
          nextHopPeerId: peer,
          metric: 1,
          state: RouteState.active,
          source: RouteSource.direct,
          createdAt: DateTime.now(),
          lastValidatedAt: DateTime.now(),
        );

    Route? routeTo(String dest) {
      if (dest == peerB) return routeIsUp ? routeToPeer(peerB) : null;
      if (dest == peerC) return peerCUp ? routeToPeer(peerC) : null;
      return null;
    }

    String? deviceFor(String peer) {
      if (peer == peerB) return deviceB;
      if (peer == peerC) return peerCUp ? deviceC : null;
      return null;
    }

    MessageTransport buildTransport({
      bool? withRoute,
      Stream<void>? routeEvents,
    }) {
      // The group body runs once, so every test re-establishes the
      // fixture here; the outbox cases then bring peerC up by hand.
      routeIsUp = withRoute ?? true;
      peerCUp = false;

      final transmission = MessageTransmissionService(
        localPeerId: localId,
        bleService: ble,
        routeLookup: routeTo,
        deviceResolver: deviceFor,
        isPeerConnected: (peer) => deviceFor(peer) != null,
      );

      final built = MessageTransport(
        bleService: ble,
        database: db,
        localPeerId: localId,
        identityForDevice: (device) => device == deviceB
            ? peerB
            : device == deviceC
                ? peerC
                : null,
        deviceForPeer: deviceFor,
        routeLookup: routeTo,
        transmissionService: transmission,
        routeEvents: routeEvents,
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
      // An I9 envelope announces itself with the envelope protocol version;
      // a legacy MessageCodec frame starts with the 2-byte length of "m_1".
      expect(packet.payload.first, messageProtocolVersion);

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
      expect(packet.payload.first, isNot(messageProtocolVersion));
      expect(
        MessageCodec.decode(Uint8List.fromList(packet.payload)).content,
        'no route yet',
      );
    });

    test('a peer with no device leaves the message in the outbox',
        () async {
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

      // Not delivered, but not written off either: the peer may simply
      // not be on the air yet.
      final messages = await db.getMessages(convId);
      expect(messages.single.status, 'queued');
      expect(await db.queuedMessages(), hasLength(1));
    });

    test('a known identity with no device leaves the message in the outbox',
        () async {
      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Peer C', peerC);

      final result = await transport!.sendMessage(
        peerDeviceId: peerC,
        conversationId: convId,
        content: 'nobody home',
      );

      expect(result, isNot(TransferResult.delivered));
      expect((await db.getMessages(convId)).single.status, 'queued');
      verifyNever(ble.sendReliable(any, any));
    });

    test('flush delivers a queued message once a route appears', () async {
      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Peer C', peerC);
      await transport!.sendMessage(
        peerDeviceId: peerC,
        conversationId: convId,
        content: 'saved for later',
      );
      expect((await db.getMessages(convId)).single.status, 'queued');

      peerCUp = true;
      await transport!.flushQueued();

      expect((await db.getMessages(convId)).single.status, 'sent');
      expect(await db.queuedMessages(), isEmpty);
      verify(ble.sendReliable(deviceC, any)).called(1);
    });

    test('flush leaves the message queued while the peer is still out of reach',
        () async {
      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Peer C', peerC);
      await transport!.sendMessage(
        peerDeviceId: peerC,
        conversationId: convId,
        content: 'still nobody home',
      );

      await transport!.flushQueued();

      expect((await db.getMessages(convId)).single.status, 'queued');
      verifyNever(ble.sendReliable(any, any));
    });

    test('a route change event triggers the flush on its own', () async {
      final routeEvents = StreamController<void>.broadcast();
      addTearDown(routeEvents.close);

      transport = buildTransport(
        withRoute: false,
        routeEvents: routeEvents.stream,
      );
      final convId = await db.createConversationWithPeer('Peer C', peerC);
      await transport!.sendMessage(
        peerDeviceId: peerC,
        conversationId: convId,
        content: 'waiting on the mesh',
      );
      expect((await db.getMessages(convId)).single.status, 'queued');

      peerCUp = true;
      routeEvents.add(null);
      await pumpEventQueue();

      expect((await db.getMessages(convId)).single.status, 'sent');
      expect(await db.queuedMessages(), isEmpty);
    });

    test('a message too long for one packet goes out in pieces', () async {
      transport = buildTransport();
      final convId = await db.createConversationWithPeer('Peer B', deviceB);
      final content = 'x' * 600;

      final result = await transport!.sendMessage(
        peerDeviceId: deviceB,
        conversationId: convId,
        content: content,
      );
      expect(result, TransferResult.delivered);

      // deviceId / payload, repeated once per packet.
      final captured = verify(ble.sendReliable(captureAny, captureAny)).captured;
      expect(captured.length, greaterThan(2));
      expect(captured.whereType<String>(), everyElement(deviceB));

      final reassembler = PacketChunkReassembler();
      Uint8List? envelopeBytes;
      for (var i = 1; i < captured.length; i += 2) {
        final packet = packetOf(captured[i]);
        expect(packet.type, PacketType.message);
        envelopeBytes = reassembler.accept(
          'peer',
          packet.packetId,
          Uint8List.fromList(packet.payload),
        );
      }

      expect(envelopeBytes, isNotNull);
      final envelope = MessageEnvelopeCodec.decode(envelopeBytes!);
      expect(envelope.destinationPeerId, peerB);
      expect(MessageCodec.decode(envelope.payload).content, content);

      expect((await db.getMessages(convId)).single.status, 'sent');
    });

    test('a message that can never fit is failed, not queued', () async {
      transport = buildTransport(withRoute: false);
      final convId = await db.createConversationWithPeer('Peer B', deviceB);

      final result = await transport!.sendMessage(
        peerDeviceId: deviceB,
        conversationId: convId,
        content: 'x' * (MessageCodec.maxContentLength + 1),
      );

      expect(result, isNot(TransferResult.delivered));
      expect((await db.getMessages(convId)).single.status, 'failed');
      expect(await db.queuedMessages(), isEmpty);
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

    test('a receipt from the peer raises the message it names', () async {
      transport = buildTransport();
      final convId = await db.createConversationWithPeer('Peer B', deviceB);

      final result = await transport!.sendMessage(
        peerDeviceId: deviceB,
        conversationId: convId,
        content: 'did you get this?',
      );
      expect(result, TransferResult.delivered);

      final sent = (await db.getMessages(convId)).single;
      expect(sent.status, 'sent');

      Future<void> hearAbout(ReceiptKind kind) async {
        inbound.add(ReliableDataReceived(
          deviceId: deviceB,
          payload: PacketCodec.encode(OneBitPacket(
            type: PacketType.message,
            packetId: 1,
            payload: MessageEnvelopeCodec.encode(MessageEnvelope(
              protocolVersion: messageProtocolVersion,
              messageId: MessageId(),
              sourcePeerId: peerB,
              destinationPeerId: localId,
              payload: ReceiptTag.encodeFrame(
                kind: kind,
                messageIds: ['m_${sent.id}'],
                timestampMs: 1700000000000,
              ),
            )),
          )),
          transferId: 1,
        ));
        await pumpEventQueue();
      }

      await hearAbout(ReceiptKind.delivered);
      expect((await db.getMessages(convId)).single.status, 'delivered');

      await hearAbout(ReceiptKind.read);
      expect((await db.getMessages(convId)).single.status, 'read');

      // A receipt is not a message: the thread still holds the one
      // thing that was said, and no second conversation appeared.
      expect(await db.getMessages(convId), hasLength(1));
      expect(await db.getConversationByPeerDevice(deviceB), isNull);
    });

    test('a message that lands earns a receipt on its way home', () async {
      transport = buildTransport();

      inbound.add(ReliableDataReceived(
        deviceId: deviceB,
        payload: PacketCodec.encode(OneBitPacket(
          type: PacketType.message,
          packetId: 1,
          payload: MessageEnvelopeCodec.encode(MessageEnvelope(
            protocolVersion: messageProtocolVersion,
            messageId: MessageId(),
            sourcePeerId: peerB,
            destinationPeerId: localId,
            payload: MessageCodec.encode(
              externalMessageId: 'm_7',
              content: 'are you there?',
              timestampMs: 1700000000000,
            ),
          )),
        )),
        transferId: 1,
      ));
      await pumpEventQueue();

      final conversation = await db.getConversationByPeerDevice(peerB);
      final messages = await db.getMessages(conversation!.id);
      expect(messages.single.content, 'are you there?');
      expect(messages.single.isRead, 0);

      // The only thing this exchange put back on the wire is the
      // receipt — and it travels either wrapped in an envelope (when
      // the mesh can carry it) or straight down the direct link.
      final captured =
          verify(ble.sendReliable(captureAny, captureAny)).captured;
      expect(captured, hasLength(2));

      final payload = Uint8List.fromList(packetOf(captured.last).payload);
      final frame = payload.first == messageProtocolVersion
          ? MessageEnvelopeCodec.decode(payload).payload
          : payload;
      final receipt = ReceiptTag.decodeFrame(frame);

      expect(receipt, isNotNull);
      expect(receipt!.kind, ReceiptKind.delivered);
      expect(receipt.messageIds, ['m_7']);
    });

    test('ackRead puts the ids it was given on the wire', () async {
      transport = buildTransport();

      await transport!.ackRead(
        peerKey: peerB,
        fallbackDeviceId: deviceB,
        messageIds: ['m_1', 'm_2', 'm_3'],
      );
      await pumpEventQueue();

      // Small enough to be one packet, so one call.
      final captured =
          verify(ble.sendReliable(captureAny, captureAny)).captured;
      expect(captured, hasLength(2));

      final payload = Uint8List.fromList(packetOf(captured.last).payload);
      final frame = payload.first == messageProtocolVersion
          ? MessageEnvelopeCodec.decode(payload).payload
          : payload;
      final receipt = ReceiptTag.decodeFrame(frame);

      expect(receipt, isNotNull);
      expect(receipt!.kind, ReceiptKind.read);
      expect(receipt.messageIds, ['m_1', 'm_2', 'm_3']);
    });
  });

  group('MessageTransport end-to-end encryption', () {
    late AppDatabase db;
    late MockBleService ble;
    late StreamController<ReliableDataReceived> inbound;
    MessageTransport? transport;

    late SimpleKeyPair localEd;
    late Uint8List localXBytes;
    late SimpleKeyPair localX;
    late Uint8List localEdBytes;
    late SimpleKeyPair peerEd;
    late SimpleKeyPair peerX;
    late Uint8List peerXBytes;
    late String peerEdHex;
    const deviceP = 'AA:BB:CC:DD:EE';

    String hexOf(Uint8List bytes) => IdentityRepository.bytesToHex(bytes);

    setUp(() async {
      db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
      ble = MockBleService();
      inbound = StreamController<ReliableDataReceived>.broadcast();

      when(ble.reliableDataReceived).thenAnswer((_) => inbound.stream);
      when(ble.sendReliable(any, any))
          .thenAnswer((_) async => TransferResult.delivered);

      localEd = await Ed25519().newKeyPair();
      localX = await X25519().newKeyPair();
      localXBytes =
          Uint8List.fromList((await localX.extractPublicKey()).bytes);
      localEdBytes =
          Uint8List.fromList((await localEd.extractPublicKey()).bytes);
      peerEd = await Ed25519().newKeyPair();
      peerX = await X25519().newKeyPair();
      peerXBytes = Uint8List.fromList((await peerX.extractPublicKey()).bytes);
      peerEdHex = hexOf(
        Uint8List.fromList((await peerEd.extractPublicKey()).bytes),
      );
    });

    tearDown(() async {
      transport?.dispose();
      await inbound.close();
      await db.close();
    });

    Route routeToPeerFor(String peer) => Route(
          destinationPeerId: peer,
          nextHopPeerId: peer,
          metric: 1,
          state: RouteState.active,
          source: RouteSource.direct,
          createdAt: DateTime.now(),
          lastValidatedAt: DateTime.now(),
        );

    Route? routeTo(String dest) =>
        dest == peerEdHex ? routeToPeerFor(peerEdHex) : null;

    String? deviceFor(String peer) => peer == peerEdHex ? deviceP : null;

    MessageTransport buildKeyedTransport() {
      final transmission = MessageTransmissionService(
        localPeerId: localId,
        bleService: ble,
        routeLookup: routeTo,
        deviceResolver: deviceFor,
        isPeerConnected: (peer) => deviceFor(peer) != null,
      );

      final built = MessageTransport(
        bleService: ble,
        database: db,
        localPeerId: localId,
        identityForDevice: (device) => device == deviceP ? peerEdHex : null,
        deviceForPeer: deviceFor,
        routeLookup: routeTo,
        transmissionService: transmission,
        localKeyAgreement: () async => localX,
        localSign: (message) async => Uint8List.fromList(
          (await Ed25519().sign(message, keyPair: localEd)).bytes,
        ),
      );
      built.startListening();
      return built;
    }

    /// Every outbound frame payload, unwrapped from its packets and
    /// envelope: what actually traveled. Reassembles chunked sends, so
    /// a frame that outgrew one packet still arrives here whole.
    Future<List<Uint8List>> outboundPayloads() async {
      final captured =
          verify(ble.sendReliable(captureAny, captureAny)).captured;
      final reassembler = PacketChunkReassembler();
      final out = <Uint8List>[];
      for (var i = 1; i < captured.length; i += 2) {
        final packet = packetOf(captured[i]);
        final whole = reassembler.accept(
          captured[i - 1] as String,
          packet.packetId,
          Uint8List.fromList(packet.payload),
        );
        if (whole == null) continue;
        out.add(
          whole.first == messageProtocolVersion
              ? MessageEnvelopeCodec.decode(whole).payload
              : whole,
        );
      }
      return out;
    }

    void hearEnvelope({
      required Uint8List framePayload,
      required String from,
    }) {
      final envelope = MessageEnvelope(
        protocolVersion: messageProtocolVersion,
        messageId: MessageId(),
        sourcePeerId: from,
        destinationPeerId: localId,
        payload: framePayload,
      );
      // Production sends chunk; the test link must too, or anything
      // past one packet throws in PacketCodec instead of arriving.
      final slices = splitPayload(MessageEnvelopeCodec.encode(envelope));
      var transferId = 1;
      for (final slice in slices) {
        inbound.add(ReliableDataReceived(
          deviceId: deviceP,
          payload: PacketCodec.encode(
            OneBitPacket(
              type: PacketType.message,
              packetId: 1,
              payload: slice,
            ),
          ),
          transferId: transferId++,
        ));
      }
    }

    test('encrypts when the peer key is known', () async {
      transport = buildKeyedTransport();
      await db.storePeerKeyAgreementPublicKey(
        identityId: peerEdHex,
        keyAgreementPublicKey: hexOf(peerXBytes),
      );
      final convId = await db.createConversationWithPeer('Peer', peerEdHex);

      final result = await transport!.sendMessage(
        peerDeviceId: peerEdHex,
        conversationId: convId,
        content: 'secret',
      );
      expect(result, TransferResult.delivered);

      // The peer has not proven they hold our key yet, so our
      // announcement rides along with the encrypted message.
      final payloads = await outboundPayloads();
      expect(payloads, hasLength(2));

      final opened = <DecodedMessage>[];
      ({String keyHex, Uint8List signature})? announcement;
      for (final payload in payloads) {
        final decrypted = await E2eeFrame.decrypt(
          localKeyPair: peerX,
          payload: payload,
        );
        if (decrypted != null) {
          expect(decrypted.senderKey, localXBytes);
          opened.add(MessageCodec.decode(decrypted.frame));
        } else {
          announcement = KeyAnnouncement.decodeFrame(payload);
        }
      }

      expect(opened.single.content, 'secret');
      expect((await db.getMessages(convId)).single.isEncrypted, 1);
      expect(announcement, isNotNull);      expect(
        await KeyAnnouncement.verify(
          content: KeyAnnouncement.encode(
            x25519Hex: announcement!.keyHex,
            signature: announcement.signature,
          ),
          senderEdPublicKey: localEdBytes,
        ),
        isTrue,
      );

      // And on the wire it is opaque: no strict decode reads it.
      for (final payload in payloads) {
        if (KeyAnnouncement.decodeFrame(payload) == null) {
          expect(() => MessageCodec.decode(payload), throwsArgumentError);
        }
      }
    });

    test('sends plaintext plus an announcement when the key is unknown',
        () async {
      transport = buildKeyedTransport();
      final convId = await db.createConversationWithPeer('Peer', peerEdHex);

      final result = await transport!.sendMessage(
        peerDeviceId: peerEdHex,
        conversationId: convId,
        content: 'hello',
      );
      expect(result, TransferResult.delivered);

      final payloads = await outboundPayloads();
      expect(payloads, hasLength(2));

      var sawPlaintext = false;
      var sawAnnouncement = false;
      for (final payload in payloads) {
        final announcement = KeyAnnouncement.decodeFrame(payload);
        if (announcement != null) {
          sawAnnouncement = true;
          expect(
            await KeyAnnouncement.verify(
              content: KeyAnnouncement.encode(
                x25519Hex: announcement.keyHex,
                signature: announcement.signature,
              ),
              senderEdPublicKey: localEdBytes,
            ),
            isTrue,
          );
        } else {
          expect(MessageCodec.decode(payload).content, 'hello');
          sawPlaintext = true;
        }
      }
      expect(sawPlaintext, isTrue);
      expect(sawAnnouncement, isTrue);
      expect((await db.getMessages(convId)).single.isEncrypted, 0);
    });

    test('a received encrypted frame decrypts and teaches the key',
        () async {
      transport = buildKeyedTransport();

      final inner = MessageCodec.encode(
        externalMessageId: 'm_99',
        content: 'secret',
        timestampMs: 1700000000000,
      );
      hearEnvelope(
        framePayload: await E2eeFrame.encrypt(
          localKeyPair: peerX,
          peerPublicKey: localXBytes,
          frame: inner,
        ),
        from: peerEdHex,
      );
      await pumpEventQueue();

      final conversation = await db.getConversationByPeerDevice(peerEdHex);
      expect(conversation, isNotNull);
      final messages = await db.getMessages(conversation!.id);
      expect(messages.single.content, 'secret');
      expect(messages.single.isEncrypted, 1);

      expect(await db.peerKeyAgreementKey(peerEdHex), hexOf(peerXBytes));
    });

    test('a signed announcement is stored, never displayed', () async {
      transport = buildKeyedTransport();

      final signature = await Ed25519().sign(peerXBytes, keyPair: peerEd);
      hearEnvelope(
        framePayload: KeyAnnouncement.encodeFrame(
          x25519Hex: hexOf(peerXBytes),
          signature: Uint8List.fromList(signature.bytes),
          timestampMs: 1700000000000,
        ),
        from: peerEdHex,
      );
      await pumpEventQueue();

      expect(await db.peerKeyAgreementKey(peerEdHex), hexOf(peerXBytes));
      expect(await db.getConversationByPeerDevice(peerEdHex), isNull);
    });

    test('a forged announcement is dropped', () async {
      transport = buildKeyedTransport();

      final malloryEd = await Ed25519().newKeyPair();
      final forged = await Ed25519().sign(peerXBytes, keyPair: malloryEd);
      hearEnvelope(
        framePayload: KeyAnnouncement.encodeFrame(
          x25519Hex: hexOf(peerXBytes),
          signature: Uint8List.fromList(forged.bytes),
          timestampMs: 1700000000000,
        ),
        from: peerEdHex,
      );
      await pumpEventQueue();

      expect(await db.peerKeyAgreementKey(peerEdHex), isNull);
      expect(await db.getConversationByPeerDevice(peerEdHex), isNull);
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
