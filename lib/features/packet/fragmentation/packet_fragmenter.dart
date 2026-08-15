import 'dart:convert';

import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';

/// A serialized wire frame ready for the mesh layer: the fragment [packet]
/// plus its exact [bytes].
final class PacketWireFrame {
  const PacketWireFrame({required this.packet, required this.bytes});

  final Packet packet;
  final List<int> bytes;
}

/// Result of sizing a logical packet for the wire.
final class PacketFraming {
  const PacketFraming({required this.frames, required this.fragmented});

  /// One frame when the packet fits, otherwise one frame per fragment.
  final List<PacketWireFrame> frames;

  /// True when [frames] holds more than one fragment.
  final bool fragmented;
}

/// Splits a logical packet into wire frames within an MTU budget.
///
/// Fragmentation is end-to-end: the destination's reassembly engine joins
/// the frames by `(source, sequence, fragmentId)`; the mesh layer never
/// sees the split. The parent signature travels on fragment 0 only.
final class PacketFragmenter {
  PacketFragmenter({required this.serializer});

  final PacketSerializer serializer;

  /// Sizes [packet] into frames that each serialize within [mtu] bytes.
  ///
  /// A packet whose payload fits serializes as a single, un-fragmented
  /// frame. A payload larger than the budget is split into chunks of
  /// `mtu - overhead` bytes; the run gets a fresh [fragmentId] seed.
  PacketFraming frame(Packet packet, {required int mtu, int? fragmentId}) {
    final sourceBytes = utf8.encode(packet.header.source).length;
    final destinationBytes = utf8.encode(packet.header.destination).length;
    final overhead = serializer.fixedOverhead(
      sourceBytes: sourceBytes,
      destinationBytes: destinationBytes,
    );

    final payload = packet.payload.bytes;
    final capacity = mtu - overhead;
    if (payload.length <= capacity) {
      return PacketFraming(frames: [_encodeWith(packet)], fragmented: false);
    }

    if (capacity <= 0) {
      throw ArgumentError.value(mtu, 'mtu', 'smaller than the frame overhead');
    }

    final count = (payload.length + capacity - 1) ~/ capacity;
    final seed = fragmentId ?? _nextSeed++;
    final frames = <PacketWireFrame>[];
    for (var i = 0; i < count; i++) {
      final start = i * capacity;
      final end = (start + capacity).clamp(0, payload.length);
      final chunk = payload.sublist(start, end);
      final fragment = Packet(
        header: packet.header.copyWith(
          flags: {...packet.header.flags, PacketFlag.fragmented},
          fragmentId: seed,
          fragmentIndex: i,
          fragmentCount: count,
        ),
        payload: packet.payload.withBytes(chunk),
        signature: i == 0 ? packet.signature : const [],
      );
      frames.add(
        PacketWireFrame(packet: fragment, bytes: _encodeOrThrow(fragment)),
      );
    }
    return PacketFraming(frames: frames, fragmented: true);
  }

  PacketWireFrame _encodeWith(Packet packet) {
    return PacketWireFrame(packet: packet, bytes: _encodeOrThrow(packet));
  }

  List<int> _encodeOrThrow(Packet packet) {
    return serializer
        .encode(packet)
        .fold<List<int>>(
          (bytes) => bytes,
          (failure) => throw StateError(failure.toString()),
        );
  }

  int _nextSeed = 1;
}
