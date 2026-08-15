package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.utils.UuidUtils
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UuidUtilsTest {

    private val BLE_BASE = "00000000-0000-1000-8000-00805F9B34FB"

    @Test
    fun `expands a 16-bit short form`() {
        val normalized = UuidUtils.normalize("A1A0")
        assertEquals("0000A1A0-0000-1000-8000-00805F9B34FB".uppercase(), normalized)
    }

    @Test
    fun `expands a 32-bit short form`() {
        val normalized = UuidUtils.normalize("12345678")
        assertEquals("12345678-0000-1000-8000-00805F9B34FB", normalized)
    }

    @Test
    fun `passes a full uuid through unchanged`() {
        val full = "B2A7E5C0-7D0C-4A1B-9C2E-0F1A2B3C4D5E"
        assertEquals(full.uppercase(), UuidUtils.normalize(full))
    }

    @Test
    fun `handles compact 32-hex form`() {
        val hex = "a1a0000000001000800000805f9b34fb"
        val normalized = UuidUtils.normalize(hex)
        assertEquals("A1A00000-0000-1000-8000-00805F9B34FB", normalized)
    }

    @Test
    fun `ignores dashes and case`() {
        assertEquals(
            "A2A0E5C0-7D0C-4A1B-9C2E-0F1A2B3C4D5E",
            UuidUtils.normalize("a2a0e5c0-7d0c-4a1b-9c2e-0f1a2b3c4d5e"),
        )
    }

    @Test
    fun `rejects garbage`() {
        assertNull(UuidUtils.normalize("not-a-uuid"))
        assertNull(UuidUtils.normalize("XYZ"))
        assertNull(UuidUtils.normalize(null))
    }

    @Test
    fun `shortId recovers the 16-bit form when based`() {
        assertEquals("A1A0", UuidUtils.shortId("A1A0"))
    }

    @Test
    fun `shortId null for non-base uuids`() {
        assertNull(UuidUtils.shortId("B2A7E5C0-7D0C-4A1B-9C2E-0F1A2B3C4D5E"))
    }
}