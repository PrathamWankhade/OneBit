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

  /// Addresses whose radio is out of the air: a send to them fails
  /// the way a link that went away fails — refused, not thrown.
  final Set<String> down = {};

  /// Every envelope that crossed, in order: (from, to, hop count).
  final List<({String from, String to, int hops})> crossings = [];

  /// What actually reached an inbox, kept whole so a test can put
  /// one copy back on the wire by hand.
  final List<({String from, String to, List<int> payload})> deliveries = [];

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
    if (inbox == null || down.contains(to)) {
      return TransferResult.failed; // no such radio, or it went away
    }

    final packet = PacketCodec.decode(Uint8List.fromList(payload));
    if (packet.type == PacketType.message) {
      final envelope = MessageEnvelopeCodec.decode(
        Uint8List.fromList(packet.payload),
      );
      crossings.add((from: from, to: to, hops: envelope.hopCount));
    }
    deliveries.add((from: from, to: to, payload: payload));

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

  /// The transport's relay, kept reachable so a test can drive
  /// held-forward retries by hand. Zero backoff: the timer is never
  /// started here, and a hold should be due the moment we ask.
  late final MessageRelayService relay;

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
    relay = MessageRelayService(
      localPeerId: peerId,
      transmissionService: transmission,
      retryBaseBackoff: Duration.zero,
    );
    final built = MessageTransport(
      bleService: ble,
      database: db,
      localPeerId: peerId,
      relayService: relay,
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

  group('I9.17.b — offline, recovery, and a replayed copy', () {
    test('a message waits out its peer being away, and a replay changes nothing',
        () async {
      final a = makeNode(address: 'DEV_A', peerId: peerA);
      final c = makeNode(address: 'DEV_C', peerId: peerC);

      a.routes[peerC] = _route(dest: peerC, nextHop: peerC);
      a.devices[peerC] = 'DEV_C';
      a.connected.add(peerC);

      c.routes[peerA] = _route(dest: peerA, nextHop: peerA);
      c.devices[peerA] = 'DEV_A';
      c.connected.add(peerA);

      // C's radio goes out of the air before A has anything to say.
      wire.down.add('DEV_C');

      final aConv = await a.db.createConversationWithPeer('C', peerC);
      final result = await a.transport.sendMessage(
        peerDeviceId: peerC,
        conversationId: aConv,
        content: 'you were out',
      );

      // Offline: the send fails honestly, and the words wait in the
      // outbox rather than being written off.
      expect(result, TransferResult.failed);
      final waiting = (await a.db.getMessages(aConv)).single;
      expect(waiting.status, 'queued');
      expect(waiting.content, 'you were out');

      // The radio comes back; the outbox takes it out on its own
      // next pass.
      wire.down.remove('DEV_C');
      await a.transport.flushQueued();
      await pumpEventQueue();
      await pumpEventQueue();

      final cConv = await c.db.getConversationByPeerDevice(peerA);
      expect(cConv, isNotNull);
      expect(
        (await c.db.getMessages(cConv!.id)).single.content,
        'you were out',
      );
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');

      // The link's own echo of what it carried — the same packet,
      // once more — changes nothing downstream: one row, and the
      // sender hears from C exactly once.
      final copiesToC = wire.deliveries
          .where((d) => d.to == 'DEV_C')
          .toList(growable: false);
      expect(copiesToC, hasLength(1));
      final receiptsFromC =
          wire.crossings.where((x) => x.from == 'DEV_C').length;
      expect(receiptsFromC, 1);

      await wire.send(
        from: 'DEV_A',
        to: 'DEV_C',
        payload: copiesToC.single.payload,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect((await c.db.getMessages(cConv.id)).length, 1);
      expect(
        wire.crossings.where((x) => x.from == 'DEV_C').length,
        receiptsFromC,
      );
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');
    });

    test('a forward the relay held lands once the road opens', () async {
      final a = makeNode(address: 'DEV_A', peerId: peerA);
      final b = makeNode(address: 'DEV_B', peerId: peerB);
      final c = makeNode(address: 'DEV_C', peerId: peerC);

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

      // The last leg's radio dies after A has handed the message
      // to B.
      wire.down.add('DEV_C');

      final aConv = await a.db.createConversationWithPeer('C', peerC);
      final result = await a.transport.sendMessage(
        peerDeviceId: peerC,
        conversationId: aConv,
        content: 'held at the middle',
      );

      // A's hop succeeded — past B is B's business now.
      expect(result, TransferResult.delivered);
      expect((await a.db.getMessages(aConv)).single.status, 'sent');

      await pumpEventQueue();

      // B tried and could not: the envelope waits on B's hold,
      // C's database has nothing, and nobody has any receipt to
      // send.
      expect(b.relay.pendingForwardCount, 1);
      expect(await c.db.getConversationByPeerDevice(peerA), isNull);

      // The road reopens; the hold takes its retry by hand.
      wire.down.remove('DEV_C');
      await b.relay.retryDueForwards();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(b.relay.pendingForwardCount, 0);
      final cConv = await c.db.getConversationByPeerDevice(peerA);
      expect(cConv, isNotNull);
      expect(
        (await c.db.getMessages(cConv!.id)).single.content,
        'held at the middle',
      );

      // B was still only a pipe, and the receipt walked back
      // through it to A's row.
      expect(await b.db.getConversationByPeerDevice(peerA), isNull);
      expect((await a.db.getMessages(aConv)).single.status, 'delivered');
    });
  });
}
