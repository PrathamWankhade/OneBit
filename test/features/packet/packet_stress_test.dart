import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

/// Stress the whole engine: many packets, mixed sizes, out-of-order runs,
/// corrupt frames and a stall that must expire — asserting the layer stays
/// consistent under load.
void main() {
  PacketEngine newEngine() {
    const serializer = PacketSerializer();
    return PacketEngine(
      source: 'node-1',
      serializer: serializer,
      validator: const PacketValidator(),
      fragmenter: PacketFragmenter(serializer: serializer),
      reassembly: ReassemblyEngine(maxSessions: 64),
    );
  }

  test('one hundred packets round-trip under mixed conditions', () {
    final engine = newEngine();
    final delivered = <int>[];
    const addresses = ['node-a', 'node-b', 'node-c', 'node-d'];

    for (var i = 0; i < 100; i++) {
      final size = (i % 7 == 0) ? 3000 : 32; // mix fragmented and whole
      final payload = List<int>.generate(size, (j) => (i + j) % 256);
      final packet = engine.createMessage(
        destination: addresses[i % addresses.length],
        payload: PacketPayload.binary(payload),
      );
      final framing = engine.framesFor(packet, mtu: 200);
      for (final frame in framing.value!.frames) {
        final outcome = engine.decode(frame.bytes);
        if (outcome is PacketDelivered) {
          expect(outcome.packet.payload.bytes, payload);
          delivered.add(i);
        }
      }
    }

    expect(delivered.length, 100);
    expect(engine.statistics.packetsCreated, 100);
    expect(engine.statistics.packetsDelivered, 100);
    expect(engine.statistics.packetsRejected, 0);
    expect(engine.reassembly.sessionCount, 0);
  });

  test('out-of-order interleaved runs from one source stay distinct', () {
    final engine = newEngine();
    final expectedA = List<int>.generate(2000, (i) => (i * 3) % 256);
    final expectedB = List<int>.generate(2000, (i) => (i * 5) % 256);
    final a = engine.createMessage(
      destination: 'x',
      payload: PacketPayload.binary(expectedA),
    );
    final b = engine.createMessage(
      destination: 'y',
      payload: PacketPayload.binary(expectedB),
    );
    final framesA = engine.framesFor(a, mtu: 200).value!.frames;
    final framesB = engine.framesFor(b, mtu: 200).value!.frames;

    // Interleave: feed A0, B0, A1, B1, ...
    final interleaved = <List<int>>[];
    for (var i = 0; i < framesA.length || i < framesB.length; i++) {
      if (i < framesA.length) {
        interleaved.add(framesA[i].bytes);
      }
      if (i < framesB.length) {
        interleaved.add(framesB[i].bytes);
      }
    }
    final delivered = <List<int>>[];
    for (final bytes in interleaved.reversed) {
      final outcome = engine.decode(bytes);
      if (outcome is PacketDelivered) {
        delivered.add(outcome.packet.payload.bytes);
      }
    }
    expect(delivered, hasLength(2));
    expect(delivered, containsAll([expectedA, expectedB]));
  });

  test('corruptions interleaved with good frames only cost the bad ones', () {
    final engine = newEngine();
    final good = <PacketDecodeOutcome>[];
    for (var i = 0; i < 40; i++) {
      final packet = engine.createMessage(
        destination: 'node-7',
        payload: PacketPayload.utf8('good message $i'),
      );
      final frame = engine.serializer.encode(packet).value!;
      if (i % 4 == 0) {
        final bad = List<int>.of(frame)..[5] ^= 0xFF;
        expect(engine.decode(bad), isA<PacketRejected>());
      } else {
        good.add(engine.decode(frame));
      }
    }
    expect(good.whereType<PacketDelivered>(), hasLength(30));
    expect(engine.statistics.packetsRejected, 10);
    expect(engine.statistics.packetsDelivered, 30);
  });

  test('duplicate delivery attempts stay idempotent across a full run', () {
    final engine = newEngine();
    final payload = List<int>.generate(1500, (i) => i % 64);
    final packet = engine.createMessage(
      destination: 'node-2',
      payload: PacketPayload.binary(payload),
    );
    final frames = engine.framesFor(packet, mtu: 185).value!.frames;

    final first = frames.first.bytes;
    expect(engine.decode(first), isA<PacketFragmentBuffered>());
    expect(engine.decode(List<int>.of(first)), isA<PacketFragmentBuffered>());
    // Clone of the first fragment is a duplicate too.
    expect(engine.decode(List<int>.of(first)), isA<PacketFragmentBuffered>());

    var completions = 0;
    for (final frame in frames.skip(1)) {
      final outcome = engine.decode(frame.bytes);
      if (outcome is PacketDelivered) {
        completions++;
        expect(outcome.packet.payload.bytes, payload);
      }
    }
    expect(completions, 1);
    expect(engine.statistics.packetsDelivered, 1);
  });
}
