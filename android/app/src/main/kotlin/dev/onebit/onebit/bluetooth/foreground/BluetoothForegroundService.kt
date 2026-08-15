package dev.onebit.onebit.bluetooth.foreground

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import dev.onebit.onebit.R
import dev.onebit.onebit.bluetooth.logging.BleLog

/**
 * Secure foreground service keeping the transport alive while the app is
 * backgrounded (screen-off discovery/connection, Android 8+).
 *
 * Declared in the manifest as `connectedDevice` type: that matches BLE
 * connect/scan/advertise work on Android 14+ and is a safe subset on older
 * platforms. The service is intentionally dumb — all state lives in
 * [dev.onebit.onebit.bluetooth.BluetoothManager] — so it survives
 * Activity death without duplicating logic.
 */
class BluetoothForegroundService : Service() {

    companion object {
        const val NOTIFICATION_ID = 0x0B1E
        const val CHANNEL_ID = "onebit_ble_transport"
        const val EXTRA_REASON = "reason"

        /** True when [service] is currently running in the foreground. */
        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        startAsForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val reason = intent?.getStringExtra(EXTRA_REASON) ?: "Bluetooth transport"
        ensureChannel()
        val notification = buildNotification(reason)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAsForeground() {
        // onStartCommand performs the actual startForeground; onCreate only
        // flips the flag so the manager can observe state synchronously.
    }

    private fun ensureChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bluetooth transport",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { setShowBadge(false) }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(reason: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Bluetooth transport active")
            .setContentText(reason)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }
}
