package dev.onebit.onebit.bluetooth.gatt

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import dev.onebit.onebit.bluetooth.callbacks.GattEventListener
import dev.onebit.onebit.bluetooth.characteristics.CharacteristicProfile
import dev.onebit.onebit.bluetooth.utils.UuidUtils
import java.util.UUID

/**
 * Owns one [BluetoothGatt] handle per device and translates platform
 * callbacks into [GattEventListener] observations. Deliberately stateless
 * about *when* to connect/negotiate — that sequencing lives in the
 * connection layer.
 */
@SuppressLint("MissingPermission")
class GattClientManager(private val context: Context) {

    private val links = mutableMapOf<String, GattLink>()

    /** Opens (or reuses) the GATT link for [device]. */
    fun connect(device: BluetoothDevice, autoReconnect: Boolean, listener: GattEventListener): GattLink? {
        links[device.address]?.takeIf { it.gatt != null }?.let { return it }
        val link = GattLink(device, listener)
        val gatt = try {
            device.connectGatt(context, autoReconnect, link.callback)
        } catch (e: Exception) {
            null
        }
        if (gatt == null) return null
        link.gatt = gatt
        links[device.address] = link
        return link
    }

    fun linkFor(deviceId: String): GattLink? = links[deviceId]

    fun requestMtu(deviceId: String, mtu: Int) {
        links[deviceId]?.gatt?.requestMtu(mtu)
    }

    fun discoverServices(deviceId: String) {
        links[deviceId]?.gatt?.discoverServices()
    }

    /** Finds a characteristic by service/characteristic UUID (short or full). */
    fun characteristicOf(deviceId: String, serviceUuid: String, charUuid: String): BluetoothGattCharacteristic? {
        val gatt = links[deviceId]?.gatt ?: return null
        val service = gatt.getService(UuidUtils.normalize(serviceUuid)?.let(UUID::fromString)) ?: return null
        return service.getCharacteristic(UuidUtils.normalize(charUuid)?.let(UUID::fromString))
    }

    fun readCharacteristic(deviceId: String, serviceUuid: String, charUuid: String): Boolean {
        val char = characteristicOf(deviceId, serviceUuid, charUuid) ?: return false
        return links[deviceId]?.gatt?.readCharacteristic(char) == true
    }

    /**
     * Writes one packet-sized chunk to [charUuid].
     *
     * @param withoutResponse uses the no-ack write type (no callback is
     *   guaranteed for it); long values must then be chunked by the caller.
     * @param maxPacketBytes largest chunk the peer can accept at the
     *   negotiated MTU (`MTU - 3`); the first chunk never exceeds it.
     * @param reliable starts (or continues) a reliable-write session when
     *   true; the caller drives the remaining chunks and must end with
     *   [commitReliable] or [abortReliable].
     */
    fun writeCharacteristic(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
        value: ByteArray,
        withoutResponse: Boolean,
        maxPacketBytes: Int = MAX_PACKET_BYTES,
        reliable: Boolean = false,
    ): Boolean {
        val char = characteristicOf(deviceId, serviceUuid, charUuid) ?: return false
        val link = links[deviceId] ?: return false
        val gatt = link.gatt ?: return false
        if (reliable) {
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            if (!link.reliableSession) {
                if (!gatt.beginReliableWrite()) return false
                link.reliableSession = true
            }
        } else {
            char.writeType = if (withoutResponse) {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            }
        }
        char.value = value.takeAtMost(maxPacketBytes)
        return gatt.writeCharacteristic(char)
    }

    /** Writes the next reliable-write chunk (session must be open). */
    fun writeReliableChunk(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
        value: ByteArray,
        offset: Int,
        maxPacketBytes: Int = MAX_PACKET_BYTES,
    ): Boolean {
        val char = characteristicOf(deviceId, serviceUuid, charUuid) ?: return false
        val gatt = links[deviceId]?.gatt ?: return false
        char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        char.value = value.copyOfRange(offset, (offset + maxPacketBytes).coerceAtMost(value.size))
        return gatt.writeCharacteristic(char)
    }

