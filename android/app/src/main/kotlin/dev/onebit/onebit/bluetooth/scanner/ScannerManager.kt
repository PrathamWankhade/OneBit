package dev.onebit.onebit.bluetooth.scanner

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.PowerManager
import dev.onebit.onebit.bluetooth.BleEmitter
import dev.onebit.onebit.bluetooth.BleException
import dev.onebit.onebit.bluetooth.errors.BleErrorCodes
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.rssi.RssiSmoother
import dev.onebit.onebit.bluetooth.utils.UuidUtils
import java.util.concurrent.atomic.AtomicLong

/**
 * BLE central scanning — one scan instance at a time.
 *
 * `passive` maps to the low-power duty cycle with a report delay; `active`
 * requests low-latency. Optional per-device RSSI cadence and duplicate
 * filtering mirror the Dart [dev.onebit.onebit.bluetooth.characteristics.ScanConfig]
 * contract. A hard timeout cancels the scan and emits
 * `ble.scan.timeout` on the transport error event.
 *
 * When `adaptive` is set the scan runs as a duty cycle driven by
 * [AdaptiveScanController]: burst windows after a sighting, relaxed
 * windows while idle, and the deepest profile on battery saver or in the
 * background. When `adaptive` is off the scan runs continuously until
 * stopped or timed out.
 */
