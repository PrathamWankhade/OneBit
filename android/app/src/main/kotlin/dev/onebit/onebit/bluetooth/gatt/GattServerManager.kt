package dev.onebit.onebit.bluetooth.gatt

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.ParcelUuid
import dev.onebit.onebit.bluetooth.BleEmitter
import dev.onebit.onebit.bluetooth.characteristics.CharacteristicProfile
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.uuids.Uuids
import java.util.UUID

/**
 * GATT *server* side for the probe/echo service.
 *
 * OneBit generally acts as the GATT central, but a node may also serve the
 * probe service so peers can verify symmetric transport health. The server
 * answers `ID` reads with this device's stable id and echoes writes back
 * through the notification pipeline: peers that enable the echo CCCD
 * receive every accepted write as a notification (or indication) as well as
 * the write response. Subscriptions are tracked per peer and dropped when
 * the peer disconnects.
 */
@SuppressLint("MissingPermission")
class GattServerManager(context: Context) {

    var emitter: BleEmitter? = null

    private val appContext = context.applicationContext
    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
    private var server: BluetoothGattServer? = null
    private var deviceId: String = ""
    private var running = false

    /** Peer address → `true` when the echo characteristic is an indication. */
    private val subscribers = mutableMapOf<String, Boolean>()

    /** Peer address → `true` when the communication characteristic is an indication. */
    private val commSubscribers = mutableMapOf<String, Boolean>()

    /** Opens the server and registers the probe service (idempotent). */
    fun start(deviceId: String): Boolean {
        if (running) return true
        this.deviceId = deviceId
        val manager = bluetoothManager ?: return false
        val opened = try {
            manager.openGattServer(appContext, serverCallback)
        } catch (e: SecurityException) {
            BleLog.e("gatt server blocked", throwable = e)
            null
        } catch (e: Exception) {
            BleLog.e("gatt server unavailable", throwable = e)
            null
        }
        server = opened ?: return false
        registerProbeService()
        registerCommunicationService()
        running = true
        return true
    }

    fun stop() {
        if (!running) return
        subscribers.clear()
        commSubscribers.clear()
        runCatching { server?.clearServices() }
        runCatching { server?.close() }
        server = null
        running = false
    }

    private fun registerProbeService() {
        val service = BluetoothGattService(
            UUID.fromString(Uuids.PROBE_SERVICE),
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )
        val idChar = BluetoothGattCharacteristic(
            UUID.fromString(Uuids.ID_CHARACTERISTIC),
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        val echoChar = BluetoothGattCharacteristic(
            UUID.fromString(Uuids.ECHO_CHARACTERISTIC),
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        // CCCD: peers enable echo notifications/indications by writing it.
        echoChar.addDescriptor(
            BluetoothGattDescriptor(
                CharacteristicProfile.CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or
                    BluetoothGattDescriptor.PERMISSION_WRITE,
            ),
        )
        service.addCharacteristic(idChar)
        service.addCharacteristic(echoChar)
        runCatching { server?.addService(service) }
            .onSuccess { BleLog.d("probe service registered") }
    }

    private fun registerCommunicationService() {
        val service = BluetoothGattService(
            UUID.fromString(Uuids.ONEBIT_SERVICE),
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )
        val commChar = BluetoothGattCharacteristic(
            UUID.fromString(Uuids.COMMUNICATION_CHARACTERISTIC),
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        commChar.addDescriptor(
            BluetoothGattDescriptor(
                CharacteristicProfile.CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or
                    BluetoothGattDescriptor.PERMISSION_WRITE,
            ),
        )
        service.addCharacteristic(commChar)
        runCatching { server?.addService(service) }
            .onSuccess { BleLog.d("communication service registered") }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic,
        ) {
            val bytes = if (characteristic.uuid == UUID.fromString(Uuids.ID_CHARACTERISTIC)) {
                deviceId.toByteArray(Charsets.UTF_8)
            } else {
                ByteArray(0)
            }
            server?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, offset, bytes,
            )
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            val isEcho = characteristic.uuid == UUID.fromString(Uuids.ECHO_CHARACTERISTIC)
            val isComm = characteristic.uuid == UUID.fromString(Uuids.COMMUNICATION_CHARACTERISTIC)
            if ((isEcho || isComm) && !preparedWrite) {
                characteristic.value = value
                if (isEcho) {
                    emitEcho(device, value, indications = false)
                    notifySubscribers(device, value)
                }
                if (isComm) {
                    emitCommunication(device, value, indications = false)
                    notifyCommSubscribers(device, value)
                }
            }
            server?.sendResponse(
                device,
                requestId,
                if (isEcho || isComm) BluetoothGatt.GATT_SUCCESS
                else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                offset,
                null,
            )
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor,
        ) {
            server?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, offset, descriptor.value,
            )
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            descriptor.value = value
            if (descriptor.uuid == CharacteristicProfile.CCCD_UUID) {
                if (value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
                    subscribers.remove(device.address)
                    commSubscribers.remove(device.address)
                } else {
                    val isIndication = value.contentEquals(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
                    subscribers[device.address] = isIndication
                    commSubscribers[device.address] = isIndication
                }
            }
            server?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null,
            )
        }

        override fun onConnectionStateChange(
            device: BluetoothDevice,
            status: Int,
            newState: Int,
        ) {
            if (newState == BluetoothGattServer.STATE_DISCONNECTED) {
                subscribers.remove(device.address)
                commSubscribers.remove(device.address)
            }
            BleLog.d(
                "server ${if (newState == BluetoothGattServer.STATE_CONNECTED) "connected" else "disconnected"} " +
                    "to ${device.address}",
            )
        }
    }

