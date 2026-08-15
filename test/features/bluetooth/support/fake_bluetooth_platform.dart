import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_platform.dart';

/// Deterministic [BluetoothPlatform] for tests.
///
/// Scripts a queue of responses per method so tests can drive repositories
/// without real hardware — same contract the MethodChannel implementation
/// honors.
final class FakeBluetoothPlatform implements BluetoothPlatform {
  final Map<String, List<Result<Map<String, Object?>>>> _responses = {};

  final StreamController<Map<String, Object?>> _events =
      StreamController<Map<String, Object?>>.broadcast();

  final List<String> invokedMethods = [];

  /// Records a scripted response for [method].
  void enqueue(String method, Result<Map<String, Object?>> response) {
    _responses.putIfAbsent(method, () => []).add(response);
  }

  /// Emits a transport event to listeners.
  void emit(Map<String, Object?> event) => _events.add(event);

  Future<Result<Map<String, Object?>>> _respond(String method) async {
    invokedMethods.add(method);
    final queue = _responses[method];
    if (queue == null || queue.isEmpty) {
      return const Err(PlatformFailure(message: 'ble.unscripted'));
    }
    return queue.removeAt(0);
  }

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<Result<Map<String, Object?>>> getState() => _respond('getState');

  @override
  Future<Result<Map<String, Object?>>> requestPermissions() =>
      _respond('requestPermissions');

  @override
  Future<Result<Map<String, Object?>>> recoverPermissions() =>
      _respond('recoverPermissions');

  @override
  Future<Result<Map<String, Object?>>> startScan(Map<String, Object?> args) =>
      _respond('startScan');

  @override
  Future<Result<Map<String, Object?>>> stopScan(Map<String, Object?> args) =>
      _respond('stopScan');

  @override
  Future<Result<Map<String, Object?>>> startAdvertising(
    Map<String, Object?> args,
  ) => _respond('startAdvertising');

  @override
  Future<Result<Map<String, Object?>>> stopAdvertising(
    Map<String, Object?> args,
  ) => _respond('stopAdvertising');

  @override
  Future<Result<Map<String, Object?>>> startGattServer(
    Map<String, Object?> args,
  ) => _respond('startGattServer');

  @override
  Future<Result<Map<String, Object?>>> stopGattServer() =>
      _respond('stopGattServer');

  @override
  Future<Result<Map<String, Object?>>> connect(Map<String, Object?> args) =>
      _respond('connect');

  @override
  Future<Result<Map<String, Object?>>> disconnect(Map<String, Object?> args) =>
      _respond('disconnect');

  @override
  Future<Result<Map<String, Object?>>> readRssi(Map<String, Object?> args) =>
      _respond('readRssi');

  @override
  Future<Result<Map<String, Object?>>> requestMtu(Map<String, Object?> args) =>
      _respond('requestMtu');

  @override
  Future<Result<Map<String, Object?>>> discoverServices(
    Map<String, Object?> args,
  ) => _respond('discoverServices');

  @override
  Future<Result<Map<String, Object?>>> readCharacteristic(
    Map<String, Object?> args,
  ) => _respond('readCharacteristic');

  @override
  Future<Result<Map<String, Object?>>> writeCharacteristic(
    Map<String, Object?> args,
  ) => _respond('writeCharacteristic');

  @override
  Future<Result<Map<String, Object?>>> setNotify(Map<String, Object?> args) =>
      _respond('setNotify');

  @override
  Future<Result<Map<String, Object?>>> startForegroundService(
    Map<String, Object?> args,
  ) => _respond('startForegroundService');

  @override
  Future<Result<Map<String, Object?>>> stopForegroundService() =>
      _respond('stopForegroundService');

  void dispose() => _events.close();
}

/// Scripted happy-path responses for a radio snapshot.
Map<String, Object?> readySnapshot() => {
  'state': 'ready',
  'permission': 'granted',
  'batterySaver': false,
  'maxConcurrentConnections': 4,
};
