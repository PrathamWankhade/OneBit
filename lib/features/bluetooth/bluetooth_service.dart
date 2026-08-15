import 'dart:async';

import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';

/// Application-scoped lifecycle owner of the Bluetooth transport.
///
/// The single place that starts/stops the transport with the app: it reads
/// the radio snapshot, subscribes the transport event stream and records
/// lifecycle transitions. Managers stay pluggable behind [BluetoothRepository]
/// so the dev tooling and the future mesh phase consume one service.
///
/// Transport only — this service knows nothing about messages, routing,
/// encryption or the mesh. It never throws: every path returns a [Result]
/// or logs through [AppLogger], so boot is safe when Bluetooth is off or
/// unsupported.
final class BluetoothService {
  BluetoothService({required this.repository, required this.logger});

  static const _tag = 'ble.service';

  final BluetoothRepository repository;
  final AppLogger logger;

  bool _started = false;
  StreamSubscription<BluetoothTransportEvent>? _subscription;
  String? _deviceId;

  /// True once [start] completed successfully.
  bool get isStarted => _started;

  /// The device id the native host reports, once discovered.
  String? get deviceId => _deviceId;

  /// Initializes the transport; idempotent and never throws.
  Future<Result<void>> start() async {
    if (_started) return const Ok(null);
    final snapshot = await repository.getRadioSnapshot();
    if (snapshot.isErr) {
      logger.warning(
        'transport init failed: ${snapshot.failure!.message}',
        tag: _tag,
        error: snapshot.failure,
      );
      return Err(snapshot.failure!);
    }
    _subscription = repository.events.listen(
      _onEvent,
      onError: (Object error) =>
          logger.error('event stream failed: $error', tag: _tag),
      onDone: () {
        _started = false;
        _subscription = null;
      },
    );
    _started = true;
    logger.info(
      'transport started (radio ${snapshot.value!.radio.rawName})',
      tag: _tag,
    );
    return const Ok(null);
  }

  /// Stops the transport; idempotent and never throws.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
    _deviceId = null;
    logger.info('transport stopped', tag: _tag);
  }

  void _onEvent(BluetoothTransportEvent event) {
    switch (event) {
      case RadioStateChangedEvent(:final radio):
        logger.debug('radio: ${radio.rawName}', tag: _tag);
      case ConnectionChangedEvent(:final deviceId, :final state):
        _deviceId = deviceId;
        logger.debug('link $deviceId: $state', tag: _tag);
      case TransportErrorEvent(:final code):
        logger.warning('transport error: $code', tag: _tag);
      default:
        break;
    }
  }
}
