import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

/// Headless packet-protocol simulation runner.
///
/// Exercises every scenario the real flow demands — single packet, 100
/// packets, fragmented, corrupted, packet loss, duplicates, large payloads,
/// version mismatch and reassembly timeout — and prints a pass/fail report.
/// Run with `flutter test tool/packet_simulation.dart`; a failed scenario
/// throws so the runner exits non-zero.
Future<void> main() async {
  final scenarios = <String, Future<bool> Function()>{
    'single packet round-trip': singlePacketRoundTrip,
    '100 packets round-trip': hundredPacketsRoundTrip,
    'fragmented packet reassembles': fragmentedReassembles,
    'corrupted packet is rejected': corruptedRejected,
    'packet loss drops the run': packetsLostDropped,
    'duplicate fragment is not double-written': duplicateNotOverwritten,
    'large payload (24 KiB) survives': largePayloadSurvives,
    'oversized run is rejected': oversizedRunRejected,
    'version mismatch is dropped': versionMismatchDropped,
    'reassembly timeout drops partial run': timeoutDropsRun,
  };

  var passed = 0;
  var failed = 0;
  for (final entry in scenarios.entries) {
    // ignore: avoid_print
    print('== ${entry.key} ==');
    var ok = false;
    try {
      ok = await entry.value();
    } catch (error) {
      // ignore: avoid_print
      print('  [ERROR] $error');
    }
    // ignore: avoid_print
    print('[${ok ? 'PASS' : 'FAIL'}]');
    if (ok) {
      passed++;
    } else {
      failed++;
    }
  }

  // ignore: avoid_print
  print('-----------------------------');
  // ignore: avoid_print
  print('total: $passed passed, $failed failed');
  if (failed > 0) {
    throw StateError('$failed packet simulation checks failed');
  }
}

/// Engine over an advanceable clock (for timeout scenarios).
PacketEngine newEngine(DateTime Function() now) {
  const serializer = PacketSerializer();
  return PacketEngine(
    source: 'node-a',
    serializer: serializer,
    validator: const PacketValidator(),
    fragmenter: PacketFragmenter(serializer: serializer),
    reassembly: ReassemblyEngine(
      timeout: const Duration(seconds: 30),
      now: now,
    ),
    now: now,
  );
}

Future<bool> singlePacketRoundTrip() async {
  final engine = newEngine(DateTime.now);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.utf8('hello mesh'),
  );
  final frame = engine.serializer.encode(packet).value!;
  final outcome = engine.decode(frame);
  return outcome is PacketDelivered &&
      String.fromCharCodes(outcome.packet.payload.bytes) == 'hello mesh';
}

Future<bool> hundredPacketsRoundTrip() async {
  final engine = newEngine(DateTime.now);
  for (var i = 0; i < 100; i++) {
    final packet = engine.createMessage(
      destination: 'node-b',
      payload: PacketPayload.utf8('packet number $i'),
    );
    final frame = engine.serializer.encode(packet).value!;
    final outcome = engine.decode(frame);
    if (outcome is! PacketDelivered ||
        String.fromCharCodes(outcome.packet.payload.bytes) !=
            'packet number $i') {
      return false;
    }
  }
  return engine.statistics.packetsDelivered == 100;
}

Future<bool> fragmentedReassembles() async {
  final engine = newEngine(DateTime.now);
  final payload = List<int>.generate(4000, (i) => i % 256);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(payload),
  );
  final frames = engine.framesFor(packet, mtu: 185).value!.frames;
  if (frames.length < 2) return false;
  for (final frame in frames) {
    final outcome = engine.decode(frame.bytes);
    if (outcome is PacketDelivered) {
      return outcome.packet.payload.bytes.length == payload.length &&
          _bytesEqual(outcome.packet.payload.bytes, payload);
    }
  }
  return false;
}

Future<bool> corruptedRejected() async {
  final engine = newEngine(DateTime.now);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.utf8('important'),
  );
  final frame = engine.serializer.encode(packet).value!;
  final flipped = List<int>.of(frame);
  flipped[flipped.length - 2] = flipped[flipped.length - 2] ^ 0x7F;
  return engine.decode(flipped) is PacketRejected;
}

