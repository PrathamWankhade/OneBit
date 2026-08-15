package dev.onebit.onebit.bluetooth.advertising

import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import dev.onebit.onebit.bluetooth.BleEmitter
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.utils.UuidUtils
import java.util.concurrent.atomic.AtomicLong

/**
 * BLE peripheral advertising — one session at a time.
 *
 * Power mode, tx power floor, service UUID, local-name flag and
 * manufacturer data mirror the Dart [AdvertisementConfig]. Screen-off
 * survival is the caller's foreground hold; this class only manages its
 * own session.
 *
 * Rotation: when more than one variant is requested the payload is
 * re-advertised on a mode-dependent cadence with a rotating sequence byte
 * embedded in the manufacturer data, so peers applying scan-frequency
 * filtering still observe this device across windows. Rotation stops with
 * the session.
 */
class AdvertiserManager(private val adapter: BluetoothAdapter?) {

    var emitter: BleEmitter? = null

    private val handler = Handler(Looper.getMainLooper())

    var advertisingId: String? = null
        private set
    private var currentCallback: AdvertiseCallback? = null
    private var rotationRunnable: Runnable? = null
    private var activeEmitted = false

    /** Starts advertising and returns an id, or `null` on failure. */
    fun startAdvertising(
        mode: String,
        serviceUuid: String?,
        manufacturerId: Int?,
        manufacturerData: List<Int>?,
        localName: String?,
        txPowerBoost: Int,
        background: Boolean,
        rotationCount: Int,
    ): String? {
        if (advertisingId != null) return advertisingId
        activeEmitted = false
        val advertiser = runCatching { adapter?.bluetoothLeAdvertiser }.getOrNull()
            ?: run { BleLog.w("no BluetoothLeAdvertiser"); return null }

        if (rotationCount > 1 && manufacturerId == null) {
            BleLog.w("rotation requested without manufacturerId; rotating nothing")
        }

        val id = "advertising-${adsStarted.incrementAndGet()}"
        val settings = buildSettings(mode, txPowerBoost, background)
        startVariant(
            advertiser = advertiser,
            id = id,
            settings = settings,
            serviceUuid = serviceUuid,
            manufacturerId = manufacturerId,
            manufacturerData = manufacturerData.orEmpty(),
            localName = localName,
            rotationCount = rotationCount,
            variantIndex = 0,
        )

        if (rotationCount > 1 && manufacturerId != null) {
            val intervalMs = rotationIntervalMs(mode)
            val runnable = object : Runnable {
                override fun run() {
                    if (advertisingId != id) return
                    stopVariant()
                    startVariant(
                        advertiser = advertiser,
                        id = id,
                        settings = settings,
                        serviceUuid = serviceUuid,
                        manufacturerId = manufacturerId,
                        manufacturerData = manufacturerData.orEmpty(),
                        localName = localName,
                        rotationCount = rotationCount,
                        variantIndex = ((rotationIndex.incrementAndGet()) % rotationCount).toInt(),
                    )
                    handler.postDelayed(this, intervalMs)
                }
            }
            rotationRunnable = runnable
            handler.postDelayed(runnable, intervalMs)
        }

        advertisingId = id
        return id
    }

    fun stopAdvertising(advertisingId: String) {
        if (advertisingId != this.advertisingId) return
        rotationRunnable?.let { handler.removeCallbacks(it) }
        rotationRunnable = null
        stopVariant()
        activeEmitted = false
        val stoppedId = this.advertisingId
        this.advertisingId = null
        if (stoppedId != null) {
            emitter?.send(
                "advertisingChanged",
                mapOf("active" to false, "advertisingId" to stoppedId),
            )
        }
    }

    fun dispose() {
        stopAdvertising(advertisingId ?: return)
    }

    // ---- Internals ---------------------------------------------------------------

