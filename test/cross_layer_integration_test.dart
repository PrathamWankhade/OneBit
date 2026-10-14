// I10.1 — the cross-layer harness: four devices, one box, the whole stack.
//
// Every earlier multi-device test stops at a wall. The multi_peer
// suites prove identity and routing at the state layer, with no
// radio above them; the I9.17 lifecycle tests run real transports
// over a wire, but their routes are handed in by hand. This is the
// seam neither covers: devices that discover each other, push real
// topology advertisements across the wire, learn their routing
// tables from those advertisements, and then carry an end-to-end
// encrypted message multi-hop on the routes they learned — with
// receipts walking home the same way. Nothing in any routing table
// below is installed by the test; the cascade installs it.

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/mesh_router.dart';
import 'package:onebit/features/routing/neighbor_table.dart';
import 'package:onebit/features/routing/peer_reachability.dart';
import 'package:onebit/features/routing/route_discovery.dart';
import 'package:onebit/features/routing/routing_table.dart';
import 'package:onebit/features/routing/topology_exchange_service.dart';
import 'package:onebit/features/routing/topology_repository.dart';

import 'helpers/virtual_medium.dart';
import 'cross_layer_integration_test.mocks.dart';

@GenerateMocks([PeerConnectionManager, PeerReachability])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VirtualWire wire;
  final devices = <_Device>[];

  setUp(() {
    wire = VirtualWire();
    devices.clear();
  });

  tearDown(() async {
    for (final device in devices) {
      await device.dispose();
    }
    await wire.close();
  });

  Future<_Device> makeDevice({required String address}) async {
    final radio = wire.radioFor(address);
    final edPair = await Ed25519().newKeyPair();
    final device = _Device(
      address: address,
      // The peer id IS the Ed25519 public key: that is what lets a
      // receiver verify an announcement's signature against the name
      // the envelope carries.
      peerId: IdentityRepository.bytesToHex(
        Uint8List.fromList((await edPair.extractPublicKey()).bytes),
      ),
      radio: radio,
      xPair: await X25519().newKeyPair(),
      edPair: edPair,
      reachability: MockPeerReachability(),
    );
    devices.add(device);
    when(device.reachability.getReachableNeighbors())
        .thenAnswer((_) => device.reachablePeerIds());
    // Both listening layers come up before any traffic: broadcast
    // streams with no listener drop what arrives before it.
    device.router.start();
    device.transport;
    return device;
  }

  group('I10.1 — identity, BLE, routing and delivery together', () {
    test(
        'four devices learn their routes from advertisements and carry an '
        'encrypted message across them', () async {
      final a = await makeDevice(address: 'DEV_A');
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');
      final d = await makeDevice(address: 'DEV_D');

      // The BLE layer connects the chain: A—B—C—D. Every address
      // below is what the neighbour table hands the radio.
      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      c.neighbors.addNeighbor(d.peerId, bleDeviceId: 'DEV_D');
      d.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');

      await pumpEventQueue();
      await pumpEventQueue();

      // ── Routing, learned ───────────────────────────────────
      // Each device's advertisement crossed the wire to each of
      // its neighbours; these are the edges of the graph, flown.
      expect(
        wire.packets,
        containsAll([
          (from: 'DEV_A', to: 'DEV_B', type: PacketType.topologyAdvertisement),
          (from: 'DEV_B', to: 'DEV_C', type: PacketType.topologyAdvertisement),
          (from: 'DEV_C', to: 'DEV_D', type: PacketType.topologyAdvertisement),
          (from: 'DEV_D', to: 'DEV_C', type: PacketType.topologyAdvertisement),
        ]),
      );

      // A knows its neighbour and — through B's advertisement — the
      // two-hop destination, and nothing else. The table was built
      // by the cascade, not by this test.
      expect(a.routing.routeCount, 2);
      final aToC = a.routing.bestRoute(c.peerId);
      expect(aToC, isNotNull);
      expect(aToC!.nextHopPeerId, b.peerId);
      expect(aToC.metric, 2);

      // The far end learned the graph from the same flood: D sees B
      // through C's advertisement.
      final dToB = d.routing.bestRoute(b.peerId);
      expect(dToB, isNotNull);
      expect(dToB!.nextHopPeerId, c.peerId);
      expect(dToB.metric, 2);

      // ── Delivery, first contact (plaintext bootstrap) ──────
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      final result = await a.transport.sendMessage(
        peerDeviceId: c.peerId,
        conversationId: aConv,
        content: 'the whole stack says hello',
      );
      expect(result, TransferResult.delivered);

      // The message left on A's learned route: hop 0 to B, hop 1
      // behind it, exactly the next hop the table named.
      expect(
        wire.crossings,
        containsAllInOrder([
          (from: 'DEV_A', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_C', hops: 1),
        ]),
      );

      await pumpEventQueue();
      await pumpEventQueue();

      // C has the words, in the clear — its key was unknown when A
      // typed them — and the announcement riding along taught C who
      // to encrypt to.
      final cConv = await c.db.getConversationByPeerDevice(a.peerId);
      expect(cConv, isNotNull);
      final firstAtC = (await c.db.getMessages(cConv!.id)).single;
      expect(firstAtC.content, 'the whole stack says hello');
      expect(firstAtC.isEncrypted, 0);
      expect(
        await c.db.peerKeyAgreementKey(a.peerId),
        IdentityRepository.bytesToHex(
          Uint8List.fromList((await a.xPair.extractPublicKey()).bytes),
        ),
      );

      // B carried it and kept nothing: a pipe, not a party.
      expect(await b.db.getConversationByPeerDevice(a.peerId), isNull);
      expect(await b.db.getConversationByPeerDevice(c.peerId), isNull);

      // The delivered receipt walked home through B, unasked.
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');

      // ── The reply, already encrypted ───────────────────────
      // C answers in the thread the arrival created — no new
      // conversation — and because C now holds A's key, C's first
      // words leave in the envelope's sealed form and A's database
      // says so on arrival.
      final replyConv = cConv.id;
      final reply = await c.transport.sendMessage(
        peerDeviceId: a.peerId,
        conversationId: replyConv,
        content: 'the stack says it back',
      );
      expect(reply, TransferResult.delivered);

      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        wire.crossings,
        containsAllInOrder([
          (from: 'DEV_C', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_A', hops: 1),
        ]),
      );

      final aRows = await a.db.getMessages(aConv);
      final received = aRows.singleWhere(
        (row) => row.content == 'the stack says it back',
      );
      expect(received.isEncrypted, 1);
      // Decrypting it taught A C's key in return.
      expect(
        await a.db.peerKeyAgreementKey(c.peerId),
        IdentityRepository.bytesToHex(
          Uint8List.fromList((await c.xPair.extractPublicKey()).bytes),
        ),
      );
      // And C's receipt for its own words came home through B.
      expect(
        (await c.db.getMessages(replyConv))
            .singleWhere((row) => row.content == 'the stack says it back')
            .status,
        'delivered',
      );

      // ── Third contact, sealed both ways ────────────────────
      final again = await a.transport.sendMessage(
        peerDeviceId: c.peerId,
        conversationId: aConv,
        content: 'now we are encrypted',
      );
      expect(again, TransferResult.delivered);

      await pumpEventQueue();
      await pumpEventQueue();

      final cRows = await c.db.getMessages(cConv.id);
      expect(cRows, hasLength(3)); // two arrivals, one reply, no extras
      final sealed = cRows.singleWhere(
        (row) => row.content == 'now we are encrypted',
      );
      expect(sealed.isEncrypted, 1);
    });
  });
}

