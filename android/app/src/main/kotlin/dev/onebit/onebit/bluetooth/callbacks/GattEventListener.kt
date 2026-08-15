package dev.onebit.onebit.bluetooth.callbacks

/**
 * Observations the GATT client layer produces for one connected device.
 *
 * Implemented by
 * [dev.onebit.onebit.bluetooth.connection.ConnectionManager], which turns
 * these into Dart events and drives the multi-step connect sequence. Kept
 * as a plain interface so unit tests can observe the transport without a
 * real stack.
 */
interface GattEventListener {
    fun onGattConnectionChanged(deviceId: String, connected: Boolean, status: Int)
    fun onMtuChanged(deviceId: String, mtu: Int, status: Int)
    fun onServicesDiscovered(deviceId: String, status: Int)
    fun onCharacteristicRead(deviceId: String, characteristicUuid: String, value: ByteArray, status: Int)
    fun onCharacteristicWrite(deviceId: String, characteristicUuid: String, status: Int)
    fun onCharacteristicChanged(deviceId: String, serviceUuid: String, characteristicUuid: String, value: ByteArray)
    fun onRssiRead(deviceId: String, rssi: Int, status: Int)
}
