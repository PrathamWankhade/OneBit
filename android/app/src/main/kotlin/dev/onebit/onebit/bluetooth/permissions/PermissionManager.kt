package dev.onebit.onebit.bluetooth.permissions

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import dev.onebit.onebit.bluetooth.logging.BleLog

/**
 * Bluetooth runtime permission orchestration.
 *
 * Android 12+ gates BLE on the scoped BLUETOOTH_SCAN/CONNECT/ADVERTISE
 * permissions; 10-11 use the legacy BLUETOOTH pair plus location. This
 * manager hides the split: callers only ask "are we granted?" and "ask".
 * The wire names mirror `BluetoothPermissionState` on the Dart side.
 */
class PermissionManager(private val adapter: BluetoothAdapter) {

    companion object {
        const val PERMISSION_REQUEST_CODE = 0x0B1E
    }

    /**
     * True when the user has denied a required permission at least once
     * and the system now refuses to show the rationale dialog (i.e. the
     * "don't ask again" path). Transport operations degrade to error
     * codes instead of crashing in that case.
     */
    fun hasPermanentlyDenied(activity: Activity): Boolean =
        deniedOnce && requiredPermissions().any {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED &&
                !activity.shouldShowRequestPermissionRationale(it)
        }

    private var deniedOnce = false

    /** Permissions required by the manifest for the current platform. */
    fun requiredPermissions(): Array<String> {
        val scoped = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            scoped + Manifest.permission.POST_NOTIFICATIONS
        } else {
            scoped
        }
    }

    /** True when every manifest-required runtime permission is granted. */
    fun hasRequiredPermissions(activity: Activity): Boolean =
        requiredPermissions().all {
            activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }

    /** Grants nothing; reports the current state for the radio snapshot. */
    fun currentState(activity: Activity): String {
        if (!adapter.isEnabled) return "adapterOff"
        val granted = requiredPermissions().count {
            activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
        val total = requiredPermissions().size
        return when (granted) {
            total -> "granted"
            0 -> "notDetermined"
            else -> "partial"
        }
    }

    /**
     * Requests the missing runtime permissions.
     *
     * @param callback invoked with the resulting wire state; always called
     *   (also when nothing needed requesting).
     */
    fun request(activity: Activity, callback: (String) -> Unit) {
        if (!adapter.isEnabled) {
            callback("adapterOff")
            return
        }
        val missing = missingPermissions(activity)
        if (missing.isEmpty()) {
            callback("granted")
            return
        }
        pendingCallback = callback
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    /**
     * Recovery entry point after a permission was denied.
     *
     * Re-requests exactly the still-missing permissions. Callers use this
     * after surfacing [dev.onebit.onebit.bluetooth.errors.BleErrorCodes.PERMISSION_RECOVERY_REQUIRED]
     * or `LOCATION_REQUIRED`; the runtime dialog itself stays in Android's
     * hands. Never crashes when the user keeps denying.
     */
    fun recover(activity: Activity, callback: (String) -> Unit) {
        BleLog.d("permission recovery: state=${currentState(activity)}")
        request(activity, callback)
    }

    /** The runtime permissions not yet granted. */
    fun missingPermissions(activity: Activity): List<String> =
        requiredPermissions().filter {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }

    /** Called from [Activity.onRequestPermissionsResult]. */
    fun onRequestPermissionsResult(activity: Activity) {
        val callback = pendingCallback ?: return
        pendingCallback = null
        val state = currentState(activity)
        deniedOnce = deniedOnce || state != "granted"
        BleLog.d("permission result -> $state")
        callback(state)
    }

    private var pendingCallback: ((String) -> Unit)? = null
}