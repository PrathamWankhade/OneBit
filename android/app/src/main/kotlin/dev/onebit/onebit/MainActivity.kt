package dev.onebit.onebit

import android.os.Build
import dev.onebit.onebit.bluetooth.BluetoothChannel
import dev.onebit.onebit.bluetooth.BluetoothManager
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.permissions.PermissionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * OneBit Android host.
 *
 * Registers the platform channels that the Dart [NativeChannelBridge]
 * targets: root introspection, the identity vault and the Bluetooth
 * transport (BLE). The transport object is process-scoped and outlives
 * channel resubscriptions, so the adapter and receivers stay consistent.
 */
class MainActivity : FlutterActivity() {

    /** Hardware-wrapped identity seed vault (identity channel). */
    private val identityKeystore by lazy { IdentityKeystore(this) }

    /** BLE transport orchestrator + channel binding. */
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothChannel: BluetoothChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannels.ROOT,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                PlatformMethods.GET_DEVICE_INFO -> result.success(deviceInfo())
                PlatformMethods.PING -> result.success("pong")
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannels.IDENTITY,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                IdentityMethods.STORE_SEED -> {
                    val alias = call.argument<String>("alias")
                    val seed = call.argument<String>("seed")
                    if (alias == null || seed == null) {
                        result.error("BAD_ARGS", "alias and seed are required", null)
                    } else {
                        try {
                            identityKeystore.storeSeed(alias, seed)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STORE_FAILED", e.message, null)
                        }
                    }
                }
                IdentityMethods.LOAD_SEED -> {
                    val alias = call.argument<String>("alias")
                    if (alias == null) {
                        result.error("BAD_ARGS", "alias is required", null)
                    } else {
                        val seed = identityKeystore.loadSeed(alias)
                        if (seed == null) {
                            result.error(
                                "KEY_NOT_FOUND",
                                "No identity seed for alias $alias",
                                null,
                            )
                        } else {
                            result.success(seed)
                        }
                    }
                }
                IdentityMethods.HAS_IDENTITY -> {
                    val alias = call.argument<String>("alias")
                    result.success(alias != null && identityKeystore.hasIdentity(alias))
                }
                IdentityMethods.DELETE_IDENTITY -> {
                    val alias = call.argument<String>("alias")
                    result.success(alias != null && identityKeystore.deleteIdentity(alias))
                }
                else -> result.notImplemented()
            }
        }

        bindBluetooth(flutterEngine)
    }

    /** Binds the BLE transport once per engine configuration. */
    private fun bindBluetooth(flutterEngine: FlutterEngine) {
        if (bluetoothChannel != null) return
        val manager = runCatching { BluetoothManager(this) }.getOrElse { error ->
            BleLog.e("Bluetooth transport unavailable", throwable = error)
            return
        }
        bluetoothManager = manager
        bluetoothChannel = BluetoothChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            manager,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PermissionManager.PERMISSION_REQUEST_CODE) {
            bluetoothManager?.permissionResult()
        }
    }

    override fun onDestroy() {
        bluetoothChannel = null
        bluetoothManager?.dispose()
        bluetoothManager = null
        super.onDestroy()
    }

    /** Snapshot of device metadata safe to hand to Dart. */
    private fun deviceInfo(): Map<String, Any> = mapOf(
        "androidSdkInt" to Build.VERSION.SDK_INT,
        "model" to Build.MODEL,
        "manufacturer" to Build.MANUFACTURER,
        "brand" to Build.BRAND,
    )
}

/** Stable channel/method identifiers mirrored from Dart. */
private object PlatformChannels {
    const val ROOT = "dev.onebit.onebit/native"
    const val IDENTITY = "dev.onebit.onebit/identity"
}

private object PlatformMethods {
    const val GET_DEVICE_INFO = "getDeviceInfo"
    const val PING = "ping"
}

private object IdentityMethods {
    const val STORE_SEED = "storeSeed"
    const val LOAD_SEED = "loadSeed"
    const val HAS_IDENTITY = "hasIdentity"
    const val DELETE_IDENTITY = "deleteIdentity"
}
