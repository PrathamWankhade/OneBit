package dev.onebit.onebit.bluetooth

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import androidx.core.content.ContextCompat
import dev.onebit.onebit.bluetooth.advertising.AdvertiserManager
import dev.onebit.onebit.bluetooth.connection.ConnectionManager
import dev.onebit.onebit.bluetooth.errors.BleErrorCodes
import dev.onebit.onebit.bluetooth.foreground.ForegroundServiceManager
import dev.onebit.onebit.bluetooth.gatt.GattClientManager
import dev.onebit.onebit.bluetooth.gatt.GattServerManager
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.mtu.MtuOutcome
import dev.onebit.onebit.bluetooth.mtu.MtuPolicy
import dev.onebit.onebit.bluetooth.permissions.PermissionManager
import dev.onebit.onebit.bluetooth.scanner.ScannerManager
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

/**
 * The transport orchestrator: owns the adapter, the managers and the
 * receivers, and exposes the exact command surface the Dart repository
 * calls. Every method returns a JSON-serializable map (or a future of one);
 * failures surface as [BleException] which the channel maps onto
 * `ble.*` error codes.
 */
class BluetoothManager(private val activity: Activity) {

    private val appContext = activity.applicationContext
    private val systemBluetooth = appContext.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
    private val adapter: BluetoothAdapter? = systemBluetooth?.adapter

    private val permissionManager: PermissionManager by lazy {
        val adapt = adapter ?: throw BleException(BleErrorCodes.ADAPTER_UNAVAILABLE, "no Bluetooth adapter")
        PermissionManager(adapt)
    }
    private val foreground = ForegroundServiceManager(appContext)
    private val scanner = ScannerManager(adapter, appContext)
    private val advertiser = AdvertiserManager(adapter)
    private val gattClient = GattClientManager(appContext)
    private val connection = ConnectionManager(gattClient)
    private val gattServer = GattServerManager(appContext)

    /** Set by the channel when the Dart event stream is listening. */
    @Volatile
    var emitter: BleEmitter? = null

    private var deviceId: String = "onebit-device"
    private var receiversRegistered = false

    init {
        scanner.emitter = emitterProvider()
        advertiser.emitter = emitterProvider()
        connection.emitter = emitterProvider()
        gattServer.emitter = emitterProvider()
    }

    private fun emitterProvider() = BleEmitter { event, payload ->
        emitter?.send(event, payload)
    }

    // ---- Lifecycle -------------------------------------------------------------

    /** Called from the host once the event channel is being listened to. */
    fun attach(deviceId: String) {
        this.deviceId = deviceId
        registerReceivers()
    }

    fun detach() {
        emitter = null
    }

    fun dispose() {
        scanner.dispose()
        advertiser.dispose()
        connection.dispose()
        gattServer.stop()
        foreground.stop()
        if (receiversRegistered) {
            runCatching {
                appContext.unregisterReceiver(adapterReceiver)
                appContext.unregisterReceiver(batteryReceiver)
                appContext.unregisterReceiver(idleReceiver)
            }
            receiversRegistered = false
        }
    }

    // ---- State ---------------------------------------------------------------

    fun getState(): Map<String, Any> = mapOf(
        "state" to radioStateName(),
        "permission" to permissionManager.currentState(activity),
        "batterySaver" to batterySaver,
        "maxConcurrentConnections" to ConnectionManager.MAX_CONCURRENT_LINKS,
        "recoveryRequired" to permissionManager.hasPermanentlyDenied(activity),
    )

    private fun radioStateName(): String {
        val adapter = adapter ?: return "unavailable"
        return when (adapter.state) {
            BluetoothAdapter.STATE_ON -> "ready"
            BluetoothAdapter.STATE_TURNING_ON -> "initializing"
            BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_OFF -> "off"
            else -> "unknown"
        }
    }

    private val batterySaver: Boolean
        get() {
            val power = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                ?: return false
            return power.isPowerSaveMode
        }

    // ---- Receivers ------------------------------------------------------------

