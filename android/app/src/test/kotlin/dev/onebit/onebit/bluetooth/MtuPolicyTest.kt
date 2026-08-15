package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.mtu.MtuPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MtuPolicyTest {

    @Test
    fun `outcome records fallback when peer settles lower`() {
        val outcome = MtuPolicy.outcome(requested = 512, actual = 185)
        assertEquals(512, outcome.requestedMtu)
        assertEquals(185, outcome.actualMtu)
        assertTrue(outcome.fellBack)
    }

    @Test
    fun `exact negotiation does not flag fallback`() {
        val outcome = MtuPolicy.outcome(requested = 512, actual = 512)
        assertFalse(outcome.fellBack)
    }

    @Test
    fun `failed negotiation clamps to the BLE default`() {
        val outcome = MtuPolicy.outcome(requested = 512, actual = 0)
        assertEquals(23, outcome.actualMtu)
        assertTrue(outcome.fellBack)
    }

    @Test
    fun `sub-minimum requested mtu resolves to the default`() {
        val outcome = MtuPolicy.outcome(requested = 3, actual = 3)
        assertEquals(23, outcome.requestedMtu)
        assertEquals(23, outcome.actualMtu)
    }

    @Test
    fun `payload limit deducts the att header`() {
        assertEquals(20, MtuPolicy.payloadLimit(23))
        assertEquals(509, MtuPolicy.payloadLimit(512))
        assertEquals(20, MtuPolicy.payloadLimit(5))
    }

    @Test
    fun `wire map carries requested and actual only`() {
        val wire = MtuPolicy.outcome(512, 185).toWire()
        assertEquals(512, wire["requestedMtu"])
        assertEquals(185, wire["actualMtu"])
    }
}