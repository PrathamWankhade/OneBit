package dev.onebit.onebit.bluetooth.foreground

import android.content.Context
import android.content.Intent
import dev.onebit.onebit.bluetooth.logging.BleLog

/**
 * Thin governor over [BluetoothForegroundService].
 *
 * The transport escalates to foreground when a scan/advertisement carries
 * [background] = true (i.e. the mesh wants discovery across screen-off),
 * and drops back when the last one stops. Doesn't care about reasons — the
 * system does the admission on Android 14+ via foreground service types.
 */
class ForegroundServiceManager(private val context: Context) {

    private var activeRequests = 0

    /** Whether the foreground service is expected to be running. */
    val isHeld: Boolean
        get() = activeRequests > 0 && BluetoothForegroundService.isRunning

    /** Starts the foreground service for [reason]; idempotent (ref-counted). */
    fun start(reason: String = "Bluetooth transport") {
        activeRequests = (activeRequests + 1).coerceAtMost(Int.MAX_VALUE - 1)
        val request = activeRequests
        BleLog.d("foreground hold requested ($request merge(s))")
        val intent = Intent(context, BluetoothForegroundService::class.java)
            .putExtra(BluetoothForegroundService.EXTRA_REASON, reason)
        context.startForegroundService(intent)
    }

    /** Releases one hold; stops the service when the last one drops. */
    fun stop() {
        activeRequests = (activeRequests - 1).coerceAtLeast(0)
        if (activeRequests == 0) {
            Intent(context, BluetoothForegroundService::class.java).also {
                context.stopService(it)
            }
        }
    }
}