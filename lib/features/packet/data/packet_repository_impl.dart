import 'dart:async';

import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_incoming.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_priority.dart';
import 'package:onebit/features/packet/domain/packet_repository.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';

/// Binds [PacketEngine] to whatever transport the app uses today.
///
/// Outbound: `send()` builds a packet, compresses it when beneficial,
/// fragments it to the configured [mtu] and hands each frame to the
/// [sendFrame] callback (the mesh layer's `MeshRepository.send` in the
/// app wiring; a fake in tests). Inbound: every payload from [inbound] is
/// decoded by the engine; complete packets are emitted on the delivered
/// stream, rejections are logged and surfaced through the engine's decode
/// stream for the developer panels.
final class PacketRepositoryImpl implements PacketRepository {
  PacketRepositoryImpl({
    required this.engine,
    required this.sendFrame,
    required Stream<List<int>> inbound,
    this.mtu = 185,
    this.logger,
  }) {
    _subscription = inbound.listen(
      _onFrame,
      onError: (Object error, StackTrace stackTrace) {
        logger?.error(
          'inbound frame stream error',
          tag: LogTags.packet,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// The packet pipeline (build, compress, frame, decode, reassemble).
  final PacketEngine engine;

  /// Hands one serialized wire frame to the transport.
  final Future<Result<void>> Function(
    String destination,
    List<int> bytes,
    int ttl,
  )
  sendFrame;

  /// Per-frame budget the engine must stay under.
  final int mtu;

  /// Optional logger (pure Dart friendly).
  final AppLogger? logger;

  final StreamController<Result<Packet>> _deliveredController =
      StreamController<Result<Packet>>.broadcast();
  StreamSubscription<List<int>>? _subscription;

  @override
  Future<Result<void>> send({
    required String destination,
    required List<int> payload,
    PacketType type = PacketType.message,
    PacketPriority priority = PacketPriority.normal,
    bool ackRequested = false,
    int ttl = 8,
  }) async {
    final packet = engine.createMessage(
      destination: destination,
      payload: PacketPayload.binary(payload),
      type: type,
      priority: priority,
      ackRequested: ackRequested,
      ttl: ttl,
    );
    final prepared = engine.compressIfBeneficial(packet);
    final framing = engine.framesFor(prepared, mtu: mtu);
    if (framing.failure case final failure?) {
      return Err(failure);
    }
    for (final frame in framing.value!.frames) {
      final result = await sendFrame(destination, frame.bytes, ttl);
      if (result.isErr) return result;
    }
    return const Ok(null);
  }

  @override
  Stream<Result<Packet>> observeDeliveredPackets() =>
      _deliveredController.stream;

  void _onFrame(List<int> bytes) {
    final outcome = engine.decode(bytes);
    if (outcome case PacketDelivered(:final packet)) {
      _deliveredController.add(Ok(packet));
    }
  }

  void dispose() {
    _subscription?.cancel();
    _deliveredController.close();
  }
}
