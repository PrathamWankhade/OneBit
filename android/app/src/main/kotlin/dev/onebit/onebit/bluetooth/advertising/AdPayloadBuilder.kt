package dev.onebit.onebit.bluetooth.advertising

import dev.onebit.onebit.bluetooth.utils.ByteUtils

/**
 * Builds raw BLE advertisement payload chunks (pure logic, JVM-testable).
 *
 * AdvertiseData.Builder covers the common cases; this builder produces the
 * *bytes* used for rotation variants (surviving scan-frequency filtering by
 * peers) and for JVM-level round-trip tests of the wire format. All fields
 * follow the Bluetooth 5 advertising data element layout:
 * `len | type | value`.
 */
object AdPayloadBuilder {

    const val TYPE_FLAGS: Byte = 0x01
    const val TYPE_SHORT_NAME: Byte = 0x08
    const val TYPE_COMPLETE_NAME: Byte = 0x09
    const val TYPE_TX_POWER: Byte = 0x0A
    const val TYPE_MANUFACTURER: Byte = 0xFF.toByte()

    /** Maximum advertising packet payload (default PDU) in octets. */
    const val MAX_AD_LENGTH = 31

    /** Name bytes as the scan response or complete/short local name. */
    fun localName(name: String): ByteArray {
        val bytes = name.toByteArray(Charsets.UTF_8)
        return field(if (bytes.size <= 12) TYPE_SHORT_NAME else TYPE_COMPLETE_NAME, bytes)
    }

    /** Tx power field. */
    fun txPower(powerDb: Int): ByteArray =
        field(TYPE_TX_POWER, byteArrayOf(powerDb.toByte()))

    /** Manufacturer specific data: company id (LE u16) + payload. */
    fun manufacturerData(companyId: Int, payload: ByteArray): ByteArray {
        val data = ByteUtils.concat(ByteUtils.u16le(companyId), payload)
        return field(TYPE_MANUFACTURER, data)
    }

    /** Rotates a stable identity across [variantCount] counter values. */
    fun rotationVariant(
        variantCount: Int,
        variantIndex: Int,
        build: (sequence: Byte) -> ByteArray,
    ): ByteArray {
        val seq = (variantIndex % variantCount.coerceAtLeast(1)).toByte()
        return build(seq)
    }

    private fun field(type: Byte, value: ByteArray): ByteArray {
        require(value.size <= 0xFF) { "AD field too long: ${value.size}" }
        return ByteUtils.concat(byteArrayOf((value.size + 1).toByte(), type), value)
    }
}
