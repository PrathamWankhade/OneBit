package dev.onebit.onebit.bluetooth.characteristics

import android.bluetooth.BluetoothGattCharacteristic
import dev.onebit.onebit.bluetooth.uuids.Uuids
import java.util.UUID

/**
 * Classifies transport characteristics and derives client-side behavior
 * from their UUIDs.
 *
 * The single place that decides what a characteristic is for — whether a
 * subscription means a notification or an indication, and which property
 * bits a read/write requires. The mesh phase registers its own
 * characteristics here; the transport only knows the probe/echo pair.
 */
object CharacteristicProfile {

    /** Client Characteristic Configuration Descriptor (standard base UUID). */
    val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    /** How a characteristic delivers value updates. */
    enum class NotifyKind {
        /** No value-update path; read/write only. */
        NONE,

        /** Standard notification (ENABLE_NOTIFICATION_VALUE). */
        NOTIFICATION,

        /** Reliable indication (ENABLE_INDICATION_VALUE, acknowledged). */
        INDICATION,
    }

    /**
     * The subscription flavor this transport expects for [characteristicUuid].
     *
     * Transport characteristics are negotiated as notifications; the echo
     * pipe is the reference implementation. Anything unknown defaults to
     * [NotifyKind.NONE] so callers never guess.
     */
    fun notifyKind(characteristicUuid: String?): NotifyKind = when {
        characteristicUuid.equals(Uuids.ECHO_CHARACTERISTIC, ignoreCase = true) ->
            NotifyKind.NOTIFICATION
        else -> NotifyKind.NONE
    }

    /** True when [characteristic] carries the given [property] bit. */
    fun hasProperty(characteristic: BluetoothGattCharacteristic?, property: Int): Boolean =
        characteristic != null && characteristic.properties and property == property

    /** True when [characteristic] can be read. */
    fun supportsRead(characteristic: BluetoothGattCharacteristic?): Boolean =
        hasProperty(characteristic, BluetoothGattCharacteristic.PROPERTY_READ)

    /** True when [characteristic] accepts writes (with or without response). */
    fun supportsWrite(characteristic: BluetoothGattCharacteristic?): Boolean =
        hasProperty(characteristic, BluetoothGattCharacteristic.PROPERTY_WRITE) ||
            hasProperty(characteristic, BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)

    /** True when [characteristic] can notify or indicate. */
    fun supportsSubscribe(characteristic: BluetoothGattCharacteristic?): Boolean =
        hasProperty(characteristic, BluetoothGattCharacteristic.PROPERTY_NOTIFY) ||
            hasProperty(characteristic, BluetoothGattCharacteristic.PROPERTY_INDICATE)
}
