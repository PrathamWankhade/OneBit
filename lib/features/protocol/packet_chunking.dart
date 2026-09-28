import 'dart:typed_data';

import 'package:onebit/features/protocol/onebit_packet.dart';
import 'package:onebit/features/protocol/packet_codec.dart';
import 'package:onebit/features/protocol/packet_error.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// Marker that opens a chunk slice.
///
/// A slice cannot be mistaken for a whole payload: a legacy
/// `MessageCodec` frame opens with the big-endian length of the external
/// message id (a handful of bytes in practice), an I9 envelope opens
/// with the envelope protocol version (2), and a topology advertisement
/// opens with its own version (1). 0x43 — `'C'` — sits clear of all
/// three, and [isChunkPayload] checks the rest of the framing too.
const int chunkMagic = 0x43;

/// `[magic 1][index 1][count 1][length hi][length lo][slice]`.
///
/// The total length is carried rather than inferred so a slice left over
/// from an abandoned transfer cannot be quietly welded onto a fresh one.
const int chunkHeaderSize = 5;

/// Largest slice that still fits the payload of a single packet.
const int maxChunkSlice = PacketConstants.maxPayloadSize - chunkHeaderSize;

/// Largest payload that can be spread over the 255 slices a one-byte
/// index and count can address.
const int maxChunkedPayload = maxChunkSlice * 255;

/// Whether a packet payload is one slice of something larger.
bool isChunkPayload(List<int> payload) =>
    payload.length > chunkHeaderSize &&
    payload[0] == chunkMagic &&
    payload[2] >= 2 && // a payload that fits is never framed
    payload[1] < payload[2]; // ...and the index sits inside the run

/// The packet payloads that carry [payload].
///
/// A payload that already fits comes back untouched, so everything that
/// worked before this existed still goes out as the exact same bytes and
/// older peers can still read it.
///
/// Throws [ArgumentError] above [maxChunkedPayload] — there is no honest
/// way to carry a payload that does not fit the framing, and silently
/// truncating it is the very bug this exists to fix.
List<Uint8List> splitPayload(List<int> payload) {
  if (payload.length <= PacketConstants.maxPayloadSize) {
    return [Uint8List.fromList(payload)];
  }
  if (payload.length > maxChunkedPayload) {
    throw ArgumentError.value(
      payload.length,
      'payload',
      'exceeds the $maxChunkedPayload bytes chunking can carry',
    );
  }

  final count = (payload.length + maxChunkSlice - 1) ~/ maxChunkSlice;
  final slices = <Uint8List>[];
  for (var index = 0; index < count; index++) {
    final start = index * maxChunkSlice;
    final chunkEnd = start + maxChunkSlice;
    final end = chunkEnd < payload.length ? chunkEnd : payload.length;
    final slice = Uint8List(chunkHeaderSize + (end - start));
    slice[0] = chunkMagic;
    slice[1] = index;
    slice[2] = count;
    slice[3] = (payload.length >> 8) & 0xFF;
    slice[4] = payload.length & 0xFF;
    slice.setRange(chunkHeaderSize, slice.length, payload, start);
    slices.add(slice);
  }
  return slices;
}

/// Sends [payload] as [type] in as many packets as it needs.
///
/// Slices of one message share [packetId] so the receiving end can tell
/// them apart from the message that follows. They are sent one at a time:
/// a link only has room for one transfer in flight, and waiting for each
/// ACK is what keeps a multi-packet message in order.
Future<TransferResult> sendInPackets(
  List<int> payload, {
  required int type,
  required int packetId,
  required Future<TransferResult> Function(Uint8List packetBytes) send,
}) async {
  final List<Uint8List> slices;
  try {
    slices = splitPayload(payload);
  } on ArgumentError {
    return TransferResult.failed;
  }

  for (final slice in slices) {
    final Uint8List packetBytes;
    try {
      packetBytes = PacketCodec.encode(
        OneBitPacket(type: type, packetId: packetId, payload: slice),
      );
    } on PacketDecodeException {
      // Only reachable if a slice outgrew the packet format, which
      // splitPayload already rules out — treat it as hard rather than
      // transient so it is not retried forever.
      return TransferResult.failed;
    }

    final result = await send(packetBytes);
    if (result != TransferResult.delivered) return result;
  }
  return TransferResult.delivered;
}

/// Puts the slices of a chunked payload back together.
///
/// One partial per device. Sends are serialized per link, so a second
/// partial can only mean the first was abandoned — dropping it bounds
/// what a peer can make us hold by never finishing a transfer, and the
/// age check clears anything the link lost halfway.
class PacketChunkReassembler {
  PacketChunkReassembler({this.maxAge = const Duration(seconds: 60)});

  /// How long a half-assembled payload is kept before it is discarded.
  final Duration maxAge;

  final Map<String, _PartialPayload> _partials = {};

  /// Feed the payload of one incoming packet.
  ///
  /// Returns the payload unchanged when it was never chunked, `null`
  /// while slices are still missing, and the whole payload once the last
  /// slice lands.
  Uint8List? accept(String deviceId, int packetId, Uint8List payload) {
    if (!isChunkPayload(payload)) return payload;

    final totalLength = (payload[3] << 8) | payload[4];
    if (totalLength == 0 || totalLength > maxChunkedPayload) return null;

    final count = payload[2];
    final index = payload[1];

    var partial = _partials[deviceId];
    if (partial == null ||
        partial.packetId != packetId ||
        partial.count != count ||
        partial.totalLength != totalLength ||
        DateTime.now().difference(partial.startedAt) > maxAge) {
      partial = _PartialPayload(
        count: count,
        packetId: packetId,
        totalLength: totalLength,
      );
      _partials[deviceId] = partial;
    }

    // Out of range or already held — a retransmit at the transport layer
    // must not be counted twice.
    if (index >= partial.count || partial.slices[index] != null) return null;

    partial.slices[index] = payload.sublist(chunkHeaderSize);
    partial.received += 1;
    if (partial.received < partial.count) return null;

    _partials.remove(deviceId);
    return _join(partial);
  }

  /// Forget everything held for [deviceId].
  void forget(String deviceId) => _partials.remove(deviceId);

  Uint8List _join(_PartialPayload partial) {
    final whole = Uint8List(partial.totalLength);
    var offset = 0;
    // Every index is filled exactly once before this runs, so the nulls
    // below are unreachable — they are here because a fixed list has to
    // be created before the first slice lands.
    for (final slice in partial.slices) {
      if (slice == null) continue;
      whole.setRange(offset, offset + slice.length, slice);
      offset += slice.length;
    }
    return whole;
  }
}

class _PartialPayload {
  _PartialPayload({
    required this.count,
    required this.packetId,
    required this.totalLength,
  }) : slices = List<Uint8List?>.filled(count, null);

  final int count;
  final int packetId;
  final int totalLength;
  final List<Uint8List?> slices;
  int received = 0;
  final DateTime startedAt = DateTime.now();
}
