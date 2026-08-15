import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/platform/native_channel_bridge.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_methods.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_platform.dart';

/// [BluetoothPlatform] implemented over the native method/event channels.
///
/// This is the only class in the Bluetooth feature that touches
/// `MethodChannel`/`EventChannel` directly. Commands go through the supplied
/// [NativeChannelBridge] — callers must hand it a bridge bound to
/// [BluetoothChannels.methods]; callbacks come from the dedicated event
/// channel. Both sides use the standard codec so wire strings survive
/// byte-for-byte — the JSON codec would base64-decode any string that looks
/// like valid base64 (e.g. `'idle'`, `'rssi'`).
final class MethodChannelBluetoothPlatform implements BluetoothPlatform {
  MethodChannelBluetoothPlatform({
    required this._bridge,
    EventChannel? eventChannel,
  }) : _eventChannel =
           eventChannel ?? const EventChannel(BluetoothChannels.events);

  final NativeChannelBridge _bridge;
  final EventChannel _eventChannel;

  Stream<Map<String, Object?>>? _events;

  @override
  Stream<Map<String, Object?>> get events =>
      _events ??= _eventChannel.receiveBroadcastStream().map(
        (raw) =>
            Map<String, Object?>.from((raw as Map).cast<String, Object?>()),
      );

  @override
  Future<Result<Map<String, Object?>>> getState() =>
      _invoke(BluetoothMethods.getState);

  @override
  Future<Result<Map<String, Object?>>> requestPermissions() =>
      _invoke(BluetoothMethods.requestPermissions);

  @override
  Future<Result<Map<String, Object?>>> recoverPermissions() =>
      _invoke(BluetoothMethods.recoverPermissions);

  @override
  Future<Result<Map<String, Object?>>> startScan(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.startScan, args);

  @override
  Future<Result<Map<String, Object?>>> stopScan(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.stopScan, args);

  @override
  Future<Result<Map<String, Object?>>> startAdvertising(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.startAdvertising, args);

  @override
  Future<Result<Map<String, Object?>>> stopAdvertising(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.stopAdvertising, args);

  @override
  Future<Result<Map<String, Object?>>> startGattServer(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.startGattServer, args);

  @override
  Future<Result<Map<String, Object?>>> stopGattServer() =>
      _invoke(BluetoothMethods.stopGattServer);

  @override
  Future<Result<Map<String, Object?>>> connect(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.connect, args);

  @override
  Future<Result<Map<String, Object?>>> disconnect(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.disconnect, args);

  @override
  Future<Result<Map<String, Object?>>> readRssi(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.readRssi, args);

  @override
  Future<Result<Map<String, Object?>>> requestMtu(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.requestMtu, args);

  @override
  Future<Result<Map<String, Object?>>> discoverServices(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.discoverServices, args);

  @override
  Future<Result<Map<String, Object?>>> readCharacteristic(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.readCharacteristic, args);

  @override
  Future<Result<Map<String, Object?>>> writeCharacteristic(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.writeCharacteristic, args);

  @override
  Future<Result<Map<String, Object?>>> setNotify(Map<String, Object?> args) =>
      _invoke(BluetoothMethods.setNotify, args);

  @override
  Future<Result<Map<String, Object?>>> startForegroundService(
    Map<String, Object?> args,
  ) => _invoke(BluetoothMethods.startForegroundService, args);

  @override
  Future<Result<Map<String, Object?>>> stopForegroundService() =>
      _invoke(BluetoothMethods.stopForegroundService);

  Future<Result<Map<String, Object?>>> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _bridge.invoke(method, arguments);
    return result.fold(
      (payload) => payload is Map
          ? Ok<Map<String, Object?>>(Map<String, Object?>.from(payload))
          : Err(
              PlatformFailure(message: 'ble.invalid_response', method: method),
            ),
      Err<Map<String, Object?>>.new,
    );
  }
}

/// Encodes transport bytes for the standard method codec.
class BleBytes {
  const BleBytes._();

  static Uint8List encode(List<int> bytes) => Uint8List.fromList(bytes);

  static List<int> decode(Object? raw) {
    if (raw is List) return List<int>.from(raw);
    if (raw is String) return utf8.encode(raw);
    return const [];
  }
}
