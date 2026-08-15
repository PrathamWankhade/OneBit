package dev.onebit.onebit.bluetooth.errors

/**
 * Stable machine-readable error codes for the Bluetooth transport.
 *
 * Mirrors `BluetoothErrorCodes` on the Dart side verbatim, so the Dart
 * repository can map a [MethodChannelResult] error code onto a
 * [com.onebit.core.errors.PlatformFailure] without string sniffing. The
 * channel handler raises these codes via [android.os.ResultReceiver] errors.
 */
object BleErrorCodes {
    const val ADAPTER_DISABLED = "ble.disabled"
    const val ADAPTER_UNAVAILABLE = "ble.unsupported"
    const val PERMISSION_DENIED = "ble.permission.denied"
    const val PERMISSION_RECOVERY_REQUIRED = "ble.permission.recovery"
    const val LOCATION_REQUIRED = "ble.permission.location"
    const val SCAN_FAILED = "ble.scan.failed"
    const val SCAN_TIMEOUT = "ble.scan.timeout"
    const val ADVERTISE_FAILED = "ble.advertise.failed"
    const val ADVERTISE_TIMEOUT = "ble.advertise.timeout"
    const val CONNECT_FAILED = "ble.connect.failed"
    const val CONNECT_TIMEOUT = "ble.connect.timeout"
    const val CONNECTION_LOST = "ble.connection.lost"
    const val DISCONNECT_FAILED = "ble.disconnect.failed"
    const val MTU_FAILED = "ble.mtu.failed"
    const val GATT_FAILED = "ble.gatt.failed"
    const val READ_FAILED = "ble.read.failed"
    const val WRITE_FAILED = "ble.write.failed"
    const val NOTIFY_FAILED = "ble.notify.failed"
    const val BUSY = "ble.busy"
    const val FOREGROUND_FAILED = "ble.foreground.failed"
    const val INVALID_ARGUMENTS = "ble.invalid_arguments"
}