    /**
     * Builds the platform settings for this session.
     *
     * Background advertising favors battery: the session always drops to
     * [AdvertiseSettings.ADVERTISE_MODE_LOW_POWER] (largest interval) and
     * never boosts TX power, so a backgrounded transport stays discoverable
     * without burning radio.
     */
    private fun buildSettings(mode: String, txPowerBoost: Int, background: Boolean): AdvertiseSettings {
        val effectiveMode = if (background) "lowPower" else mode
        val effectiveBoost = if (background) 0 else txPowerBoost
        return AdvertiseSettings.Builder()
            .setAdvertiseMode(
                when (effectiveMode) {
                    "lowPower" -> AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
                    "lowLatency" -> AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
                    else -> AdvertiseSettings.ADVERTISE_MODE_BALANCED
                },
            )
            .setTxPowerLevel(
                when {
                    effectiveBoost <= -4 -> AdvertiseSettings.ADVERTISE_TX_POWER_ULTRA_LOW
                    effectiveBoost < 0 -> AdvertiseSettings.ADVERTISE_TX_POWER_LOW
                    effectiveBoost >= 2 -> AdvertiseSettings.ADVERTISE_TX_POWER_HIGH
                    else -> AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
                },
            )
            .setTimeout(0)
            .build()
    }

    /** Payload rotation cadence per power mode (ms between variants). */
    private fun rotationIntervalMs(mode: String): Long = when (mode) {
        "lowLatency" -> 3_000L
        "balanced" -> 5_000L
        else -> 8_000L
    }

    private fun startVariant(
        advertiser: android.bluetooth.le.BluetoothLeAdvertiser,
        id: String,
        settings: AdvertiseSettings,
        serviceUuid: String?,
        manufacturerId: Int?,
        manufacturerData: List<Int>,
        localName: String?,
        rotationCount: Int,
        variantIndex: Int,
    ) {
        // A custom local name cannot be embedded by the platform API, so we
        // expose it once in the manufacturer payload; consumers read the
        // device name from the scan record instead.
        val builder = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
        serviceUuid?.let { raw ->
            UuidUtils.normalize(raw)?.let { normalized ->
                builder.addServiceUuid(ParcelUuid.fromString(normalized))
            }
        }
        manufacturerId?.let { companyId ->
            var payload = manufacturerData.toByteArray()
            val nameChunk = localName?.toByteArray(Charsets.UTF_8) ?: ByteArray(0)
            if (nameChunk.isNotEmpty()) {
                payload = payload + byteArrayOf(0x00) + nameChunk
            }
            if (rotationCount > 1) {
                payload = AdPayloadBuilder.rotationVariant(rotationCount, variantIndex) { seq ->
                    payload + byteArrayOf(seq)
                }
            }
            builder.addManufacturerData(companyId, payload)
        }

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                BleLog.d("advertising variant $variantIndex up: $id")
                if (variantIndex == 0 && !activeEmitted) {
                    activeEmitted = true
                    emitter?.send(
                        "advertisingChanged",
                        mapOf("active" to true, "advertisingId" to id),
                    )
                }
            }

            override fun onStartFailure(errorCode: Int) {
                BleLog.w("advertising failed: $errorCode")
                if (advertisingId == id) {
                    advertisingId = null
                    currentCallback = null
                    activeEmitted = false
                    emitter?.send(
                        "advertisingChanged",
                        mapOf("active" to false, "advertisingId" to id),
                    )
                }
            }
        }
        currentCallback = callback
        try {
            advertiser.startAdvertising(settings, builder.build(), callback)
        } catch (e: SecurityException) {
            BleLog.e("advertising blocked by permissions", throwable = e)
            callback.onStartFailure(AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR)
        } catch (e: Exception) {
            BleLog.e("advertiser unavailable", throwable = e)
            callback.onStartFailure(AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR)
        }
    }

    /** Stops the current platform session without ending the logical one. */
    private fun stopVariant() {
        val callback = currentCallback
        currentCallback = null
        runCatching { adapter?.bluetoothLeAdvertiser?.stopAdvertising(callback) }
    }

    companion object {
        private val adsStarted = AtomicLong()
        private val rotationIndex = AtomicLong()
    }
}

private fun List<Int>.toByteArray(): ByteArray {
    val out = ByteArray(size)
    for (i in indices) out[i] = this[i].toByte()
    return out
}