class ScannerManager(
    private val adapter: BluetoothAdapter?,
    private val appContext: Context,
) {

    var emitter: BleEmitter? = null

    private val handler = Handler(Looper.getMainLooper())
    private val adaptive = AdaptiveScanController()
    private val powerManager = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
    private val smoothers = mutableMapOf<String, RssiSmoother>()
    private val lastRssiEmit = mutableMapOf<String, Long>()

    var scanId: String? = null
        private set

    private var adaptiveMode = false
    private var backgroundRequested = false
    private var rssiIntervalMs: Long = 0
    private var configuredMode = "active"
    private var configuredServiceUuids: List<String> = emptyList()
    private var configuredDuplicateFilter = true
    private var configuredReportDelayMs = 0
    private var timeoutRunnable: Runnable? = null
    private var cycleRunnable: Runnable? = null
    private var paused = false

    /** Starts a scan and returns its id, or `null` if it could not start. */
    fun startScan(
        mode: String,
        serviceUuids: List<String>,
        duplicateFilter: Boolean,
        timeoutMs: Long?,
        reportDelayMs: Int,
        background: Boolean,
        rssiIntervalMs: Long,
        adaptive: Boolean = true,
    ): String? {
        if (scanId != null) return scanId
        val scanner = adapter?.bluetoothLeScanner ?: run {
            BleLog.w("no BluetoothLeScanner available")
            return null
        }

        val id = "scan-${scanCounter.incrementAndGet()}"
        scanId = id
        this.adaptiveMode = adaptive
        this.backgroundRequested = background
        this.rssiIntervalMs = rssiIntervalMs
        this.configuredMode = mode
        this.configuredServiceUuids = serviceUuids
        this.configuredDuplicateFilter = duplicateFilter
        this.configuredReportDelayMs = reportDelayMs

        try {
            if (adaptive) {
                scheduleAdaptiveWindow()
            } else {
                startWindow(
                    mode = mode,
                    serviceUuids = serviceUuids,
                    duplicateFilter = duplicateFilter,
                    reportDelayMs = reportDelayMs,
                )
            }
        } catch (e: BleException) {
            scanId = null
            throw e
        } catch (e: Exception) {
            BleLog.e("scan could not start", throwable = e)
            scanId = null
            return null
        }

        if (timeoutMs != null && timeoutMs > 0) {
            val runnable = Runnable {
                val toStop = scanId
                if (toStop == id) stopScan(id, timedOut = true)
            }
            timeoutRunnable = runnable
            handler.postDelayed(runnable, timeoutMs)
        }
        return id
    }

    /** Stops [scanId]; safe to call twice. */
    fun stopScan(scanId: String, timedOut: Boolean = false) {
        if (scanId != this.scanId) return
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        cycleRunnable?.let { handler.removeCallbacks(it) }
        cycleRunnable = null
        stopWindow()
        val stoppedId = this.scanId
        this.scanId = null
        if (stoppedId != null) {
            emitter?.send(
                "scanStateChanged",
                mapOf("scanning" to false, "scanId" to stoppedId),
            )
            if (timedOut) {
                emitter?.send(
                    "transportError",
                    mapOf(
                        "code" to BleErrorCodes.SCAN_TIMEOUT,
                        "message" to "scan $stoppedId reached its deadline",
                        "context" to "scan",
                    ),
                )
            }
        }
        smoothers.clear()
        lastRssiEmit.clear()
    }

    /**
     * Suspends an active scan while Doze holds the device (no wakeups, no
     * radio time). The scan id stays valid; [resume] picks it back up.
     */
    fun pause() {
        if (paused || scanId == null) return
        paused = true
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        cycleRunnable?.let { handler.removeCallbacks(it) }
        cycleRunnable = null
        stopWindow()
        BleLog.d("scan paused (Doze)")
    }

    /** Re-opens the paused scan; a no-op when nothing is paused. */
    fun resume() {
        if (!paused) return
        paused = false
        if (scanId != null) {
            if (adaptiveMode) {
                scheduleAdaptiveWindow()
            } else {
                startWindow(
                    mode = configuredMode,
                    serviceUuids = configuredServiceUuids,
                    duplicateFilter = configuredDuplicateFilter,
                    reportDelayMs = configuredReportDelayMs,
                )
            }
        }
        BleLog.d("scan resumed")
    }

    // ---- Duty cycle (adaptive) --------------------------------------------------

    private fun scheduleAdaptiveWindow() {
        if (scanId == null) return
        val batterySaver = powerManager?.isPowerSaveMode == true
        val schedule = adaptive.nextSchedule(backgroundRequested, batterySaver)
        BleLog.d(
            "adaptive scan window=${schedule.windowMs}ms " +
                "pause=${adaptive.pauseMs(schedule)}ms active=${schedule.active} " +
                "batterySaver=$batterySaver",
        )
        startWindow(
            mode = if (schedule.active) "active" else "passive",
            serviceUuids = configuredServiceUuids,
            duplicateFilter = configuredDuplicateFilter,
            reportDelayMs = if (schedule.active) 0 else configuredReportDelayMs,
        )
        val pause = adaptive.pauseMs(schedule)
        if (pause > 0) {
            cycleRunnable?.let { handler.removeCallbacks(it) }
            val runnable = Runnable {
                if (scanId != null) scheduleAdaptiveWindow()
            }
            cycleRunnable = runnable
            handler.postDelayed(runnable, schedule.windowMs + pause)
        }
    }

    // ---- Single window -----------------------------------------------------------

    private fun startWindow(
        mode: String,
        serviceUuids: List<String>,
        duplicateFilter: Boolean,
        reportDelayMs: Int,
    ) {
        val scanner = adapter?.bluetoothLeScanner ?: return
        val filters = buildFilters(serviceUuids)
        val reportDelay = if (mode == "passive") reportDelayMs.toLong() else 0L
        val settings = ScanSettings.Builder()
            .setScanMode(
                if (mode == "active") ScanSettings.SCAN_MODE_LOW_LATENCY
                else ScanSettings.SCAN_MODE_LOW_POWER,
            )
            .setReportDelay(reportDelay)
            .setCallbackType(
                if (duplicateFilter && reportDelay == 0L) ScanSettings.CALLBACK_TYPE_FIRST_MATCH
                else ScanSettings.CALLBACK_TYPE_ALL_MATCHES,
            )
            .build()
        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (e: SecurityException) {
            BleLog.e("scan blocked by permissions", throwable = e)
            val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                BleErrorCodes.PERMISSION_RECOVERY_REQUIRED
            } else {
                BleErrorCodes.LOCATION_REQUIRED
            }
            throw BleException(code, "scan blocked by permissions")
        }
    }

    private fun stopWindow() {
        try {
            adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (e: SecurityException) {
            // Adapter has nothing left to clean up.
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) =
            emitScanResult(result)

        override fun onScanFailed(errorCode: Int) {
            BleLog.w("scan failed: $errorCode")
            timeoutRunnable?.let { handler.removeCallbacks(it) }
            timeoutRunnable = null
            cycleRunnable?.let { handler.removeCallbacks(it) }
            cycleRunnable = null
            val id = scanId
            scanId = null
            if (id != null) {
                emitter?.send(
                    "scanStateChanged",
                    mapOf("scanning" to false, "scanId" to id),
                )
                emitter?.send(
                    "transportError",
                    mapOf(
                        "code" to BleErrorCodes.SCAN_FAILED,
                        "message" to "platform scan failure $errorCode",
                        "context" to "scan",
                    ),
                )
            }
        }
    }

    private fun emitScanResult(result: ScanResult) {
        val emitter = emitter ?: return
        val record = result.scanRecord
        val device = result.device
        val nowMs = System.currentTimeMillis()
        if (adaptiveMode) adaptive.onDeviceSeen(nowMs)

        val name = record?.deviceName ?: device.name

        val addressType = when (device.type) {
            BluetoothDevice.ADDRESS_TYPE_RANDOM -> "random"
            BluetoothDevice.ADDRESS_TYPE_PUBLIC -> "public"
            else -> null
        }
        val manufacturer = linkedMapOf<String, Any?>()
        record?.manufacturerSpecificData?.let { md ->
            for (i in 0 until md.size()) {
                manufacturer[md.keyAt(i).toString()] = md.valueAt(i).toList()
            }
        }
        val serviceData = linkedMapOf<String, Any?>()
        record?.serviceData?.forEach { (key, value) ->
            serviceData[key.uuid.toString()] = value.toList()
        }

        emitter.send(
            "scanResult",
            mapOf(
                "device" to linkedMapOf("id" to device.address)
                    .also { m -> name?.let { m["name"] = it }; addressType?.let { m["addressType"] = it } },
                "rssiDb" to result.rssi,
                "timestamp" to nowMs,
                "connectable" to true,
                "advertisement" to linkedMapOf(
                    "localName" to name,
                    "txPowerLevel" to record?.txPowerLevel,
                    "serviceUuids" to (record?.serviceUuids?.map { it.toString() }
                        ?: emptyList<String>()),
                    "manufacturerData" to manufacturer,
                    "serviceData" to serviceData,
                ),
            ),
        )

        if (rssiIntervalMs > 0) {
            val smoother = smoothers.getOrPut(device.address) { RssiSmoother() }
            val sample = smoother.sample(result.rssi, nowMs)
            val last = lastRssiEmit[device.address] ?: 0L
            if (nowMs - last >= rssiIntervalMs) {
                lastRssiEmit[device.address] = nowMs
                emitter.send(
                    "rssi",
                    mapOf(
                        "deviceId" to device.address,
                        "rssi" to sample.rawDb,
                        "smoothed" to sample.smoothedDb,
                        "timestamp" to nowMs,
                    ),
                )
            }
        }
    }

    private fun buildFilters(serviceUuids: List<String>): List<ScanFilter> =
        serviceUuids.mapNotNull { raw ->
            val normalized = UuidUtils.normalize(raw) ?: return@mapNotNull null
            ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString(normalized)).build()
        }

    fun dispose() {
        scanId?.let { stopScan(it) }
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        cycleRunnable?.let { handler.removeCallbacks(it) }
        cycleRunnable = null
        smoothers.clear()
        lastRssiEmit.clear()
    }

    private companion object {
        private val scanCounter = AtomicLong()
    }
}
