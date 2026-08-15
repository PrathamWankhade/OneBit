import 'package:onebit/core/platform/channel_names.dart';

/// Stable identifiers for the Bluetooth transport channels.
abstract final class BluetoothChannels {
  const BluetoothChannels._();

  /// Method channel for all transport commands.
  static const String methods = PlatformChannels.bluetooth;

  /// Event channel for transport callbacks.
  static const String events = '${PlatformChannels.bluetooth}_events';
}

/// Method names invoked on [BluetoothChannels.methods].
abstract final class BluetoothMethods {
  const BluetoothMethods._();

  static const String getState = 'getState';
  static const String requestPermissions = 'requestPermissions';
  static const String recoverPermissions = 'recoverPermissions';
  static const String startScan = 'startScan';
  static const String stopScan = 'stopScan';
  static const String startAdvertising = 'startAdvertising';
  static const String stopAdvertising = 'stopAdvertising';
  static const String startGattServer = 'startGattServer';
  static const String stopGattServer = 'stopGattServer';
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String readRssi = 'readRssi';
  static const String requestMtu = 'requestMtu';
  static const String discoverServices = 'discoverServices';
  static const String readCharacteristic = 'readCharacteristic';
  static const String writeCharacteristic = 'writeCharacteristic';
  static const String setNotify = 'setNotify';
  static const String startForegroundService = 'startForegroundService';
  static const String stopForegroundService = 'stopForegroundService';
}

/// Event types delivered on [BluetoothChannels.events].
abstract final class BluetoothEventTypes {
  const BluetoothEventTypes._();

  static const String stateChanged = 'stateChanged';
  static const String scanResult = 'scanResult';
  static const String scanStateChanged = 'scanStateChanged';
  static const String advertisingChanged = 'advertisingChanged';
  static const String connectionChanged = 'connectionChanged';
  static const String mtuNegotiated = 'mtuNegotiated';
  static const String rssi = 'rssi';
  static const String characteristicChanged = 'characteristicChanged';
  static const String permissionChanged = 'permissionChanged';

  /// Transport-level failure (e.g. scan timeout) with a `ble.*` code.
  static const String transportError = 'transportError';
}
