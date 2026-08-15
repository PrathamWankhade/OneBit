import 'dart:async';

import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';

/// Drains the DTN delivery seam.
///
/// [DTNRepository.observeDelivered] is a pull, not a stream: the pump loops
/// `await observeDelivered()` and hands every envelope to the engine. A
/// failed or malformed delivery never kills the loop — it backs off and
/// keeps listening.
final class InboundPump {
  InboundPump({
    required this.dtn,
    required this.logger,
    this.backoff = const Duration(milliseconds: 250),
  });

  final DTNRepository dtn;
  final AppLogger logger;

  /// Pause between failed delivery reads.
  final Duration backoff;

  static const _tag = LogTags.messaging;

  bool _running = false;
  Future<void>? _loop;

  bool get isRunning => _running;

  /// Starts the delivery loop. Handles each envelope with [onEnvelope]
  /// sequentially (ordering per-channel is preserved that way).
  void start(Future<void> Function(DtnPacket packet) onEnvelope) {
    if (_running) return;
    _running = true;
    _loop = _run(onEnvelope);
  }

  Future<void> stop() async {
    _running = false;
    await _loop;
  }

  Future<void> _run(Future<void> Function(DtnPacket) onEnvelope) async {
    while (_running) {
      try {
        final packet = await dtn.observeDelivered();
        await onEnvelope(packet);
      } on DtnFailure catch (failure) {
        logger.warning('inbound: delivery failed: $failure', tag: _tag);
        if (_running) await Future<void>.delayed(backoff);
      } catch (error, stackTrace) {
        logger.error(
          'inbound: unterminated error: $error',
          tag: _tag,
          error: error,
          stackTrace: stackTrace,
        );
        if (_running) await Future<void>.delayed(backoff);
      }
    }
  }
}
