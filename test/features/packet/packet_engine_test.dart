import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/compression/packet_compression_strategies.dart';
import 'package:onebit/features/packet/compression/zlib_compressor.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

final _now = DateTime(2026, 1, 1, 12);

PacketEngine _engine({DateTime Function()? now}) {
  const serializer = PacketSerializer();
  return PacketEngine(
    source: 'node-1',
    serializer: serializer,
    validator: const PacketValidator(),
    fragmenter: PacketFragmenter(serializer: serializer),
    reassembly: ReassemblyEngine(now: now ?? () => _now),
    now: now ?? () => _now,
  );
}

void main() {
  group('PacketEngine end-to-end', () {
    test('createMessage issues incrementing sequence ids', () {
      final engine = _engine();
      final a = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8('one'),
      );
      final b = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8('two'),
      );
      expect(a.header.sequence, lessThan(b.header.sequence));
      expect(a.header.source, 'node-1');
      expect(a.header.destination, 'node-2');
      expect(engine.statistics.packetsCreated, 2);
    });

    test('unfragmented frames deliver and count', () {
      final engine = _engine();
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8('hey'),
      );
      final outcome = engine.decode(engine.serializer.encode(packet).value!);
      expect(outcome, isA<PacketDelivered>());
      expect(
        (outcome as PacketDelivered).packet.payload.bytes,
        'hey'.codeUnits,
      );
      expect(engine.statistics.packetsDelivered, 1);
      expect(engine.statistics.packetsRejected, 0);
    });

    test('framesFor plus decode reassemble end-to-end, out of order', () {
      final engine = _engine();
      final payload = List<int>.generate(5000, (i) => i % 128);
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.binary(payload),
      );
      final framing = engine.framesFor(packet, mtu: 512);
      expect(framing.value!.fragmented, isTrue);
      expect(engine.statistics.packetsSent, framing.value!.frames.length);

      PacketDelivered? delivered;
      for (final frame in framing.value!.frames.reversed) {
        final outcome = engine.decode(frame.bytes);
        if (outcome is PacketDelivered) delivered = outcome;
      }
      expect(delivered, isNotNull);
      expect(delivered!.packet.payload.bytes, payload);
      expect(engine.statistics.packetsDelivered, 1);
      expect(engine.statistics.fragmentsCompleted, 1); // one completed run
      expect(engine.statistics.fragmentsAccepted, framing.value!.frames.length);
      expect(engine.reassembly.sessionCount, 0);
    });

    test('garbage frames are counted as rejected', () {
      final engine = _engine();
      expect(engine.decode(List<int>.filled(16, 0xAA)), isA<PacketRejected>());
      expect(engine.statistics.packetsRejected, 1);
    });

    test('a corrupted frame produces a typed PacketRejected', () {
      final engine = _engine();
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8('hello'),
      );
      final frame = engine.serializer.encode(packet).value!;
      final mutated = List<int>.of(frame)..[frame.length - 2] ^= 0x40;
      final outcome = engine.decode(mutated);
      expect(outcome, isA<PacketRejected>());
      final rejected = outcome as PacketRejected;
      expect(rejected.failure, isNotNull);
      expect(
        rejected.failure.toString(),
        anyOf(contains('crc'), contains('decode')),
      );
      expect(engine.statistics.packetsRejected, 1);
      expect(engine.statistics.packetsDelivered, 0);
    });

    test('a stalled run expires and is never delivered', () {
      var clock = _now;
      final engine = _engine(now: () => clock);
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.binary(List<int>.filled(4000, 9)),
      );
      final frames = engine.framesFor(packet, mtu: 185).value!.frames;
      for (final frame in frames.skip(1)) {
        expect(engine.decode(frame.bytes), isA<PacketFragmentBuffered>());
      }
      clock = clock.add(const Duration(seconds: 31));
      expect(engine.reassembly.sweepExpired(), 1);
      expect(engine.reassembly.sessionCount, 0);
      final outcome = engine.decode(frames.first.bytes);
      // The stale run is gone; the late first fragment opens a fresh one.
      expect(outcome, isA<PacketFragmentBuffered>());
      expect(engine.statistics.packetsDelivered, 0);
    });

    test('compressIfBeneficial flags a compressible payload', () {
      final engine = PacketEngine(
        source: 'node-1',
        serializer: const PacketSerializer(),
        validator: const PacketValidator(),
        fragmenter: PacketFragmenter(serializer: const PacketSerializer()),
        reassembly: ReassemblyEngine(now: () => _now),
        compression: PacketCompressionPolicy(
          compressor: ZlibFastCompressor(),
          threshold: 64,
        ),
        now: () => _now,
      );
      final text = 'repetitive repetition repetition. ' * 20;
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8(text),
      );
      expect(packet.header.flags, isNot(contains(PacketFlag.compressed)));

      final compressed = engine.compressIfBeneficial(packet);
      expect(compressed.header.flags, contains(PacketFlag.compressed));
      expect(compressed.payload.type, PacketPayloadType.compressed);
      expect(compressed.payload.uncompressedSize, text.length);

      final roundtrip = engine.serializer
          .decode(engine.serializer.encode(compressed).value!)
          .value!;
      expect(roundtrip.header.flags, contains(PacketFlag.compressed));
      expect(roundtrip.payload.bytes, compressed.payload.bytes);
    });

    test('statistics and outcomes stream for the dev consoles', () async {
      final engine = _engine();
      final received = <PacketDecodeOutcome>[];
      final subscription = engine.observeDecodeOutcomes().listen(received.add);
      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.utf8('buffered?'),
      );
      final outcome = engine.decode(engine.serializer.encode(packet).value!);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(received, hasLength(1));
      expect(received.single, same(outcome));
      expect(engine.statistics.packetsDelivered, 1);
    });
  });
}