    private fun registerReceivers() {
        if (receiversRegistered) return
        val adapterFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        ContextCompat.registerReceiver(
            appContext, adapterReceiver, adapterFilter, ContextCompat.RECEIVER_EXPORTED,
        )
        val batteryFilter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        ContextCompat.registerReceiver(
            appContext, batteryReceiver, batteryFilter, ContextCompat.RECEIVER_EXPORTED,
        )
        val idleFilter = IntentFilter(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
        ContextCompat.registerReceiver(
            appContext, idleReceiver, idleFilter, ContextCompat.RECEIVER_EXPORTED,
        )
        receiversRegistered = true
    }

    private val adapterReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
            val newState = intent.getIntExtra(
                BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR,
            )
            val name = when (newState) {
                BluetoothAdapter.STATE_ON -> "ready"
                BluetoothAdapter.STATE_TURNING_ON -> "initializing"
                else -> "off"
            }
            emitRadio(name)
        }
    }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == PowerManager.ACTION_POWER_SAVE_MODE_CHANGED) {
                emitRadio(radioStateName())
            }
        }
    }

    /**
     * Doze awareness: scanning is the transport's most expensive activity, so
     * it is suspended while the device is in device-idle and re-opened (with
     * the same schedule) when Doze lifts. Connections and the foreground
     * service are exempt from Doze and keep working.
     */
    private val idleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED) return
            val power = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                ?: return
            if (power.isDeviceIdleMode) {
                scanner.pause()
            } else {
                scanner.resume()
            }
        }
    }

    private fun emitRadio(stateName: String) {
        emitter?.send(
            "stateChanged",
            mapOf(
                "state" to stateName,
                "permission" to permissionManager.currentState(activity),
                "batterySaver" to batterySaver,
                "maxConcurrentConnections" to ConnectionManager.MAX_CONCURRENT_LINKS,
                "recoveryRequired" to permissionManager.hasPermanentlyDenied(activity),
            ),
        )
    }

    // ---- Commands ---------------------------------------------------------------

    fun requestPermissions(): CompletableFuture<Map<String, Any>> {
        val future = CompletableFuture<Map<String, Any>>()
        permissionManager.request(activity) { permission ->
            future.complete(mapOf("permission" to permission))
            emitter?.send("permissionChanged", mapOf("permission" to permission))
        }
        return future
    }

    /** Recovery path after a denied permission; safe to retry freely. */
    fun recoverPermissions(): CompletableFuture<Map<String, Any>> {
        val future = CompletableFuture<Map<String, Any>>()
        permissionManager.recover(activity) { permission ->
            future.complete(mapOf("permission" to permission))
            emitter?.send("permissionChanged", mapOf("permission" to permission))
        }
        return future
    }

    /** Forwards the activity's permission result into the pending request. */
    fun permissionResult() {
        permissionManager.onRequestPermissionsResult(activity)
    }

    fun startScan(args: Map<*, *>): Map<String, Any> {
        requireRadioReady()
        val id = scanner.startScan(
            mode = args["mode"] as? String ?: "passive",
            serviceUuids = (args["serviceUuids"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
            duplicateFilter = args["duplicateFilter"] as? Boolean ?: true,
            timeoutMs = (args["timeoutMs"] as? Number)?.toLong(),
            reportDelayMs = if (args["mode"] == "passive") PASSIVE_REPORT_DELAY_MS else 0,
            background = args["background"] as? Boolean ?: false,
            rssiIntervalMs = (args["rssiIntervalMs"] as? Number)?.toLong() ?: 0,
            adaptive = args["adaptive"] as? Boolean ?: true,
        ) ?: throw BleException(BleErrorCodes.SCAN_FAILED, "scan could not start")
        if (args["background"] == true) foreground.start("background scan $id")
        return mapOf("id" to id)
    }

    fun stopScan(args: Map<*, *>): Map<String, Any> {
        val scanId = args["scanId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "scanId required",
        )
        scanner.stopScan(scanId)
        foreground.stop()
        return emptyMap()
    }

    fun startAdvertising(args: Map<*, *>): Map<String, Any> {
        requireRadioReady()
        // Advertising is the peripheral role: serve the GATT server the
        // moment we present a service so inbound peers find it.
        if (args["serviceUuid"] != null) {
            gattServer.start(deviceId)
        }
        val id = advertiser.startAdvertising(
            mode = args["mode"] as? String ?: "balanced",
            serviceUuid = args["serviceUuid"] as? String,
            manufacturerId = (args["manufacturerId"] as? Number)?.toInt(),
            manufacturerData = (args["manufacturerData"] as? List<*>)?.mapNotNull { it as? Int },
            localName = args["localName"] as? String,
            txPowerBoost = (args["txPower"] as? Number)?.toInt() ?: 0,
            background = args["background"] as? Boolean ?: false,
            rotationCount = (args["rotationCount"] as? Number)?.toInt() ?: 0,
        ) ?: throw BleException(BleErrorCodes.ADVERTISE_FAILED, "advertising could not start")
        if (args["background"] == true) foreground.start("background advertising $id")
        return mapOf("id" to id)
    }

    fun stopAdvertising(args: Map<*, *>): Map<String, Any> {
        val advertisingId = args["advertisingId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "advertisingId required",
        )
        advertiser.stopAdvertising(advertisingId)
        gattServer.stop()
        foreground.stop()
        return emptyMap()
    }

    /** Standalone GATT server session (peripheral without advertising). */
    fun startGattServer(args: Map<*, *>): Map<String, Any> {
        val serverDeviceId = args["deviceId"] as? String ?: deviceId
        if (!gattServer.start(serverDeviceId)) {
            throw BleException(BleErrorCodes.GATT_FAILED, "gatt server could not start")
        }
        return mapOf("deviceId" to serverDeviceId)
    }

    fun stopGattServer(): Map<String, Any> {
        gattServer.stop()
        return emptyMap()
    }

    fun connect(args: Map<*, *>): Map<String, Any> {
        requireRadioReady()
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        val device = runCatching { adapter!!.getRemoteDevice(deviceId) }.getOrElse {
            throw BleException(BleErrorCodes.INVALID_ARGUMENTS, "bad device address: $deviceId")
        }
        val options = ConnectionManager.ConnectionOptions.from(args)
        if (!connection.connect(device, options)) {
            throw BleException(BleErrorCodes.CONNECT_FAILED, "connect not scheduled for $deviceId")
        }
        return emptyMap()
    }

    fun disconnect(args: Map<*, *>): Map<String, Any> {
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        connection.disconnect(deviceId)
        return emptyMap()
    }

    fun readRssi(args: Map<*, *>): CompletableFuture<Map<String, Any>> {
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        return connection.readRssiAndWait(deviceId)
    }

    fun requestMtu(args: Map<*, *>): CompletableFuture<Map<String, Any>> {
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        val mtu = (args["mtu"] as? Number)?.toInt() ?: MtuPolicy.DEFAULT_MTU
        return connection.requestMtuAndWait(deviceId, mtu)
            .thenApply { it.toWire() }
    }

    fun discoverServices(args: Map<*, *>): CompletableFuture<Map<String, Any>> {
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        return connection.discoverServices(deviceId)
            .thenApply { services -> mapOf("services" to services) }
    }

    fun readCharacteristic(args: Map<*, *>): CompletableFuture<Map<String, Any>> {
        val (deviceId, serviceUuid, charUuid) = characteristicArgs(args)
        return connection.readCharacteristicAndWait(deviceId, serviceUuid, charUuid)
            .thenApply { value -> mapOf("value" to value) }
    }

    fun writeCharacteristic(args: Map<*, *>): CompletableFuture<Map<String, Any>> {
        val (deviceId, serviceUuid, charUuid) = characteristicArgs(args)
        val value = (args["value"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?.map { it.toByte() }?.toByteArray()
            ?: throw BleException(BleErrorCodes.INVALID_ARGUMENTS, "value required")
        val withoutResponse = args["withoutResponse"] as? Boolean ?: false
        val reliable = args["reliable"] as? Boolean ?: false
        return connection.writeCharacteristicAndWait(deviceId, serviceUuid, charUuid, value, withoutResponse, reliable)
            .thenApply { if (it) emptyMap() else throw BleException(BleErrorCodes.WRITE_FAILED, "write failed") }
    }

    fun setNotify(args: Map<*, *>): Map<String, Any> {
        val (deviceId, serviceUuid, charUuid) = characteristicArgs(args)
        val enabled = args["enabled"] as? Boolean ?: true
        val indications = args["indications"] as? Boolean ?: false
        if (!connection.setNotify(deviceId, serviceUuid, charUuid, enabled, indications)) {
            throw BleException(BleErrorCodes.NOTIFY_FAILED, "notification not registered")
        }
        return emptyMap()
    }

    fun startForegroundService(args: Map<*, *>): Map<String, Any> {
        val reason = args["reason"] as? String ?: "Bluetooth transport"
        foreground.start(reason)
        return emptyMap()
    }

    fun stopForegroundService(): Map<String, Any> {
        foreground.stop()
        return emptyMap()
    }

    private fun characteristicArgs(args: Map<*, *>): Triple<String, String, String> {
        val deviceId = args["deviceId"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "deviceId required",
        )
        val serviceUuid = args["serviceUuid"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "serviceUuid required",
        )
        val charUuid = args["characteristicUuid"] as? String ?: throw BleException(
            BleErrorCodes.INVALID_ARGUMENTS, "characteristicUuid required",
        )
        return Triple(deviceId, serviceUuid, charUuid)
    }

    private fun requireRadioReady() {
        val adapter = adapter ?: throw BleException(BleErrorCodes.ADAPTER_UNAVAILABLE, "no adapter")
        if (!adapter.isEnabled) {
            throw BleException(BleErrorCodes.ADAPTER_DISABLED, "adapter is off")
        }
    }

    companion object {
        private const val PASSIVE_REPORT_DELAY_MS = 5_000
    }
}

/** Transport-level failure carrying the stable `ble.*` code. */
class BleException(val code: String, message: String) : Exception(message)

/** Convenience: waits a bounded time for a future and unwraps errors. */
fun <T> CompletableFuture<T>.awaitOrFail(timeoutMs: Long = 10_000): T {
    try {
        return this.get(timeoutMs, TimeUnit.MILLISECONDS)
    } catch (e: Exception) {
        // Unwrap the Completion/Execution chain to the first BleException.
        var failure: BleException? = e as? BleException
        var cursor: Throwable? = e.cause
        var depth = 0
        while (failure == null && cursor != null && depth < 8) {
            failure = cursor as? BleException
            cursor = cursor.cause
            depth++
        }
        throw failure ?: BleException(
            BleErrorCodes.BUSY, "operation did not complete: ${e.message}",
        )
    }
}