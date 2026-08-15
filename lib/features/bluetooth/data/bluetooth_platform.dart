import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';

/// Contract for the native Bluetooth host.
///
/// The single seam between Dart and Kotlin. Implemented by
/// [MethodChannelBluetoothPlatform]; tests substitute a fake. All methods
/// return [Result] — [Ok] with the typed payload or [Err] carrying a
/// `PlatformFailure` whose message is the stable `ble.*` code.
abstract interface class BluetoothPlatform {
  /// Current radio/permission/battery snapshot map.
  Future<Result<Map<String, Object?>>> getState();

  /// Requests runtime permissions; returns the permission state map.
  Future<Result<Map<String, Object?>>> requestPermissions();

  /// Recovery path after a permission denial; re-requests missing grants.
  Future<Result<Map<String, Object?>>> recoverPermissions();

  Future<Result<Map<String, Object?>>> startScan(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> stopScan(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> startAdvertising(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> stopAdvertising(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> startGattServer(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> stopGattServer();
  Future<Result<Map<String, Object?>>> connect(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> disconnect(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> readRssi(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> requestMtu(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> discoverServices(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> readCharacteristic(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> writeCharacteristic(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> setNotify(Map<String, Object?> args);
  Future<Result<Map<String, Object?>>> startForegroundService(
    Map<String, Object?> args,
  );
  Future<Result<Map<String, Object?>>> stopForegroundService();

  /// Raw transport callback stream (map payloads).
  Stream<Map<String, Object?>> get events;
}

/// Convenience: typed accessors over the state map.
extension BluetoothStateMapX on Map<String, Object?> {
  BluetoothRadioState get radioState =>
      BluetoothRadioState.fromWire(this['state'] as String?);
  BluetoothPermissionState get permissionState =>
      BluetoothPermissionState.fromWire(this['permission'] as String?);
  bool get batterySaver => this['batterySaver'] == true;
  int get maxConcurrent =>
      (this['maxConcurrentConnections'] as num?)?.toInt() ?? 1;
}
