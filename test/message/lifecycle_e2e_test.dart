// I9.17.a — the message lifecycle across devices, in one box.
//
// Everything below runs the real stack: real transports, real
// codecs, real relay, real databases. The only fake is the radio —
// a wire that carries bytes from one node's `sendReliable` straight
// into another node's inbox, which is exactly what the BLE layer
// promises. What is being tested here is the thing no single-node
// test can see: a message that leaves one database, crosses
// somebody else's relay, lands in a second database, and brings
// its receipt home again.

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/application/message_transmission_service.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';
import 'package:onebit/features/routing/route.dart';

/// One radio medium in a box: addresses are BLE device ids, and a
/// send lands in the addressee's inbox as though the stack had
/// delivered it.
class _Wire {
  final Map<String, StreamController<ReliableDataReceived>> _inboxes = {};

  /// Every envelope that crossed, in order: (from, to, hop count).
  final List<({String from, String to, int hops})> crossings = [];

  int _transferId = 0;

  /// The radio a node at [address] talks through. Registers the
  /// inbox first, so anything sent to this address has somewhere
  /// to land.
  _WireBle radioFor(String address) {
    final inbox = _inboxes.putIfAbsent(
      address,
      () => StreamController<ReliableDataReceived>.broadcast(),
    );
    return _WireBle(this, address, inbox.stream);
  }

  Future<TransferResult> send({
    required String from,
    required String to,
    required List<int> payload,
  }) async {
    final inbox = _inboxes[to];
    if (inbox == null) return TransferResult.failed; // no such radio

    final packet = PacketCodec.decode(Uint8List.fromList(payload));
    if (packet.type == PacketType.message) {
      final envelope = MessageEnvelopeCodec.decode(
        Uint8List.fromList(packet.payload),
      );
      crossings.add((from: from, to: to, hops: envelope.hopCount));
    }

    inbox.add(ReliableDataReceived(
      deviceId: from,
      payload: payload,
      transferId: ++_transferId,
    ));
    return TransferResult.delivered;
  }

  Future<void> close() async {
    for (final inbox in _inboxes.values) {
      await inbox.close();
    }
  }
}

/// A node's radio: the two calls the stack makes, wired to the box.
class _WireBle extends BleService {
  _WireBle(this._wire, this.address, this._inbox);

  final _Wire _wire;
  final String address;
  final Stream<ReliableDataReceived> _inbox;

  @override
  Stream<ReliableDataReceived> get reliableDataReceived => _inbox;

  @override
  Future<TransferResult> sendReliable(String deviceId, List<int> payload) =>
      _wire.send(from: address, to: deviceId, payload: payload);
}

/// One device: its database, its transport, and what it believes
/// about the world — which routes exist, which identity sits behind
/// which address, and who is currently up.
class _Node {
  _Node(this.ble, {required this.address, required this.peerId});

  final String address;
  final String peerId;
  final _WireBle ble;

  late final AppDatabase db =
      AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

  late final MessageTransport transport = _buildTransport();

  final Map<String, Route> routes = {};
  final Map<String, String> devices = {};
  final Set<String> connected = {};

  MessageTransport _buildTransport() {
    final transmission = MessageTransmissionService(
      localPeerId: peerId,
      bleService: ble,
      routeLookup: (dest) => routes[dest],
      deviceResolver: (peer) => devices[peer],
      isPeerConnected: (peer) => connected.contains(peer),
    );
    final built = MessageTransport(
      bleService: ble,
      database: db,
      localPeerId: peerId,
      relayService: MessageRelayService(
        localPeerId: peerId,
        transmissionService: transmission,
      ),
      transmissionService: transmission,
      routeLookup: (dest) => routes[dest],
      deviceForPeer: (peer) => devices[peer],
    );
    built.startListening();
    return built;
  }

  Future<void> dispose() async {
    transport.dispose();
    await db.close();
  }
}

Route _route({required String dest, required String nextHop}) => Route(
      destinationPeerId: dest,
      nextHopPeerId: nextHop,
      metric: 1,
      state: RouteState.active,
      source: RouteSource.direct,
      createdAt: DateTime.now(),
      lastValidatedAt: DateTime.now(),
    );

