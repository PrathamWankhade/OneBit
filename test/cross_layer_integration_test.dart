// The cross-layer harness: four devices, one box, the whole stack.
//
// I10.1 walks it end to end. Every earlier multi-device test stops at
// a wall. The multi_peer
// suites prove identity and routing at the state layer, with no
// radio above them; the I9.17 lifecycle tests run real transports
// over a wire, but their routes are handed in by hand. This is the
// seam neither covers: devices that discover each other, push real
// topology advertisements across the wire, learn their routing
// tables from those advertisements, and then carry an end-to-end
// encrypted message multi-hop on the routes they learned — with
// receipts walking home the same way. Nothing in any routing table
// below is installed by the test; the cascade installs it.
//
// I10.2 then holds the same stack still while identity moves under
// it: a key that rotates mid-conversation, an address that changes
// while the identity does not, and a first contact that stays a
// stranger until someone verifies it — each one proven through the
// same hops, not at the state layer.
//
// I10.3 presses on the shelves underneath all of it: queue caps,
// relay holds, retry schedules — every ceiling checked while two
// subsystems are under one partition at once, then drained, so
// bounded separately proves bounded together.
//
// I10.4 then takes the claim to the screen: a radio event, through
// the transport's own facts, to the words under a bubble — every
// state I9.14 defines, each one earned by a real send, a real
// partition, a real receipt, and never staged for the camera.

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart'
    show Icon, Icons, MaterialApp, Size, SizedBox, TextField, ValueKey, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/conversations/presentation/conversation_screen.dart';
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
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<_Device> makeDevice({
    required String address,
    int maxQueuedMessages = MessageTransport.defaultMaxQueuedMessages,
  }) async {
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
      maxQueuedMessages: maxQueuedMessages,
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

  /// A device's X25519 public key as hex — the bytes a peer stores
  /// from an announcement and encrypts to afterwards.
  Future<String> keyHexOf(_Device device) async =>
      IdentityRepository.bytesToHex(
        Uint8List.fromList((await device.xPair.extractPublicKey()).bytes),
      );

  /// Drain the event loop until nothing is moving. The bulk phases
  /// below push hundreds of deliveries through the box — messages
  /// and their receipts, hop after hop — far past the default pump
  /// queue's twenty turns.
  Future<void> settle() => pumpEventQueue(times: 600);

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

  group('I10.2 — identity & trust under the full stack', () {
    test('a key rotated mid-conversation is taken up, not shrugged off',
        () async {
      final a = await makeDevice(address: 'DEV_A');
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');

      await pumpEventQueue();
      await pumpEventQueue();

      // ── Bootstrap: each end learns the other's first key ────
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'before the rotation',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      expect(
        await c.transport.sendMessage(
          peerDeviceId: a.peerId,
          conversationId: cConv.id,
          content: 'my key before the rotation',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final key1 = await keyHexOf(c);
      expect(await a.db.peerKeyAgreementKey(c.peerId), key1);
      expect(await c.db.peerKeyAgreementKey(a.peerId), await keyHexOf(a));

      // ── The rotation ────────────────────────────────────────
      // C gets a fresh X25519 pair. Its Ed25519 identity — the
      // name every envelope and announcement carries — does not
      // move with it.
      await c.rotateKeyAgreement();
      final key2 = await keyHexOf(c);
      expect(key2, isNot(key1)); // a real rotation, not the same bytes

      expect(
        await c.transport.sendMessage(
          peerDeviceId: a.peerId,
          conversationId: cConv.id,
          content: 'after the rotation',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      // The new key arrived signed by the same identity and
      // replaced the old one: A now holds what C encrypts with,
      // not what C used to.
      expect(await a.db.peerKeyAgreementKey(c.peerId), key2);

      // The words that rode alongside it still opened at A — the
      // rotation broke no conversation on the way through B.
      final rotatedArrival = (await a.db.getMessages(aConv)).singleWhere(
        (row) => row.content == 'after the rotation',
      );
      expect(rotatedArrival.isEncrypted, 1);

      // ── Talk to the new key ─────────────────────────────────
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'sealed to the new key',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      // C's own transport — the one holding the rotated pair —
      // opened it. A's encryption followed the rotation.
      final sealed = (await c.db.getMessages(cConv.id)).singleWhere(
        (row) => row.content == 'sealed to the new key',
      );
      expect(sealed.isEncrypted, 1);
    });

    test('a new BLE address carries the same identity across every hop',
        () async {
      final a = await makeDevice(address: 'DEV_A');
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');

      await pumpEventQueue();
      await pumpEventQueue();

      // ── Bootstrap, both directions, so both ends hold keys ──
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'hello from the old address',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      expect(
        await c.transport.sendMessage(
          peerDeviceId: a.peerId,
          conversationId: cConv.id,
          content: 'and back through the relay',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(await a.db.peerKeyAgreementKey(c.peerId), isNotNull);

      // ── The address rotates ─────────────────────────────────
      final before = wire.crossings.length;
      a.moveRadio(wire.radioFor('DEV_A2'));
      // The neighbour table re-resolves the SAME peer id to the
      // new address — the update production performs when a peer
      // reconnects from a new MAC.
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A2');
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        b.neighbors.neighbors
            .singleWhere((entry) => entry.peerId == a.peerId)
            .bleDeviceId,
        'DEV_A2',
      );
      // The whole device moved, radio and router together: A's own
      // advertisement now leaves from the new address.
      expect(
        wire.packets,
        contains(
          (
            from: 'DEV_A2',
            to: 'DEV_B',
            type: PacketType.topologyAdvertisement,
          ),
        ),
      );

      // ── Traffic, both ways, on the new address ──────────────
      // C answers: the route's next hop is still B, and B hands
      // the last leg to the new address — never the old one.
      expect(
        await c.transport.sendMessage(
          peerDeviceId: a.peerId,
          conversationId: cConv.id,
          content: 'at the new address',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final afterArrival = wire.crossings.sublist(before);
      expect(
        afterArrival,
        containsAllInOrder([
          (from: 'DEV_C', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_A2', hops: 1),
        ]),
      );
      // It arrived in the same thread, under the same identity,
      // still sealed: the address changed, the peer did not.
      final arrival = (await a.db.getMessages(aConv))
          .singleWhere((row) => row.content == 'at the new address');
      expect(arrival.isEncrypted, 1);

      // And A speaks from the new address too.
      final afterReply = wire.crossings.length;
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'out from the new address',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        wire.crossings.sublist(afterReply),
        containsAllInOrder([
          (from: 'DEV_A2', to: 'DEV_B', hops: 0),
          (from: 'DEV_B', to: 'DEV_C', hops: 1),
        ]),
      );
      expect(
        (await c.db.getMessages(cConv.id))
            .singleWhere((row) => row.content == 'out from the new address')
            .isEncrypted,
        1,
      );

      // Nothing post-rotation ever went to the address A left
      // behind.
      expect(
        wire.crossings.sublist(before).where((leg) => leg.to == 'DEV_A'),
        isEmpty,
      );
    });

    test('first contact through the relay stays a stranger until verified',
        () async {
      final a = await makeDevice(address: 'DEV_A');
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');

      await pumpEventQueue();
      await pumpEventQueue();

      // First contact, two hops out of A's store and into C's.
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'a stranger writes',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      // ── What trust-on-first-use actually creates ────────────
      final firstContact = await c.db.getPeerIdentityByIdentityId(a.peerId);
      expect(firstContact, isNotNull);
      expect(firstContact!.identityId, a.peerId);
      expect(firstContact.displayName, 'Unknown');
      // The identity IS the key: this row's public key is the very
      // name the announcement's signature was checked against.
      expect(firstContact.publicKey, a.peerId);
      expect(firstContact.keyAgreementPublicKey, isNotNull);
      // A message — even one that decrypts — is not a handshake:
      // nothing here is verified, and the trust ledger is empty.
      expect(firstContact.trustState, 'unknown');
      expect(await c.db.loadAllTrust(), isEmpty);

      // ── The verification, through the production path ───────
      // Scanning A's QR is a local act, but it lands on the row
      // the mesh delivered, against the identity the mesh named.
      final trust = TrustService(IdentityRepository(c.db));
      trust.verifyIdentity(
        peerIdentityId: a.peerId,
        at: DateTime.now(),
        publicKeyHex: a.peerId,
        method: VerificationMethod.qrScan,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      expect(trust.isVerified(a.peerId), isTrue);
      final ledger = await c.db.loadAllTrust();
      expect(ledger, hasLength(1));
      expect(ledger.single.peerIdentityId, a.peerId);
      expect(ledger.single.trustState, 'verified');
      expect(ledger.single.verificationMethod, 'qrScan');
      expect(
        (await c.db.getPeerIdentityByIdentityId(a.peerId))!.trustState,
        'verified',
      );

      // ── And the conversation with the now-known peer goes on ─
      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      expect(
        await c.transport.sendMessage(
          peerDeviceId: a.peerId,
          conversationId: cConv.id,
          content: 'known now, still encrypted',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final reply = (await a.db.getMessages(aConv)).singleWhere(
        (msg) => msg.content == 'known now, still encrypted',
      );
      expect(reply.isEncrypted, 1);
      // Verification changed what C thinks of A. It touched no key
      // and put no extra byte on the wire.
      expect(await c.db.peerKeyAgreementKey(a.peerId), await keyHexOf(a));
    });
  });

  group('I10.3 — resource limits under pressure', () {
    test('the outbox is a fixed shelf: the partition fills it, healing '
        'drains it', () async {
      const shelf = 64;
      const flood = shelf + 10;

      final a = await makeDevice(address: 'DEV_A', maxQueuedMessages: shelf);
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');

      await pumpEventQueue();
      await pumpEventQueue();

      // Baseline: the road is open.
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'baseline',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();
      expect(await c.db.select(c.db.messages).get(), hasLength(1));

      // ── Partition: A's first hop closes. ────────────────────
      wire.down.add('DEV_B');

      final results = <TransferResult>[];
      for (var i = 0; i < flood; i++) {
        results.add(await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'flood #$i',
        ));
      }
      await settle();

      // Every attempt told the truth — the road was closed — and
      // left its row on the shelf for a later pass rather than
      // losing it or declaring it dead.
      expect(results.every((r) => r == TransferResult.failed), isTrue);

      // The shelf holds exactly its cap: nothing grew behind it.
      final waiting = await a.db.allQueuedMessages();
      expect(waiting, hasLength(shelf));

      // Exactly what ran off the front is written off: ten rows,
      // kept as history, not queued as work.
      final aRows = await a.db.getMessages(aConv);
      expect(aRows, hasLength(flood + 1));
      expect(
        aRows.where((m) => m.status == 'queued'),
        hasLength(shelf),
      );
      expect(aRows.where((m) => m.status == 'expired'), hasLength(10));

      // The in-memory retry schedules never outnumber the shelf:
      // an entry per waiting row, none for the ten written off.
      for (final row in waiting) {
        expect(a.transport.retryAttemptsOf(row.id), greaterThanOrEqualTo(1));
        expect(a.transport.nextRetryAt(row.id), isNotNull);
      }
      for (final row in aRows.where((m) => m.status == 'expired')) {
        expect(a.transport.retryAttemptsOf(row.id), 0);
        expect(a.transport.nextRetryAt(row.id), isNull);
      }

      // The partition leaked nothing sideways: the relay's database
      // is untouched and the far end saw only the baseline.
      expect(await b.db.select(b.db.messages).get(), isEmpty);
      expect(await c.db.select(c.db.messages).get(), hasLength(1));

      // ── Heal: the road reopens and the shelf drains. ────────
      wire.down.remove('DEV_B');
      // One flush pass moves a batch of fifty — the same
      // backpressure the retry tick applies in production — so the
      // shelf empties pass by pass, each pass bounded so a wedged
      // row can never spin this loop.
      for (var pass = 0; pass < 4; pass++) {
        await a.transport.flushQueued();
        if ((await a.db.allQueuedMessages()).isEmpty) break;
      }
      await settle();

      expect(await a.db.allQueuedMessages(), isEmpty);
      final drained = await a.db.getMessages(aConv);
      expect(drained.where((m) => m.status == 'queued'), isEmpty);
      expect(drained.where((m) => m.status == 'expired'), hasLength(10));

      // The shelf's memory went with the rows: no schedule lingers
      // for anything settled or written off.
      for (final row in drained) {
        expect(a.transport.retryAttemptsOf(row.id), 0);
        expect(a.transport.nextRetryAt(row.id), isNull);
      }

      // The far end received exactly the newest sixty-four — and
      // never the ten written off the front. Nothing revives.
      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      final cContents =
          (await c.db.getMessages(cConv.id)).map((m) => m.content).toSet();
      expect(cContents, hasLength(shelf + 1)); // baseline + the shelf
      for (var i = 0; i < 10; i++) {
        expect(cContents, isNot(contains('flood #$i')));
      }
      for (var i = 10; i < flood; i++) {
        expect(cContents, contains('flood #$i'));
      }
    });

    test('one partition presses two shelves at once — memory at the '
        'relay, disk at the outbox', () async {
      const shelf = 64;
      const flood = shelf + 10;

      final a = await makeDevice(address: 'DEV_A');
      final b = await makeDevice(address: 'DEV_B');
      final c = await makeDevice(address: 'DEV_C');
      final d = await makeDevice(address: 'DEV_D', maxQueuedMessages: shelf);

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      c.neighbors.addNeighbor(d.peerId, bleDeviceId: 'DEV_D');
      d.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');

      await pumpEventQueue();
      await pumpEventQueue();

      // Baselines: both roads open before the cut — A's words
      // cross the whole chain to C, D's ride through C to B.
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      expect(
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'baseline',
        ),
        TransferResult.delivered,
      );
      final dConv = await d.db.createConversationWithPeer('B', b.peerId);
      expect(
        await d.transport.sendMessage(
          peerDeviceId: b.peerId,
          conversationId: dConv,
          content: 'baseline',
        ),
        TransferResult.delivered,
      );
      await pumpEventQueue();
      await pumpEventQueue();
      expect(await c.db.select(c.db.messages).get(), hasLength(1));
      expect(await b.db.select(b.db.messages).get(), hasLength(1));

      // ── One partition closes the B—C leg. ───────────────────
      wire.down.add('DEV_C');

      // A's flood sails as far as B — the mesh accepted every one,
      // A's rows say so — and B, unable to pass them on, holds the
      // forwarded envelopes in memory, capped at the relay's own
      // shelf of sixty-four.
      final aResults = <TransferResult>[];
      for (var i = 0; i < flood; i++) {
        aResults.add(await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'from A #$i',
        ));
      }

      // D's own flood cannot leave the house — its first hop IS
      // the dead leg — so those rows fill the disk shelf instead,
      // under the same outbox cap.
      final dResults = <TransferResult>[];
      for (var i = 0; i < flood; i++) {
        dResults.add(await d.transport.sendMessage(
          peerDeviceId: b.peerId,
          conversationId: dConv,
          content: 'from D #$i',
        ));
      }
      await settle();

      expect(aResults.every((r) => r == TransferResult.delivered), isTrue);
      expect(dResults.every((r) => r == TransferResult.failed), isTrue);

      // Memory shelf: exactly the cap, oldest gone — and held
      // envelopes never became rows: B's database holds only its
      // own baseline conversation.
      expect(b.relay.pendingForwardCount, shelf);
      expect(await b.db.select(b.db.messages).get(), hasLength(1));

      // A's shelf never engaged: its own hop was open.
      expect(await a.db.allQueuedMessages(), isEmpty);

      // Disk shelf: exactly the cap queued, ten written off the
      // front as history.
      expect(await d.db.allQueuedMessages(), hasLength(shelf));
      final dRows = await d.db.getMessages(dConv);
      expect(dRows, hasLength(flood + 1));
      expect(dRows.where((m) => m.status == 'expired'), hasLength(10));

      // The far side of the cut saw nothing new.
      expect(await c.db.select(c.db.messages).get(), hasLength(1));

      // ── Heal: both shelves drain to nothing. ────────────────
      wire.down.remove('DEV_C');
      await b.relay.retryDueForwards();
      // The outbox drains in batches of fifty — bounded passes,
      // the way production empties it a tick at a time.
      for (var pass = 0; pass < 4; pass++) {
        await d.transport.flushQueued();
        if ((await d.db.allQueuedMessages()).isEmpty) break;
      }
      await settle();

      expect(b.relay.pendingForwardCount, 0);
      expect(await d.db.allQueuedMessages(), isEmpty);

      // C received A's newest sixty-four — the ten that fell off
      // B's memory shelf never arrived.
      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      final cContents =
          (await c.db.getMessages(cConv.id)).map((m) => m.content).toSet();
      expect(
        cContents.where((s) => s.startsWith('from A #')),
        hasLength(shelf),
      );
      for (var i = 0; i < 10; i++) {
        expect(cContents, isNot(contains('from A #$i')));
      }
      for (var i = 10; i < flood; i++) {
        expect(cContents, contains('from A #$i'));
      }

      // And B received D's newest sixty-four: the ten written off
      // the back of D's disk shelf stayed written off.
      final bConv = (await b.db.getConversationByPeerDevice(d.peerId))!;
      final bContents =
          (await b.db.getMessages(bConv.id)).map((m) => m.content).toSet();
      expect(
        bContents.where((s) => s.startsWith('from D #')),
        hasLength(shelf),
      );
      for (var i = 0; i < 10; i++) {
        expect(bContents, isNot(contains('from D #$i')));
      }
      for (var i = 10; i < flood; i++) {
        expect(bContents, contains('from D #$i'));
      }
    });
  });

  group('I10.4 — truthful status, radio to bubble', () {
    late _Device a;
    late _Device b;
    late _Device c;
    late SharedPreferences prefs;

    // A shelf of four keeps the whole thread on one screen: the
    // assertions here are about words under bubbles, and a word
    // scrolled out of the list is a word the test cannot see.
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    /// The mesh, built inside the test's own zone.
    ///
    /// A device constructed in `setUp` subscribes to the wire in the
    /// real zone; a widget test pumps a fake clock, and the callbacks
    /// that zone owns stop being serviced part-way through the test.
    /// Built here, every subscription lives on the clock the test
    /// drives, and each delivery is answered by the same pump that
    /// caused it.
    Future<void> buildMesh(WidgetTester tester) async {
      a = await makeDevice(address: 'DEV_A', maxQueuedMessages: 4);
      b = await makeDevice(address: 'DEV_B');
      c = await makeDevice(address: 'DEV_C');

      a.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');
      b.neighbors.addNeighbor(a.peerId, bleDeviceId: 'DEV_A');
      b.neighbors.addNeighbor(c.peerId, bleDeviceId: 'DEV_C');
      c.neighbors.addNeighbor(b.peerId, bleDeviceId: 'DEV_B');

      // The advertisements cross on these turns; nothing is installed
      // by hand, the cascade is. Bounded like every other wait here:
      // the test asks for the routes it needs, not for a settled app.
      for (var i = 0;
          i < 60 &&
              (a.routing.bestRoute(c.peerId) == null ||
                  c.routing.bestRoute(a.peerId) == null);
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(a.routing.bestRoute(c.peerId), isNotNull);
      expect(c.routing.bestRoute(a.peerId), isNotNull);
    }

    /// The real conversation screen over one real device's stack —
    /// the same providers production binds, pointed at the harness
    /// device instead of at the phone.
    Widget chatScreen({
      required AppDatabase db,
      required MessageTransport transport,
      required VirtualRadio radio,
      required int conversationId,
    }) {
      final settings = SettingsRepository(prefs);
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          messageTransportProvider.overrideWithValue(transport),
          bleServiceProvider.overrideWithValue(radio),
          settingsRepositoryProvider.overrideWithValue(settings),
          settingsRepositoryInitProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          // Keyed by the database, because this harness swaps devices
          // under a structurally identical tree. Without a key Flutter
          // updates the old element instead of building a new one, and
          // `initState` — where opening a thread acknowledges it — runs
          // for the first device only.
          home: ConversationScreen(
            key: ValueKey<AppDatabase>(db),
            conversationId: conversationId,
          ),
        ),
      );
    }

    /// The tree goes before the stack does: the screen's listeners
    /// are cancelled before the transports they listen to close, and
    /// the devices leave the shared list so the outer teardown has
    /// nothing left to dispose a second time.
    Future<void> quiesce(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      // drift closes a cancelled query stream on a zero timer: give
      // those turns the clock before declaring the tree down.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      for (final device in [...devices]) {
        // Every timer and listener stops here, in the fake clock
        // that owns them. The drift handle is different: its close
        // waits on stream cancellations that the same clock must
        // run, so awaiting it from inside the test deadlocks the
        // zone — and the suite's own timeout lives in that clock,
        // which is why a hang here never times out. It is closed
        // without being awaited; the in-memory file goes with the
        // process either way.
        device.router.dispose();
        device.neighbors.dispose();
        device.transport.dispose();
        unawaited(device.db.close());
      }
      devices.clear();
      await tester.pump(const Duration(milliseconds: 1));
    }

    /// Pump in bounded steps until [condition] holds. No unbounded
    /// settle: every wait here is a number the test can name, and a
    /// state that never arrives fails the assertion that follows
    /// instead of hanging the suite.
    Future<void> pumpUntilTrue(
      WidgetTester tester,
      bool Function() condition, {
      int steps = 60,
      Duration step = const Duration(milliseconds: 250),
    }) async {
      for (var i = 0; i < steps; i++) {
        if (condition()) return;
        await tester.pump(step);
      }
    }

    /// The same bounded wait, expressed as "until this is on screen".
    Future<void> pumpUntil(
      WidgetTester tester,
      Finder finder, {
      int steps = 60,
      Duration step = const Duration(milliseconds: 250),
    }) =>
        pumpUntilTrue(
          tester,
          () => finder.evaluate().isNotEmpty,
          steps: steps,
          step: step,
        );

    testWidgets(
        'every step of a real send earns its word on the bubble — '
        'queued, sending, relayed, delivered, read', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await buildMesh(tester);

      // ── Queued: the composer writes a row with no road to try.
      // No attempt, no schedule — the outbox's own first state.
      final roadless = await a.db.createConversation('Nobody yet');
      await tester.pumpWidget(
        chatScreen(
          db: a.db,
          transport: a.transport,
          radio: a.radio,
          conversationId: roadless,
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'nothing to aim at');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.text('Queued'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      // ── Sending: a real attempt, really in the air. The wire is
      // held open for this one send so the frame can catch it
      // there; everything the frame shows is the transport's own
      // transmitting flag, not a staged state.
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      await tester.pumpWidget(
        chatScreen(
          db: a.db,
          transport: a.transport,
          radio: a.radio,
          conversationId: aConv,
        ),
      );
      await tester.pump();

      // The receipt's way home is shut, the ring's way out is not:
      // A's words reach C, C's receipt reaches B, and B cannot hand
      // it to A. Handed off is not arrived, and this is that gap.
      wire.down.add('DEV_A');
      wire.gate = Completer<void>();
      await tester.enterText(find.byType(TextField), 'does this road work');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);

      // The same send is released, not replaced: the bytes that
      // were in the air are the bytes that land.
      wire.gate!.complete();
      wire.gate = null;
      await tester.pump();

      // ── Relayed: the neighbour's radio took it. Handed off is
      // not arrived, and the thread says neither.
      await pumpUntil(tester, find.byIcon(Icons.done));
      expect(find.text('Sending…'), findsNothing);
      expect(find.byIcon(Icons.done), findsOneWidget);
      // The bubble's word is the row's word, not a second opinion.
      expect(
        (await a.db.getMessages(aConv)).map((m) => m.status),
        ['sent'],
      );

      // ── Delivered: the road home reopens and B hands over the
      // receipt it was holding — the same bytes, finally arrived.
      // Until then the thread said done, and done was true: the
      // neighbour had it, the far end had not said so.
      expect(find.byIcon(Icons.done_all), findsNothing);
      wire.down.remove('DEV_A');
      await b.relay.retryDueForwards();
      await tester.pump();
      await pumpUntil(tester, find.byIcon(Icons.done_all));
      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(
        (await a.db.getMessages(aConv)).map((m) => m.status),
        ['delivered'],
      );

      // ── Read: C opens the thread. The ack that leaves is the
      // production path — _markConversationRead → ackRead — and it
      // crosses the wire like any other message.
      final cConv = (await c.db.getConversationByPeerDevice(a.peerId))!;
      // What C owes an answer for before the thread is opened …
      expect(await c.db.readPendingIds(cConv.id), isNotEmpty);
      await tester.pumpWidget(
        chatScreen(
          db: c.db,
          transport: c.transport,
          radio: c.radio,
          conversationId: cConv.id,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // ack leaves C
      // … and nothing after: opening the thread is what answers it.
      expect(await c.db.readPendingIds(cConv.id), isEmpty);

      await tester.pumpWidget(
        chatScreen(
          db: a.db,
          transport: a.transport,
          radio: a.radio,
          conversationId: aConv,
        ),
      );
      await tester.pump();
      await pumpUntilTrue(
        tester,
        () => tester
            .widgetList<Icon>(find.byIcon(Icons.done_all))
            .any((icon) => icon.color == AppTheme.accent),
      );
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.done_all)).color,
        AppTheme.accent,
      );
      expect(
        (await a.db.getMessages(aConv)).map((m) => m.status),
        ['read'],
      );

      await quiesce(tester);
    });

    testWidgets(
        'the unhappy words come from failures the wire really had — '
        'retrying, expired, failed', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await buildMesh(tester);
      final aConv = await a.db.createConversationWithPeer('C', c.peerId);
      await tester.pumpWidget(
        chatScreen(
          db: a.db,
          transport: a.transport,
          radio: a.radio,
          conversationId: aConv,
        ),
      );
      await tester.pump();

      // ── Retrying: the first hop is gone, the attempt failed,
      // and a backoff is set — so the bubble waits out loud. The
      // composer says so too: its own report does not flatter.
      wire.down.add('DEV_B');
      await tester.enterText(find.byType(TextField), 'where did the road go');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.text('Retrying'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      expect(find.text('Failed to send message'), findsOneWidget);

      // ── Expired: four more against a shelf of four — the oldest
      // row is written off as history while the partition stands,
      // and the rows behind it keep waiting.
      for (var i = 0; i < 4; i++) {
        await a.transport.sendMessage(
          peerDeviceId: c.peerId,
          conversationId: aConv,
          content: 'more #$i',
        );
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Expired — never reached recipient'), findsOneWidget);
      expect(find.byIcon(Icons.timer_off), findsOneWidget);
      expect(find.text('Retrying'), findsWidgets);

      // ── Failed: a message the codec refuses to carry. No retry
      // could fix it, so none is offered.
      await a.transport.sendMessage(
        peerDeviceId: c.peerId,
        conversationId: aConv,
        content: 'x' * 4001,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await quiesce(tester);
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
    required this.maxQueuedMessages,
  });

  String address;
  final String peerId;
  VirtualRadio radio;

  /// The device's own identity: X25519 for encryption, Ed25519 for
  /// signing the announcements that carry the encryption key. The
  /// X25519 half is the one that can rotate (I10.2); the Ed25519
  /// half IS the peer id and never moves.
  SimpleKeyPair xPair;
  final SimpleKeyPair edPair;

  final MockPeerReachability reachability;

  /// I10.3 — how many rows this device's outbox will hold before it
  /// starts writing the oldest off. A constructor knob on the real
  /// transport, so a test can flood a shelf of sixty-four instead of
  /// a thousand.
  final int maxQueuedMessages;

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

  late MeshRouter router = _buildRouter();

  MeshRouter _buildRouter() => MeshRouter(
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

  late MessageRelayService relay;
  late MessageTransport transport = _buildTransport();

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
      maxQueuedMessages: maxQueuedMessages,
      localKeyAgreement: () async => xPair,
      localSign: (message) async => Uint8List.fromList(
        (await Ed25519().sign(message, keyPair: edPair)).bytes,
      ),
    );
    built.startListening();
    return built;
  }

  /// A fresh X25519 pair — the rotation production performs when a
  /// device's key-agreement key changes. The transport is rebuilt
  /// around it, so the next send announces the new key exactly the
  /// way a first send announces an old one.
  Future<void> rotateKeyAgreement() async {
    transport.dispose();
    xPair = await X25519().newKeyPair();
    transport = _buildTransport();
  }

  /// The radio moves to a new BLE address — the MAC rotation an OS
  /// hands a device. The identity walks with it: same peer id, same
  /// routes, same threads; only the air address changes, and every
  /// layer above the radio keeps working without being told.
  void moveRadio(VirtualRadio newRadio) {
    transport.dispose();
    router.dispose();
    address = newRadio.address;
    radio = newRadio;
    router = _buildRouter();
    router.start();
    transport = _buildTransport();
  }

  Future<void> dispose() async {
    router.dispose();
    neighbors.dispose();
    transport.dispose();
    await db.close();
  }
}
