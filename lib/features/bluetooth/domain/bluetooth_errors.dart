/// Stable machine-readable error codes for the Bluetooth transport.
///
/// Values are mirrored from `BleErrorCodes.kt`; the native side emits these
/// verbatim so the Dart repository maps them 1:1 onto a [PlatformFailure]
/// without string sniffing. UI switches on the code, never on text.
abstract final class BluetoothErrorCodes {
  const BluetoothErrorCodes._();

  static const String adapterDisabled = 'ble.disabled';
  static const String adapterUnavailable = 'ble.unsupported';
  static const String permissionDenied = 'ble.permission.denied';
  static const String permissionRecoveryRequired = 'ble.permission.recovery';
  static const String locationRequired = 'ble.permission.location';
  static const String scanFailed = 'ble.scan.failed';
  static const String scanTimeout = 'ble.scan.timeout';
  static const String advertiseFailed = 'ble.advertise.failed';
  static const String advertiseTimeout = 'ble.advertise.timeout';
  static const String connectFailed = 'ble.connect.failed';
  static const String connectTimeout = 'ble.connect.timeout';
  static const String connectionLost = 'ble.connection.lost';
  static const String disconnectFailed = 'ble.disconnect.failed';
  static const String mtuFailed = 'ble.mtu.failed';
  static const String gattFailed = 'ble.gatt.failed';
  static const String readFailed = 'ble.read.failed';
  static const String writeFailed = 'ble.write.failed';
  static const String notifyFailed = 'ble.notify.failed';
  static const String busy = 'ble.busy';
  static const String foregroundFailed = 'ble.foreground.failed';
  static const String invalidArguments = 'ble.invalid_arguments';
}
