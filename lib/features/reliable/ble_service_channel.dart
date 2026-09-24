import 'dart:async';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/reliable/reliable_channel.dart';

/// Bridges [BleService] to the [ReliableChannel] abstraction.
///
/// Sends data through the communication characteristic and
/// receives data through the characteristicChanged stream.
class BleServiceChannel implements ReliableChannel {
  BleServiceChannel({
    required this._service,
    required this._deviceId,
  });

  final BleService _service;
  final String _deviceId;

  StreamSubscription<BleCharacteristicValue>? _notifySub;
  final _incomingController = StreamController<List<int>>.broadcast();
  bool _disposed = false;

  /// Whether this channel has been disposed.
  bool get isDisposed => _disposed;

  /// Start listening for incoming characteristic values.
  ///
  /// Must be called after connection and service discovery.
  void startListening() {
    _notifySub?.cancel();
    _notifySub = _service.characteristicChanged.listen((value) {
      if (value.deviceId != _deviceId) return;
      if (value.characteristicUuid != BleUuids.communicationCharacteristic) {
        return;
      }
      if (!_incomingController.isClosed) {
        _incomingController.add(value.value);
      }
    });

    // Enable notifications on the communication characteristic.
    _service
        .setNotify(
          _deviceId,
          BleUuids.oneBitService,
          BleUuids.communicationCharacteristic,
          true,
        )
        .catchError((e) {
      AppLogger.warning(
        'BleServiceChannel: notification setup failed for $_deviceId — '
        'incoming data will be lost',
      );
    });
  }

  /// Stop listening for incoming values.
  void stopListening() {
    _notifySub?.cancel();
    _notifySub = null;
  }

  @override
  bool get isConnected {
    final info = _service.current.connectionFor(_deviceId);
    return info != null && info.isConnected;
  }

  @override
  Future<void> send(List<int> bytes) {
    if (_disposed) {
      throw StateError('BleServiceChannel has been disposed');
    }
    return _service.writeCharacteristic(
      _deviceId,
      BleUuids.oneBitService,
      BleUuids.communicationCharacteristic,
      bytes,
    );
  }

  @override
  Stream<List<int>> get incoming => _incomingController.stream;

  /// Dispose and clean up listeners.
  ///
  /// Disables native BLE notifications before tearing down Dart resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notifySub?.cancel();
    _notifySub = null;

    // Disable native BLE notification to release the GATT descriptor.
    final info = _service.current.connectionFor(_deviceId);
    if (info != null && info.isConnected) {
      _service
          .setNotify(
            _deviceId,
            BleUuids.oneBitService,
            BleUuids.communicationCharacteristic,
            false,
          )
          .catchError((e) {
        AppLogger.warning(
          'BleServiceChannel: failed to disable notifications for $_deviceId',
        );
      });
    }

    if (!_incomingController.isClosed) {
      _incomingController.close();
    }
  }
}
