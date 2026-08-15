package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.scanner.AdaptiveScanController
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdaptiveScanControllerTest {

    private val controller = AdaptiveScanController()

    @Test
    fun `foreground idle uses the relaxed foreground schedule`() {
        val schedule = controller.nextSchedule(
            background = false,
            batterySaver = false,
            nowMs = 0,
        )
        assertEquals(3_000, schedule.windowMs)
        assertEquals(10_000, schedule.intervalMs)
        assertFalse(schedule.active)
    }

    @Test
    fun `device sighting keeps the scan in burst mode`() {
        controller.onDeviceSeen(nowMs = 1_000)
        val schedule = controller.nextSchedule(
            background = false,
            batterySaver = false,
            nowMs = 2_000,
        )
        assertEquals(2_000, schedule.windowMs)
        assertTrue(schedule.active)
    }

    @Test
    fun `burst decays after the retention window`() {
        controller.onDeviceSeen(nowMs = 1_000)
        val schedule = controller.nextSchedule(
            background = false,
            batterySaver = false,
            nowMs = 1_000 + controller.burstRetentionMs + 1,
        )
        assertFalse(schedule.active)
    }

    @Test
    fun `background uses the relaxed background schedule`() {
        val schedule = controller.nextSchedule(
            background = true,
            batterySaver = false,
            nowMs = 0,
        )
        assertEquals(2_000, schedule.windowMs)
        assertEquals(30_000, schedule.intervalMs)
    }

    @Test
    fun `battery saver suppresses burst entirely`() {
        controller.onDeviceSeen(nowMs = 1_000)
        val schedule = controller.nextSchedule(
            background = true,
            batterySaver = true,
            nowMs = 2_000,
        )
        assertEquals(60_000, schedule.intervalMs)
        assertFalse(schedule.active)
    }

    @Test
    fun `battery saver in foreground falls to the deepest schedule`() {
        val schedule = controller.nextSchedule(
            background = false,
            batterySaver = true,
            nowMs = 0,
        )
        assertEquals(30_000, schedule.intervalMs)
    }

    @Test
    fun `pause is the interval minus the window`() {
        val schedule = controller.nextSchedule(
            background = true,
            batterySaver = false,
            nowMs = 0,
        )
        assertEquals(28_000, controller.pauseMs(schedule))
    }

    @Test
    fun `invalid schedules are rejected`() {
        try {
            AdaptiveScanController.ScanSchedule(windowMs = 5_000, intervalMs = 2_000, active = false)
            throw AssertionError("expected IllegalArgumentException")
        } catch (expected: IllegalArgumentException) {
            // Guard works.
        }
    }
}
