package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.advertising.AdPayloadBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AdPayloadBuilderTest {

    @Test
    fun `local name field carries the name bytes`() {
        val field = AdPayloadBuilder.localName("OB")
        assertEquals(3, field[0].toInt()) // len = type byte + 2 name bytes
        assertEquals(AdPayloadBuilder.TYPE_SHORT_NAME, field[1])
        assertEquals('O'.code, field[2].toInt())
        assertEquals('B'.code, field[3].toInt())
    }

    @Test
    fun `long names use the complete-name type`() {
        val long = "onebit-super-long-name-for-rotation"
        val field = AdPayloadBuilder.localName(long)
        assertEquals(AdPayloadBuilder.TYPE_COMPLETE_NAME, field[1])
    }

    @Test
    fun `tx power encodes a signed byte`() {
        val field = AdPayloadBuilder.txPower(-4)
        assertEquals(AdPayloadBuilder.TYPE_TX_POWER, field[1])
        assertEquals(-4, field[2].toInt())
    }

    @Test
    fun `manufacturer data is little-endian company id plus payload`() {
        val field = AdPayloadBuilder.manufacturerData(276, byteArrayOf(0x01, 0x02))
        // len(5) + type(0xFF) + 0x14 0x01 (276 LE) + 0x01 0x02 — len includes the type octet
        assertEquals(5, field[0].toInt())
        assertEquals(AdPayloadBuilder.TYPE_MANUFACTURER, field[1])
        assertEquals(0x14, field[2].toInt())
        assertEquals(0x01, field[3].toInt())
        assertEquals(0x01, field[4].toInt())
        assertEquals(0x02, field[5].toInt())
    }

    @Test
    fun `rotation cycles the sequence byte`() {
        val v0 = AdPayloadBuilder.rotationVariant(4, 0) { seq ->
            AdPayloadBuilder.manufacturerData(276, byteArrayOf(seq))
        }
        val v3 = AdPayloadBuilder.rotationVariant(4, 3) { seq ->
            AdPayloadBuilder.manufacturerData(276, byteArrayOf(seq))
        }
        assertEquals(0x00, v0[4].toInt())
        assertEquals(0x03, v3[4].toInt())
    }

    @Test
    fun `oversized fields are rejected`() {
        val name = "x".repeat(256)
        assertThrows(IllegalArgumentException::class.java) {
            AdPayloadBuilder.localName(name)
        }
    }

    @Test
    fun `payload budget respects the ad limit`() {
        val name = AdPayloadBuilder.localName("x".repeat(24))
        assertTrue(name.size <= AdPayloadBuilder.MAX_AD_LENGTH)
    }
}