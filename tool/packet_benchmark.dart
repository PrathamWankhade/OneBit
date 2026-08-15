import 'dart:math';

import 'package:onebit/features/packet/compression/zlib_compressor.dart';
import 'package:onebit/features/packet/crc/crc32.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

/// Headless performance table for the packet protocol.
///
/// Measures the hot paths (serialize, deserialize, CRC, fragment,
/// reassemble, parse, compress) and prints average times per operation.
/// Run with `flutter test tool/packet_benchmark.dart`.
Future<void> main() async {
  const serializer = PacketSerializer();
  final engine = PacketEngine(
    source: 'node-a',
    serializer: serializer,
    validator: const PacketValidator(),
    fragmenter: PacketFragmenter(serializer: serializer),
    reassembly: ReassemblyEngine(),
  );

  final small = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.utf8('hello onebit'),
  );
  final large = engine.createMessage(
    destination: 'node-b',
    payload: PacketPayload.binary(
      List<int>.generate(64 * 1024, (i) => i % 256),
    ),
  );
  final compressible = utf8Encode(
    'the quick brown fox jumps over the lazy dog. ' * 64,
  );

  // ignore: avoid_print
  print('Packet protocol benchmark (host VM)');
  // ignore: avoid_print
  print('-----------------------------------');
  _row(
    'serialize small (10k ops)',
    _measure(10000, () => serializer.encode(small)),
  );
  _row(
    'deserialize small (10k ops)',
    _measure(10000, () => serializer.decode(_frame(serializer, small))),
  );
  _row(
    'crc-32 on 4 KiB (10k ops)',
    _measure(10000, () => Crc32.compute(_fourKib)),
  );
  _row(
    'frame 64 KiB at mtu 185 (200 ops)',
    _measure(200, () => engine.framesFor(large, mtu: 185)),
  );
  _row(
    'reassemble 64 KiB run (200 ops)',
    _measure(200, () => _reassembleRun(engine, large, 185)),
  );
  _row(
    'zlib compress 4 KiB text (1k ops)',
    _measure(1000, () => ZlibFastCompressor().compress(compressible)),
  );
  _row(
    'decode a small frame (10k ops)',
    _measure(10000, () => engine.decode(_frame(serializer, small))),
  );
  // ignore: avoid_print
  print('-----------------------------------');
  // ignore: avoid_print
  print(
    '  minimal small frame: ${_frame(serializer, small).length} bytes '
    '(spec minimum ~54)',
  );
}

final List<int> _fourKib = List<int>.filled(4096, 0xAA);

final Random _random = Random(42);

String _measure(int count, void Function() body) {
  for (var i = 0; i < count ~/ 10; i++) {
    body();
  }
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    body();
  }
  stopwatch.stop();
  final microsPerOp = stopwatch.elapsedMicroseconds / count;
  return '${microsPerOp.toStringAsFixed(2)} us/op '
      '(${stopwatch.elapsedMilliseconds} ms total)';
}

void _row(String label, String value) {
  // ignore: avoid_print
  print('  ${label.padRight(36)} $value');
}

List<int> _frame(PacketSerializer serializer, Packet packet) {
  return serializer.encode(packet).value!;
}

/// Sends every frame of [packet] through the engine in random order so the
/// benchmark covers out-of-order reassembly.
void _reassembleRun(PacketEngine engine, Packet packet, int mtu) {
  final frames = engine.framesFor(packet, mtu: mtu).value!.frames;
  frames.shuffle(_random);
  for (final frame in frames) {
    engine.decode(frame.bytes);
  }
}

List<int> utf8Encode(String text) => text.codeUnits;