/// Half of the run is destroyed; reassembly must never deliver a partial
/// packet and the run dies on timeout.
Future<bool> packetsLostDropped() async {
  var now = DateTime(2026, 1, 1);
  final engine = newEngine(() => now);
  final payload = List<int>.generate(3000, (i) => i % 128);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(payload),
  );
  final frames = engine.framesFor(packet, mtu: 185).value!.frames;
  var buffered = 0;
  for (final frame in frames.skip(1)) {
    final outcome = engine.decode(frame.bytes);
    if (outcome is PacketDelivered) return false;
    if (outcome is PacketFragmentBuffered) buffered++;
  }
  if (buffered == 0) return false;
  now = now.add(const Duration(seconds: 31));
  engine.reassembly.sweepExpired();
  return engine.reassembly.sessionCount == 0 && buffered > 0;
}

Future<bool> duplicateNotOverwritten() async {
  final engine = newEngine(DateTime.now);
  final payload = List<int>.generate(1500, (i) => i % 64);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(payload),
  );
  final frames = engine.framesFor(packet, mtu: 185).value!.frames;
  // Feeding the same first fragment twice must not corrupt progress.
  expectBuffered(engine.decode(frames.first.bytes));
  expectBuffered(engine.decode(frames.first.bytes));
  var delivered = false;
  for (final frame in frames.skip(1)) {
    final outcome = engine.decode(frame.bytes);
    if (outcome is PacketDelivered) {
      delivered = _bytesEqual(outcome.packet.payload.bytes, payload);
    }
  }
  return delivered && engine.statistics.fragmentsCompleted == 1;
}

Future<bool> largePayloadSurvives() async {
  final engine = newEngine(DateTime.now);
  // 24 KiB fragments into ~184 frames at mtu 185 — under the protocol cap
  // of 256 fragments per run, but a genuinely large multi-window payload.
  final payload = List<int>.generate(24 * 1024, (i) => i % 251);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(payload),
  );
  final frames = engine.framesFor(packet, mtu: 185).value!.frames;
  if (frames.length < 100) return false;
  // Deliver the run out of order.
  final shuffled = List.of(frames.reversed);
  var matched = false;
  for (final frame in shuffled) {
    final outcome = engine.decode(frame.bytes);
    if (outcome is PacketDelivered) {
      matched =
          outcome.packet.payload.bytes.length == payload.length &&
          _bytesEqual(outcome.packet.payload.bytes, payload);
    }
  }
  return matched;
}

/// 512 KiB needs ~3900 fragments; the protocol cap is 256 per run, so the
/// peer must reject the run (rule `fragmentCountAllowed`), not buffer it.
Future<bool> oversizedRunRejected() async {
  final engine = newEngine(DateTime.now);
  final payload = List<int>.generate(512 * 1024, (i) => i % 251);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(payload),
  );
  final frames = engine.framesFor(packet, mtu: 185).value!.frames;
  if (frames.length <= 256) return false;
  return engine.decode(frames.first.bytes) is PacketRejected;
}

Future<bool> versionMismatchDropped() async {
  final engine = newEngine(DateTime.now);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.utf8('newer-format'),
  );
  final frame = engine.serializer.encode(packet).value!;
  final mutated = List<int>.of(frame);
  mutated[0] = (0x2 << 4) | (mutated[0] & 0x0F); // different transport nibble
  return engine.decode(mutated) is PacketRejected;
}

Future<bool> timeoutDropsRun() async {
  var now = DateTime.now();
  final engine = newEngine(() => now);
  final packet = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.utf8('x' * 200),
  );
  final frames = engine.framesFor(packet, mtu: 100).value!.frames;
  if (frames.length < 2) {
    throw StateError('expected a fragmented run');
  }
  for (final frame in frames.take(frames.length - 1)) {
    expectBuffered(engine.decode(frame.bytes));
  }
  now = now.add(const Duration(seconds: 31));
  engine.reassembly.sweepExpired();
  return engine.reassembly.sessionCount == 0;
}

void expectBuffered(PacketDecodeOutcome outcome) {
  if (outcome is! PacketFragmentBuffered && outcome is! PacketDelivered) {
    throw StateError('unexpected outcome: $outcome');
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
