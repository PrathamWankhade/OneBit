package dev.onebit.onebit.update

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/**
 * Hands a downloaded update to the system installer.
 *
 * The APK is staged in this app's private cache, which the package
 * installer cannot read, so it is published through a FileProvider and the
 * resulting URI is granted for the lifetime of the intent.
 *
 * Nothing here downloads. Byte counts drive the UI, so the fetch stays on
 * the Dart side and this class only answers "what version is this", "may I
 * install", "take me to the screen that says so", and "install this file".
 */
class AppUpdater(private val activity: Activity) {

    /**
     * The version stamped into this build.
     *
     * Gradle took both numbers from `version:` in pubspec.yaml and handed
     * them to the package manager at install time, so this is the same
     * source the release tag is cut from. Reporting it rather than
     * repeating it in Dart is what keeps the About screen, the tag and the
     * update comparison from drifting apart.
     */
    @Suppress("DEPRECATION")
    fun version(): Map<String, String> {
        val info = try {
            activity.packageManager.getPackageInfo(activity.packageName, 0)
        } catch (e: Exception) {
            // Your own package is always installed, so this should not
            // happen — but an empty answer is a clear signal for Dart to
            // keep its fallback rather than a crash on startup.
            return mapOf("version" to "", "buildNumber" to "")
        }

        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }

        return mapOf(
            "version" to (info.versionName ?: ""),
            "buildNumber" to code.toString(),
        )
    }

    /**
     * Whether Android will currently let this app start a package install.
     *
     * False until the user flips the per-app "install unknown apps" switch,
     * which is a one-time step Android refuses to grant silently.
     */
    fun canInstall(): Boolean =
        activity.packageManager.canRequestPackageInstalls()

    /**
     * Opens that switch for this package.
     *
     * Returns false when there is no screen to open, so the caller can say
     * so rather than dropping the user somewhere unexpected.
     */
    fun openInstallPermissionSettings(): Boolean {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * Publishes the file at [path] and hands it to the installer.
     *
     * Returns `null` on success, or a message worth showing the user.
     * Anything escaping here would surface as an unhandled channel failure
     * and leave the UI waiting on a call that never answered.
     */
    fun install(path: String): String? {
        val file = File(path)
        if (!file.isFile || file.length() == 0L) {
            return "The downloaded update could not be found."
        }

        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        return try {
            activity.startActivity(intent)
            null
        } catch (e: ActivityNotFoundException) {
            "No app on this device can install packages."
        } catch (e: SecurityException) {
            "This device is not allowing OneBit to install updates."
        }
    }
}
