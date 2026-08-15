import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/mesh/engine/mesh_engine.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/packet/compression/packet_compression_strategies.dart';
import 'package:onebit/features/packet/compression/zlib_compressor.dart';
import 'package:onebit/features/packet/data/packet_repository_impl.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_state.dart';
import 'package:onebit/features/packet/domain/packet_repository.dart';
import 'package:onebit/features/packet/domain/packet_statistics.dart';
import 'package:onebit/features/packet/domain/packet_version.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

/// The validation rules the engine applies (max 256 fragments).
final Provider<PacketValidator> packetValidatorProvider =
    Provider<PacketValidator>((ref) => const PacketValidator());

/// The packet engine: composition root of the whole protocol pipeline.
///
/// Wired with the `fast` (zlib) compressor and the shared app logger. The
/// engine is pure Dart; only this provider touches Flutter/Riverpod.
final Provider<PacketEngine> packetEngineProvider = Provider<PacketEngine>((
  ref,
) {
  final logger = ref.watch(appLoggerProvider);
  const serializer = PacketSerializer();
  final engine = PacketEngine(
    source: 'local',
    serializer: serializer,
    validator: ref.watch(packetValidatorProvider),
    fragmenter: PacketFragmenter(serializer: serializer),
    reassembly: ReassemblyEngine(logger: logger),
    logger: logger,
    compression: PacketCompressionPolicy(
      compressor: ZlibFastCompressor(level: 4),
      threshold: 64,
    ),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// The repository bridging the packet engine to the mesh layer.
///
/// Outbound frames go through `MeshRepository.send`; inbound payload bytes
/// come from the mesh engine's deliver-up stream.
final Provider<PacketRepository> packetRepositoryProvider =
    Provider<PacketRepository>((ref) {
      final repository = PacketRepositoryImpl(
        engine: ref.watch(packetEngineProvider),
        sendFrame: _sendThroughMesh(ref),
        inbound: _deliveredPayloads(ref.watch(meshEngineProvider)),
        logger: ref.watch(appLoggerProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Live engine counters (packets created/sent/delivered/rejected/fragments).
final StreamProvider<PacketStatistics> packetStatisticsProvider =
    StreamProvider<PacketStatistics>(
      (ref) => ref.watch(packetEngineProvider).observeStatistics(),
    );

/// The most recent decode outcome (delivered / buffered / rejected).
final StreamProvider<PacketDecodeOutcome> packetStateProvider =
    StreamProvider<PacketDecodeOutcome>(
      (ref) => ref.watch(packetEngineProvider).observeDecodeOutcomes(),
    );

/// Live reassembly sessions (the fragment queue of this node).
final StreamProvider<List<ReassemblySession>> packetFragmentQueueProvider =
    StreamProvider<List<ReassemblySession>>((ref) {
      final engine = ref.watch(packetEngineProvider);
      return engine.observeDecodeOutcomes().map(
        (_) => engine.reassembly.sessions,
      );
    });

/// The protocol version this build speaks.
final Provider<PacketVersion> packetProtocolVersionProvider =
    Provider<PacketVersion>((ref) => PacketVersion.current);

/// The compression policy (strategy + threshold) in effect.
final Provider<PacketCompressionPolicy> packetCompressionPolicyProvider =
    Provider<PacketCompressionPolicy>(
      (ref) => ref.watch(packetEngineProvider).compression,
    );

/// Bounded log of serialization-tester round-trips (dev panel only).
final NotifierProvider<PacketWireLogController, List<String>>
packetWireLogProvider = NotifierProvider<PacketWireLogController, List<String>>(
  PacketWireLogController.new,
);

/// The wire-tester log state (plain list capped at [PacketWireLogController.maxLines]).
final class PacketWireLogController extends Notifier<List<String>> {
  /// Upper bound of retained lines.
  static const int maxLines = 50;

  @override
  List<String> build() => const [];

  /// Appends [line], trimming to [maxLines].
  void add(String line) {
    final next = <String>[...state, line];
    state = next.length > maxLines
        ? next.sublist(next.length - maxLines)
        : next;
  }
}

Future<Result<void>> Function(String destination, List<int> bytes, int ttl)
_sendThroughMesh(Ref ref) {
  final mesh = ref.read(meshRepositoryProvider);
  return (destination, bytes, ttl) async {
    final result = await mesh.send(
      destination: destination,
      payload: bytes,
      ttl: ttl,
    );
    return result.isOk ? const Ok(null) : Err(result.failure!);
  };
}

Stream<List<int>> _deliveredPayloads(MeshEngine engine) {
  return engine.deliveredUpStream.map((packet) => packet.payload);
}