/// One device: the full stack in working order — database, keys,
/// neighbour table, topology exchange, routing, mesh router, relay,
/// transport — every layer wired to the one below it the way the
/// providers wire them, and nothing installed by hand.
class _Device {
  _Device({
    required this.address,
    required this.peerId,
    required this.radio,
    required this.xPair,
    required this.edPair,
    required this.reachability,
  });

  final String address;
  final String peerId;
  final VirtualRadio radio;

  /// The device's own identity: X25519 for encryption, Ed25519 for
  /// signing the announcements that carry the encryption key.
  final SimpleKeyPair xPair;
  final SimpleKeyPair edPair;

  final MockPeerReachability reachability;

  late final AppDatabase db =
      AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

  late final NeighborTable neighbors = NeighborTable(
    connectionManager: MockPeerConnectionManager(),
  );

  late final TopologyRepository repository = TopologyRepository();

  late final TopologyExchangeService exchange = TopologyExchangeService(
    neighborTable: neighbors,
    reachability: reachability,
    repository: repository,
  );

  late final RouteDiscovery discovery = RouteDiscovery(
    topologyRepository: repository,
    getReachableNeighbors: () => reachablePeerIds().toSet(),
  );

  late final RoutingTable routing = RoutingTable(localPeerId: peerId);

  late final MeshRouter router = MeshRouter(
    localPeerId: peerId,
    neighborTable: neighbors,
    topologyExchange: exchange,
    topologyRepository: repository,
    routingTable: routing,
    bleService: radio,
    getReachableNeighbors: reachablePeerIds,
    discoverRoute: discovery.discoverRoute,
    // Never fires during a test; the neighbour cascade drives
    // advertisements itself.
    advertisementInterval: const Duration(hours: 1),
  );

  late final MessageRelayService relay;
  late final MessageTransport transport = _buildTransport();

  /// The peers this device can reach in one hop — the edge set it
  /// advertises and the BFS seeds its discovery.
  List<String> reachablePeerIds() => [
        for (final entry in neighbors.neighbors) entry.peerId,
      ];

  String? _deviceFor(String peer) {
    for (final entry in neighbors.neighbors) {
      if (entry.peerId == peer) return entry.bleDeviceId;
    }
    return null;
  }

  MessageTransport _buildTransport() {
    final transmission = MessageTransmissionService(
      localPeerId: peerId,
      bleService: radio,
      routeLookup: (dest) => routing.bestRoute(dest),
      deviceResolver: _deviceFor,
      isPeerConnected: (peer) => neighbors.isNeighbor(peer),
    );
    relay = MessageRelayService(
      localPeerId: peerId,
      transmissionService: transmission,
      retryBaseBackoff: Duration.zero,
    );
    final built = MessageTransport(
      bleService: radio,
      database: db,
      localPeerId: peerId,
      relayService: relay,
      transmissionService: transmission,
      routeLookup: (dest) => routing.bestRoute(dest),
      deviceForPeer: _deviceFor,
      // The transport hears the router's route changes and flushes
      // anything queued behind them.
      routeEvents: router.routesChanged,
      localKeyAgreement: () async => xPair,
      localSign: (message) async => Uint8List.fromList(
        (await Ed25519().sign(message, keyPair: edPair)).bytes,
      ),
    );
    built.startListening();
    return built;
  }

  Future<void> dispose() async {
    router.dispose();
    neighbors.dispose();
    transport.dispose();
    await db.close();
  }
}
