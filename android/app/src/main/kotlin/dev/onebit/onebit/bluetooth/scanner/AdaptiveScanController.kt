package dev.onebit.onebit.bluetooth.scanner

/**
 * Computes scan duty cycles and mode steps (pure logic, JVM-testable).
 *
 * The scanner runs duty-cycled windows instead of one continuous scan:
 * a window scans for [ScanSchedule.windowMs], pauses, then repeats. This
 * controller picks the schedule for the next window from the device's
 * context — burst while a peer was just seen, relaxed while idle, deepest
 * while backgrounded or on battery saver. `active` steps the underlying
 * scan up to low-latency (active scan) when the radio should be doing
 * the work, not the app.
 */
class AdaptiveScanController(
    /** Right after a peer was seen (foreground, any mode). */
    private val burstSchedule: ScanSchedule =
        ScanSchedule(windowMs = 2_000, intervalMs = 3_000, active = true),
    /** Foreground, nothing seen for a while. */
    private val foregroundSchedule: ScanSchedule =
        ScanSchedule(windowMs = 3_000, intervalMs = 10_000, active = false),
    /** Background discovery, normal battery. */
    private val backgroundSchedule: ScanSchedule =
        ScanSchedule(windowMs = 2_000, intervalMs = 30_000, active = false),
    /** Background or battery saver; deepest sleep profile. */
    private val idleSchedule: ScanSchedule =
        ScanSchedule(windowMs = 2_000, intervalMs = 60_000, active = false),
) {

    /** One scan window inside a duty cycle. */
    data class ScanSchedule(
        val windowMs: Long,
        val intervalMs: Long,
        val active: Boolean,
    ) {
        init {
            require(windowMs > 0) { "window must be positive" }
            require(intervalMs >= windowMs) { "interval must cover the window" }
        }
    }

    /** How long a device sighting keeps the scan in burst mode. */
    val burstRetentionMs: Long = 10_000

    /** Timestamp of the most recent device sighting, or null when none. */
    var lastDeviceSeenAtMs: Long? = null
        private set

    /** Records a device sighting so the next window stays in burst mode. */
    fun onDeviceSeen(nowMs: Long = System.currentTimeMillis()) {
        lastDeviceSeenAtMs = nowMs
    }

    /**
     * The schedule for the next scan window.
     *
     * @param background scan was started for background discovery.
     * @param batterySaver the system power-save mode is active.
     * @param nowMs clock reference for burst-retention math.
     */
    fun nextSchedule(
        background: Boolean,
        batterySaver: Boolean,
        nowMs: Long = System.currentTimeMillis(),
    ): ScanSchedule {
        val idleSinceMs = lastDeviceSeenAtMs?.let { nowMs - it }
        val recentlySeen = idleSinceMs != null && idleSinceMs <= burstRetentionMs
        return when {
            // Battery saver dominates everything: never burst on saver.
            batterySaver -> if (background) idleSchedule else backgroundSchedule
            recentlySeen -> burstSchedule
            background -> backgroundSchedule
            else -> foregroundSchedule
        }
    }

    /** The pause between the end of one window and the start of the next. */
    fun pauseMs(schedule: ScanSchedule): Long = (schedule.intervalMs - schedule.windowMs).coerceAtLeast(0)
}
