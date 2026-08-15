import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';

import '../transfer/transfer_envelope.dart';
import '../transfer/transfer_gateway.dart';
import 'wire/attachment_wire_codec.dart';

/// The DTN-backed [TransferGateway] — the only media object that touches
/// the DTN wire.
///
/// Outbound: encodes [MediaEnvelope]s into store-and-forward packets.
/// Inbound: exposes the engine's delivery stream (the DTN engine's
/// broadcast `inboundDeliveries`); the messaging pump shares the same
/// stream — non-media payloads fail the media codec and are dropped.
final class AttachmentManager implements TransferGateway {
  AttachmentManager({
    required this.localNodeId,
    required this.dtn,
    required this.logger,
    this.codec = const AttachmentWireCodec(),
  });

  final String localNodeId;
  final DTNRepository dtn;
  final AppLogger logger;
  final MediaEnvelopeCodec codec;

  static const _tag = LogTags.media;

  /// Media envelope TTL on the wire (matches session sweep horizons).
  static const int mediaTtlSeconds = 7 * 24 * 3600;

  Stream<DtnPacket> _inbound = const Stream.empty();

  @override
  Stream<DtnPacket> get inboundDeliveries => _inbound;

  /// Wires the radio delivery seam (called by the composition root).
  void attachInbound(Stream<DtnPacket> deliveries) {
    _inbound = deliveries;
  }

  @override
  Future<Result<DtnPacket>> transmit(
    MediaEnvelope envelope,
    String peerNodeId,
  ) async {
    final now = DateTime.now();
    final packet = DtnPacket(
      packetId:
          'media:$localNodeId:'
          '${now.microsecondsSinceEpoch.toRadixString(36)}',
      source: localNodeId,
      destination: peerNodeId,
      payload: codec.encode(envelope),
      priority: DtnPriority.normal,
      direction: DtnDirection.outbound,
      ttlSeconds: mediaTtlSeconds,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: mediaTtlSeconds)),
    );
    try {
      final stored = await dtn.store(packet);
      return Ok(stored);
    } on DtnFailure catch (failure) {
      logger.warning('media transmit failed: $failure', tag: _tag);
      return Err(
        MediaNetworkFailure(message: 'transmit failed', cause: failure),
      );
    } catch (error, stackTrace) {
      return Err(
        MediaNetworkFailure(
          message: 'transmit crashed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
