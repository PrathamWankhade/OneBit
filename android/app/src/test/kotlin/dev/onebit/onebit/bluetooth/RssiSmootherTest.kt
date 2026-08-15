package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.rssi.RssiSmoother
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RssiSmootherTest {

    @Test
    fun `first sample seeds the estimate`() {
        val smoother = RssiSmoother()
        val sample = smoother.sample(-60)
        assertEquals(-60.0, sample.smoothedDb, 0.001)
        assertEquals(1, smoother.sampleCount)
        assertFalse(sample.unstable)
    }

    @Test
    fun `steady samples converge and stay stable`() {
        val smoother = RssiSmoother()
        var estimate = 0.0
        repeat(20) {
            val sample = smoother.sample(-70)
            estimate = sample.smoothedDb
        }
        assertEquals(-70.0, estimate, 0.75)
        assertFalse(smoother.sample(-70).unstable)
    }

    @Test
    fun `wild jumps flag the link as unstable`() {
        val smoother = RssiSmoother(alpha = 0.5, unstableThresholdDb = 8)
        repeat(3) { smoother.sample(-60) }
        val jumping = smoother.sample(-40)
        assertTrue(jumping.unstable)
    }

    @Test
    fun `timestamp is recorded per sample`() {
        val smoother = RssiSmoother()
        val at = System.currentTimeMillis() - 5_000
        val sample = smoother.sample(-66, at)
        assertEquals(at, sample.timestampMs)
    }

    @Test
    fun `wire map matches the dart rssi keys`() {
        val sample = RssiSmoother().sample(-66)
        val wire = sample.toWire()
        assertEquals(-66, wire["rssi"])
        assertEquals(-66.0, wire["smoothed"] as Double, 0.001)
        assertTrue(wire.containsKey("timestamp"))
    }
}