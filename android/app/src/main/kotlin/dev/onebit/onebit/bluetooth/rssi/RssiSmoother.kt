package dev.onebit.onebit.bluetooth.rssi

import kotlin.math.abs

/**
 * Exponential moving average of RSSI samples (pure logic, JVM-testable).
 *
 * BLE RSSI bounces constantly; consumers (device list, link quality, range
 * heuristics) want a stable estimate plus a volatility flag rather than raw
 * deltas. Newer samples weight more (alpha ~ 0.25), and a wild jump beyond
 * the threshold flags the sample as unstable so higher layers avoid acting
 * on it; calm samples decay the flag again.
 */
final class RssiSmoother(
    private val alpha: Double = 0.25,
    private val unstableThresholdDb: Int = 12,
) {

    private var smoothedDb: Double? = null
    private var jumpCount = 0
    var sampleCount: Int = 0
        private set

    /** Feeds one raw sample and returns the updated estimate + stability. */
    fun sample(rawDb: Int, nowMs: Long = System.currentTimeMillis()): RssiSample {
        val previous = smoothedDb
        sampleCount++
        val estimate = if (previous == null) {
            rawDb.toDouble()
        } else {
            alpha * rawDb + (1 - alpha) * previous
        }
        smoothedDb = estimate
        if (previous != null && abs(estimate - previous) >= unstableThresholdFor(rawDb)) {
            jumpCount++
        } else if (jumpCount > 0) {
            jumpCount--
        }
        return RssiSample(
            rawDb = rawDb,
            smoothedDb = estimate,
            timestampMs = nowMs,
            unstable = jumpCount >= 1,
        )
    }

    private fun unstableThresholdFor(rawDb: Int): Int {
        val floor = if (rawDb < -80) unstableThresholdDb / 2 else unstableThresholdDb
        return floor.coerceAtLeast(4)
    }

    fun currentEstimate(): Double? = smoothedDb
}

/** One smoothed reading, mirroring the Dart [RssiReading] wire shape. */
data class RssiSample(
    val rawDb: Int,
    val smoothedDb: Double,
    val timestampMs: Long,
    val unstable: Boolean,
) {
    fun toWire() = mapOf(
        "rssi" to rawDb,
        "smoothed" to smoothedDb,
        "timestamp" to timestampMs,
    )
}