void main() {
  const peerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const peerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const peerC = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  late _Wire wire;
  final nodes = <_Node>[];

  setUp(() {
    wire = _Wire();
    nodes.clear();
  });

  tearDown(() async {
    for (final node in nodes) {
      await node.dispose();
    }
    await wire.close();
  });

  _Node makeNode({required String address, required String peerId}) {
    final node = _Node(wire.radioFor(address), address: address, peerId: peerId);
    nodes.add(node);
    // Force the transport up before any traffic: a broadcast stream
    // with no listener drops what arrives before it.
    node.transport;
    return node;
  }

  group('I9.17.a — outbound to inbound, directly routed', () {
    test(
        'a message leaves one database, lands in the other, '
        'and its receipts come home', () async {
      final a = makeNode(address: 'DEV_A', peerId: peerA);
      final c = makeNode(address: 'DEV_C', peerId: peerC);

      a.routes[peerC] = _route(dest: peerC, nextHop: peerC);
      a.devices[peerC] = 'DEV_C';
      a.connected.add(peerC);

      c.routes[peerA] = _route(dest: peerA, nextHop: peerA);
      c.devices[peerA] = 'DEV_A';
      c.connected.add(peerA);

      final aConv = await a.db.createConversationWithPeer('C', peerC);

      final result = await a.transport.sendMessage(
        peerDeviceId: peerC,
        conversationId: aConv,
        content: 'hello across the box',
      );
      expect(result, TransferResult.delivered);

      // Outbound half: A's row is on its way, and it went out as an
      // envelope straight to C — no third party in the path.
      final aRow = (await a.db.getMessages(aConv)).single;
      expect(aRow.status, anyOf('sent', 'delivered'));
      expect(
        wire.crossings,
        contains((from: 'DEV_A', to: 'DEV_C', hops: 0)),
      );

      await pumpEventQueue();
      await pumpEventQueue();

      // Inbound half: C has the words, attributed back to the row
      // A sent them from.
      final cConv = await c.db.getConversationByPeerDevice(peerA);
      expect(cConv, isNotNull);
      final cRow = (await c.db.getMessages(cConv!.id)).single;
      expect(cRow.content, 'hello across the box');
      expect(cRow.externalMessageId, 'm_${aRow.id}');

      // The delivered receipt made it home without being asked.
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');

      // And a read receipt when C's side is opened.
      final owed = await c.db.readPendingIds(cConv.id);
      expect(owed, ['m_${aRow.id}']);
      await c.transport.ackRead(peerKey: peerA, messageIds: owed);
      await pumpEventQueue();
      await pumpEventQueue();
      expect((await a.db.getMessages(aConv)).single.status, 'read');
    });
  });

  group('I9.17.a — outbound to inbound, across a relay', () {
    test('the message crosses the middle node and comes back the same way',
        () async {
      final a = makeNode(address: 'DEV_A', peerId: peerA);
      final b = makeNode(address: 'DEV_B', peerId: peerB);
      final c = makeNode(address: 'DEV_C', peerId: peerC);

      // A knows only that C is reachable via B; C gets its receipt
      // home the same way.
      a.routes[peerC] = _route(dest: peerC, nextHop: peerB);
      a.devices[peerB] = 'DEV_B';
      a.connected.add(peerB);

      b.routes[peerC] = _route(dest: peerC, nextHop: peerC);
      b.routes[peerA] = _route(dest: peerA, nextHop: peerA);
      b.devices[peerC] = 'DEV_C';
      b.devices[peerA] = 'DEV_A';
      b.connected.add(peerC);
      b.connected.add(peerA);

      c.routes[peerA] = _route(dest: peerA, nextHop: peerB);
      c.devices[peerB] = 'DEV_B';
      c.connected.add(peerB);

      final aConv = await a.db.createConversationWithPeer('C', peerC);

      final result = await a.transport.sendMessage(
        peerDeviceId: peerC,
        conversationId: aConv,
        content: 'via the long road',
      );
      expect(result, TransferResult.delivered);

      await pumpEventQueue();
      await pumpEventQueue();

      // The message went A → B at hop 0 and B → C carrying the hop
      // it spent: the middle node really relayed, it did not merely
      // watch.
      expect(
        wire.crossings,
        containsAllInOrder([
          (from: 'DEV_A', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_C', hops: 1),
        ]),
      );

      // C has it.
      final cConv = await c.db.getConversationByPeerDevice(peerA);
      expect(cConv, isNotNull);
      expect(
        (await c.db.getMessages(cConv!.id)).single.content,
        'via the long road',
      );

      // B was a pipe, not a party: nothing landed in its database.
      expect(await b.db.getConversationByPeerDevice(peerA), isNull);
      expect(await b.db.getConversationByPeerDevice(peerC), isNull);

      // The delivered receipt came home through B as well — hop 1
      // on its way back — and A's row knows it.
      expect(
        wire.crossings,
        containsAllInOrder([
          (from: 'DEV_C', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_A', hops: 1),
        ]),
      );
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');
    });
  });
}