    /** Commits the open reliable-write session (server applies all chunks). */
    fun commitReliable(deviceId: String): Boolean {
        val link = links[deviceId] ?: return false
        val committed = runCatching { link.gatt?.executeReliableWrite() == true }.getOrDefault(false)
        if (committed) link.reliableSession = false
        return committed
    }

    /** Discards the open reliable-write session. */
    fun abortReliable(deviceId: String): Boolean {
        val link = links[deviceId] ?: return false
        val aborted = runCatching {
            val gatt = link.gatt
            if (gatt != null) {
                gatt.abortReliableWrite()
                true
            } else {
                false
            }
        }.getOrDefault(false)
        link.reliableSession = false
        return aborted
    }

    fun setNotify(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
        enabled: Boolean,
        indications: Boolean,
    ): Boolean {
        val char = characteristicOf(deviceId, serviceUuid, charUuid) ?: return false
        val gatt = links[deviceId]?.gatt ?: return false
        if (!gatt.setCharacteristicNotification(char, enabled)) return false
        val cccd = char.getDescriptor(CharacteristicProfile.CCCD_UUID) ?: return false
        val value = when {
            !enabled -> BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            indications -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            else -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        }
        cccd.value = value
        return gatt.writeDescriptor(cccd)
    }

    fun readRssi(deviceId: String) {
        links[deviceId]?.gatt?.readRemoteRssi()
    }

    /** Closes the link for [deviceId]; pending calls resolve as failures. */
    fun close(deviceId: String) {
        links.remove(deviceId)?.close()
    }

    fun closeAll() {
        links.values.forEach { it.close() }
        links.clear()
    }

    /** One open connection handle with an internal callback bridge. */
    inner class GattLink internal constructor(
        internal val device: BluetoothDevice,
        internal val listener: GattEventListener,
    ) {
        internal var gatt: BluetoothGatt? = null
            set(value) {
                field = value
                if (value == null) isConnected = false
            }

        var isConnected: Boolean = false
            private set

        /** True while a begin→write→write→commit reliable session is open. */
        var reliableSession: Boolean = false
            internal set

        fun serviceUuidOf(characteristic: BluetoothGattCharacteristic): String {
            val service = gatt?.services?.firstOrNull { it.characteristics.contains(characteristic) }
            return service?.uuid?.toString() ?: ""
        }

        internal val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                isConnected = newState == BluetoothProfile.STATE_CONNECTED
                listener.onGattConnectionChanged(device.address, isConnected, status)
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                listener.onMtuChanged(device.address, mtu, status)
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                listener.onServicesDiscovered(device.address, status)
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                listener.onCharacteristicRead(
                    device.address, characteristic.uuid.toString(),
                    characteristic.value ?: ByteArray(0), status,
                )
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                listener.onCharacteristicWrite(device.address, characteristic.uuid.toString(), status)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                listener.onCharacteristicChanged(
                    device.address, serviceUuidOf(characteristic),
                    characteristic.uuid.toString(), characteristic.value ?: ByteArray(0),
                )
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                listener.onCharacteristicChanged(
                    device.address, serviceUuidOf(characteristic),
                    characteristic.uuid.toString(), value,
                )
            }

            override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
                listener.onRssiRead(device.address, rssi, status)
            }
        }

        internal fun close() {
            reliableSession = false
            runCatching { gatt?.disconnect() }
            runCatching { gatt?.close() }
            gatt = null
        }
    }

    companion object {
        /** Conservative default chunk when the negotiated MTU is unknown. */
        private const val MAX_PACKET_BYTES = 20
    }

    /** First [max] bytes of [value]; the value itself when it already fits. */
    private fun ByteArray.takeAtMost(max: Int): ByteArray =
        if (size <= max) this else copyOfRange(0, max)
}