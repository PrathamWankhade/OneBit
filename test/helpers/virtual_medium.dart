// The shared radio for cross-device tests: an in-process medium
// whose only trick is that bytes leave one node's sendReliable and
// land in another's inbox — exactly what the BLE layer promises.
// Everything above it (transports, relays, routers, databases) is
// real; only the air is simulated.

import 'dart:async';
import 'dart:typed_data';

import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/message/models/message_envelope_codec.dart';
import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_chunking.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// One radio medium in a box: addresses are BLE device ids, and a
/// send lands in the addressee's inbox as though the stack had
/// delivered it.
///
/// Every inbox is a **synchronous** broadcast stream on purpose. An
/// asynchronous controller delivers in the zone it was created in, and
/// a harness built in `setUp` lives in the real zone while a widget
/// test body pumps a fake clock — deliveries between the two stop
/// being serviced mid-test. Synchronous delivery runs in the caller's
/// zone, so whoever sends is the one being answered.
class VirtualWire {
  final Map<String, StreamController<ReliableDataReceived>> _inboxes = {};

  /// Addresses whose radio is out of the air: a send to them fails
  /// the way a link that went away fails — refused, not thrown.
  final Set<String> down = {};

  /// When set, every send waits for this to complete before the
  /// bytes leave. A widget test holds the air open for a moment so
  /// the frame can catch a send in flight, then releases it: one
  /// send, one gate, and not a wall-clock millisecond involved —
  /// a real delay here would be a real timer, invisible to the
  /// fake clock a widget test pumps.
  Completer<void>? gate;

  /// Every message envelope that crossed, in order: (from, to, hop count).
  final List<({String from, String to, int hops})> crossings = [];

  /// Every packet that crossed, in order: (from, to, packet type) —
  /// topology advertisements and all. The layer that traffic above
  /// the radio cannot see is visible here.
  final List<({String from, String to, int type})> packets = [];

  /// What actually reached an inbox, kept whole so a test can put
  /// one copy back on the wire by hand.
  final List<({String from, String to, List<int> payload})> deliveries = [];

  int _transferId = 0;

  /// The radio a node at [address] talks through. Registers the
  /// inbox first, so anything sent to this address has somewhere
  /// to land.
  VirtualRadio radioFor(String address) {
    final inbox = _inboxes.putIfAbsent(
      address,
      () => StreamController<ReliableDataReceived>.broadcast(sync: true),
    );
    return VirtualRadio(this, address, inbox.stream);
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

    final held = gate;
    if (held != null) await held.future;

    final packet = PacketCodec.decode(Uint8List.fromList(payload));
    packets.add((from: from, to: to, type: packet.type));
    // A chunk slice is not a whole envelope: it carries part of one,
    // and decoding it eagerly would throw on every multi-packet send.
    if (packet.type == PacketType.message && !isChunkPayload(packet.payload)) {
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
class VirtualRadio extends BleService {
  VirtualRadio(this._wire, this.address, this._inbox);

  final VirtualWire _wire;
  final String address;
  final Stream<ReliableDataReceived> _inbox;

  @override
  Stream<ReliableDataReceived> get reliableDataReceived => _inbox;

  @override
  Future<TransferResult> sendReliable(String deviceId, List<int> payload) =>
      _wire.send(from: address, to: deviceId, payload: payload);
}