    /** Pushes [value] to every peer that enabled the echo CCCD. */
    private fun notifySubscribers(device: BluetoothDevice, value: ByteArray) {
        val gattServer = server ?: return
        val echoChar = gattServer
            .getService(UUID.fromString(Uuids.PROBE_SERVICE))
            ?.getCharacteristic(UUID.fromString(Uuids.ECHO_CHARACTERISTIC)) ?: return
        echoChar.value = value
        subscribers.forEach { (address, indications) ->
            val peer = gattServer.connectedDevices.firstOrNull { it.address == address } ?: return@forEach
            BleLog.d("notifying $address (indications=$indications)")
            runCatching {
                gattServer.notifyCharacteristicChanged(peer, echoChar, indications, value)
            }
        }
        emitEcho(device, value, indications = true)
    }

    private fun emitEcho(device: BluetoothDevice, value: ByteArray, indications: Boolean) {
        emitter?.send(
            "characteristicChanged",
            mapOf(
                "deviceId" to device.address,
                "serviceUuid" to Uuids.PROBE_SERVICE,
                "characteristicUuid" to Uuids.ECHO_CHARACTERISTIC,
                "value" to value.toList(),
                "indication" to indications,
            ),
        )
    }

    private fun emitCommunication(device: BluetoothDevice, value: ByteArray, indications: Boolean) {
        emitter?.send(
            "characteristicChanged",
            mapOf(
                "deviceId" to device.address,
                "serviceUuid" to Uuids.ONEBIT_SERVICE,
                "characteristicUuid" to Uuids.COMMUNICATION_CHARACTERISTIC,
                "value" to value.toList(),
                "indication" to indications,
            ),
        )
    }

    /** Pushes [value] to every peer that enabled the communication CCCD. */
    private fun notifyCommSubscribers(device: BluetoothDevice, value: ByteArray) {
        val gattServer = server ?: return
        val commChar = gattServer
            .getService(UUID.fromString(Uuids.ONEBIT_SERVICE))
            ?.getCharacteristic(UUID.fromString(Uuids.COMMUNICATION_CHARACTERISTIC)) ?: return
        commChar.value = value
        commSubscribers.forEach { (address, indications) ->
            val peer = gattServer.connectedDevices.firstOrNull { it.address == address } ?: return@forEach
            BleLog.d("notifying comm $address (indications=$indications)")
            runCatching {
                gattServer.notifyCharacteristicChanged(peer, commChar, indications, value)
            }
        }
        emitCommunication(device, value, indications = true)
    }
}