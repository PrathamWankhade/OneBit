package dev.onebit.onebit.bluetooth.connection

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.os.Handler
import android.os.Looper
import dev.onebit.onebit.bluetooth.BleEmitter
import dev.onebit.onebit.bluetooth.BleException
import dev.onebit.onebit.bluetooth.callbacks.GattEventListener
import dev.onebit.onebit.bluetooth.errors.BleErrorCodes
import dev.onebit.onebit.bluetooth.gatt.GattClientManager
import dev.onebit.onebit.bluetooth.logging.BleLog
import dev.onebit.onebit.bluetooth.mtu.MtuOutcome
import dev.onebit.onebit.bluetooth.mtu.MtuPolicy
import dev.onebit.onebit.bluetooth.rssi.RssiSmoother
import dev.onebit.onebit.bluetooth.state.BtConnectionState
import dev.onebit.onebit.bluetooth.state.BluetoothStateMachine
import java.util.concurrent.CompletableFuture
import kotlin.math.pow

/**
 * Owns the full lifecycle of every BLE link this device holds.
 *
 * Connect sequence: connecting -> connected -> MTU negotiation -> service
 * discovery -> ready. Failures rewind into reconnecting (bounded by the
 * caller's retry budget and exponential backoff), then disconnected. Stage
 * results are exposed to Dart both as `connectionChanged`/`mtuNegotiated`
 * events and through completers that back the method channel.
 */
@SuppressLint("MissingPermission")
class ConnectionManager(private val gattClient: GattClientManager) : GattEventListener {

    var emitter: BleEmitter? = null

    private val handler = Handler(Looper.getMainLooper())
    private val links = mutableMapOf<String, Link>()

    /** Connection options decoded from channel arguments. */
    data class ConnectionOptions(
        val autoReconnect: Boolean,
        val maxRetries: Int,
        val connectTimeoutMs: Long,
        val retryDelayMs: Long,
        val retryBackoff: Double,
        val requestMtu: Int,
    ) {
        companion object {
            fun from(args: Map<*, *>): ConnectionOptions {
                val options = args["options"] as? Map<*, *> ?: emptyMap<Any, Any>()
                return ConnectionOptions(
                    autoReconnect = options["autoReconnect"] as? Boolean ?: true,
                    maxRetries = (options["maxRetries"] as? Number)?.toInt() ?: 3,
                    connectTimeoutMs = (options["connectTimeoutMs"] as? Number)?.toLong() ?: 20_000,
                    retryDelayMs = (options["retryDelayMs"] as? Number)?.toLong() ?: 5_000,
                    retryBackoff = (options["retryBackoff"] as? Number)?.toDouble() ?: 1.5,
                    requestMtu = (options["requestMtu"] as? Number)?.toInt() ?: 512,
                )
            }
        }
    }

    /** Starts the connect sequence for [device]; progress arrives as events. */
    fun connect(device: BluetoothDevice, options: ConnectionOptions): Boolean {
        if (links[device.address]?.gatt != null) {
            BleLog.w("connect(${device.address}) already tracked")
            return true
        }
        val link = Link(device, options)
        links[device.address] = link
        if (activeLinkCount() > MAX_CONCURRENT_LINKS) {
            // The transport caps concurrent physical links; reject the
            // newcomer instead of silently degrading existing ones.
            BleLog.w("connect(${device.address}) exceeds max concurrent links")
            links.remove(device.address)
            emitConnection(link, BtConnectionState.ERROR, errorCode = BleErrorCodes.CONNECT_FAILED)
            return false
        }
        link.machine.transition(BtConnectionState.CONNECTING)
        emitConnection(link, BtConnectionState.CONNECTING)
        if (gattClient.connect(device, autoReconnect = false, listener = this) == null) {
            links.remove(device.address)
            emitConnection(link, BtConnectionState.ERROR, errorCode = BleErrorCodes.CONNECT_FAILED)
            return false
        }
        scheduleConnectTimeout(link)
        return true
    }

    /** Number of links still on a path that can settle (the concurrency cap). */
    private fun activeLinkCount(): Int = links.values.count { it.isSettled }

    fun disconnect(deviceId: String): Boolean {
        val link = links.remove(deviceId) ?: return false
        link.invalidate()
        link.machine.transition(BtConnectionState.DISCONNECTING)
        emitConnection(link, BtConnectionState.DISCONNECTING)
        gattClient.close(deviceId)
        emitConnection(link, BtConnectionState.DISCONNECTED)
        return true
    }

    /** Service tree as wire maps; completes on the next discovery pass. */
    fun discoverServices(deviceId: String): CompletableFuture<List<Map<String, Any>>> {
        val link = links[deviceId]
            ?: return CompletableFuture.failedFuture(
                BleException(BleErrorCodes.CONNECTION_LOST, "no link to $deviceId"),
            )
        val cached = link.cachedServices
        if (cached != null) return CompletableFuture.completedFuture(cached)
        val future = CompletableFuture<List<Map<String, Any>>>()
        link.pendingDiscovery = future
        gattClient.discoverServices(deviceId)
        return future
    }

    fun requestMtuAndWait(deviceId: String, mtu: Int): CompletableFuture<MtuOutcome> {
        // Negotiation failure is recoverable: fall back to the default MTU
        // instead of failing the caller (documented MTU policy).
        val link = links[deviceId] ?: return CompletableFuture.completedFuture(
            MtuPolicy.outcome(mtu, MtuPolicy.DEFAULT_MTU),
        )
        val future = CompletableFuture<MtuOutcome>()
        link.pendingMtu = future
        gattClient.requestMtu(deviceId, mtu)
        return future
    }

    fun readCharacteristicAndWait(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
    ): CompletableFuture<List<Int>> {
        val link = links[deviceId]
            ?: return CompletableFuture.failedFuture(
                BleException(BleErrorCodes.CONNECTION_LOST, "no link to $deviceId"),
            )
        val future = CompletableFuture<List<Int>>()
        link.pendingReads[charUuid.lowercase()] = future
        if (!gattClient.readCharacteristic(deviceId, serviceUuid, charUuid)) {
            future.completeExceptionally(
                BleException(BleErrorCodes.READ_FAILED, "read not dispatched for $charUuid"),
            )
        }
        return future
    }

    fun writeCharacteristicAndWait(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
        value: ByteArray,
        withoutResponse: Boolean,
        reliable: Boolean = false,
    ): CompletableFuture<Boolean> {
        val link = links[deviceId]
            ?: return CompletableFuture.failedFuture(
                BleException(BleErrorCodes.CONNECTION_LOST, "no link to $deviceId"),
            )
        if (reliable) {
            return startReliableWrite(link, serviceUuid, charUuid, value)
        }
        val chunk = (link.negotiatedMtu - MtuPolicy.ATT_HEADER).coerceIn(20, 509)
        if (!gattClient.writeCharacteristic(deviceId, serviceUuid, charUuid, value, withoutResponse, chunk)) {
            return CompletableFuture.failedFuture(
                BleException(BleErrorCodes.WRITE_FAILED, "write not dispatched for $charUuid"),
            )
        }
        if (withoutResponse) {
            // No-ack writes have no reliability callback: report the dispatch
            // as accepted rather than waiting on a write that never acked.
            return CompletableFuture.completedFuture(true)
        }
        val future = CompletableFuture<Boolean>()
        link.pendingWrites[charUuid.lowercase()] = future
        return future
    }

    /** Begins a reliable session and returns once all chunks are committed. */
    private fun startReliableWrite(
        link: Link,
        serviceUuid: String,
        charUuid: String,
        value: ByteArray,
    ): CompletableFuture<Boolean> {
        val chunk = (link.negotiatedMtu - MtuPolicy.ATT_HEADER).coerceIn(20, MAX_PACKET)
        val future = CompletableFuture<Boolean>()
        val session = ReliableWrite(
            serviceUuid = serviceUuid,
            charUuid = charUuid,
            value = value,
            offset = chunk,
            chunkSize = chunk,
            future = future,
        )
        link.reliableWrite = session
        if (!gattClient.writeCharacteristic(link.device.address, serviceUuid, charUuid, value, false, chunk, reliable = true)) {
            link.reliableWrite = null
            gattClient.abortReliable(link.device.address)
            future.completeExceptionally(BleException(BleErrorCodes.WRITE_FAILED, "reliable write not dispatched"))
        }
        return future
    }

    fun setNotify(
        deviceId: String,
        serviceUuid: String,
        charUuid: String,
        enabled: Boolean,
        indications: Boolean,
    ): Boolean {
        val subscribed = gattClient.setNotify(deviceId, serviceUuid, charUuid, enabled, indications)
        if (subscribed) {
            // Remember the subscription flavor so value-update events can
            // report whether they are indications or notifications.
            links[deviceId]?.notifyKinds?.put(charUuid.lowercase(), indications)
        }
        return subscribed
    }

    fun readRssiAndWait(deviceId: String): CompletableFuture<Map<String, Any>> {
        val link = links[deviceId]
            ?: return CompletableFuture.failedFuture(
                BleException(BleErrorCodes.CONNECTION_LOST, "no link to $deviceId"),
            )
        val future = CompletableFuture<Map<String, Any>>()
        link.pendingRssi = future
        gattClient.readRssi(deviceId)
        return future
    }

    // ---- GattEventListener ----------------------------------------------------

    override fun onGattConnectionChanged(deviceId: String, connected: Boolean, status: Int) {
        val link = links[deviceId] ?: return
        if (connected && status == BluetoothGatt.GATT_SUCCESS) {
            BleLog.d("GATT up on $deviceId; negotiating MTU ${link.options.requestMtu}")
            link.machine.transition(BtConnectionState.CONNECTED)
            emitConnection(link, BtConnectionState.CONNECTED)
            gattClient.requestMtu(deviceId, link.options.requestMtu)
        } else {
            BleLog.w("GATT drop on $deviceId (connected=$connected status=$status)")
            if (status != BluetoothGatt.GATT_SUCCESS && !connected) {
                // The attempt itself failed; close so a retry re-opens cleanly.
                gattClient.close(deviceId)
            }
            link.machine.transition(BtConnectionState.DISCONNECTED)
            emitConnection(link, BtConnectionState.DISCONNECTED)
            maybeReconnect(link, "connection status=$status")
        }
    }

    override fun onMtuChanged(deviceId: String, mtu: Int, status: Int) {
        val link = links[deviceId] ?: return
        val outcome = MtuPolicy.outcome(
            link.options.requestMtu,
            if (status == BluetoothGatt.GATT_SUCCESS) mtu else MtuPolicy.DEFAULT_MTU,
        )
        link.negotiatedMtu = outcome.actualMtu
        emitMtu(link, outcome)
        link.pendingMtu?.complete(outcome)
        link.pendingMtu = null
        // Whether or not the exchange succeeded we continue at the settled
        // MTU (Dart falls back to 23 on failure too).
        link.machine.transition(BtConnectionState.SERVICE_DISCOVERY)
        emitConnection(link, BtConnectionState.SERVICE_DISCOVERY)
        gattClient.discoverServices(deviceId)
    }

    override fun onServicesDiscovered(deviceId: String, status: Int) {
        val link = links[deviceId] ?: return
        if (status != BluetoothGatt.GATT_SUCCESS) {
            BleLog.w("services discovery failed for $deviceId ($status)")
            link.pendingDiscovery?.complete(emptyList())
            link.pendingDiscovery = null
            maybeReconnect(link, "services failed")
            return
        }
        val tree = buildServiceTree(link)
        link.cachedServices = tree
        link.pendingDiscovery?.complete(tree)
        link.pendingDiscovery = null
        link.machine.transition(BtConnectionState.READY)
        emitConnection(link, BtConnectionState.READY, mtu = link.negotiatedMtu)
    }

    override fun onCharacteristicRead(
        deviceId: String,
        characteristicUuid: String,
        value: ByteArray,
        status: Int,
    ) {
        links[deviceId]?.pendingReads?.remove(characteristicUuid.lowercase())
            ?.complete(value.map { it.toInt() })
    }

    override fun onCharacteristicWrite(deviceId: String, characteristicUuid: String, status: Int) {
        val link = links[deviceId] ?: return
        val session = link.reliableWrite
        if (session != null && session.charUuid.equals(characteristicUuid, ignoreCase = true)) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                BleLog.w("reliable write failed for $deviceId ($status)")
                link.reliableWrite = null
                gattClient.abortReliable(deviceId)
                session.future.complete(false)
                return
            }
            if (session.offset < session.value.size) {
                // More chunks to go: write the next one inside the session.
                gattClient.writeReliableChunk(
                    deviceId, session.serviceUuid, session.charUuid,
                    session.value, session.offset, session.chunkSize,
                )
                session.offset += session.chunkSize
            } else if (!session.committing) {
                // All chunks written: commit the session; the server ack
                // arrives as a final onCharacteristicWrite.
                session.committing = true
                gattClient.commitReliable(deviceId)
            } else {
                link.reliableWrite = null
                session.future.complete(true)
            }
            return
        }
        link.pendingWrites.remove(characteristicUuid.lowercase())
            ?.complete(status == BluetoothGatt.GATT_SUCCESS)
    }

    override fun onCharacteristicChanged(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String,
        value: ByteArray,
    ) {
        val indications =
            links[deviceId]?.notifyKinds?.get(characteristicUuid.lowercase()) == true
        emitter?.send(
            "characteristicChanged",
            mapOf(
                "deviceId" to deviceId,
                "serviceUuid" to serviceUuid,
                "characteristicUuid" to characteristicUuid,
                "value" to value.toList(),
                "indication" to indications,
            ),
        )
    }

    override fun onRssiRead(deviceId: String, rssi: Int, status: Int) {
        val link = links[deviceId] ?: return
        val sample = link.smoother.sample(rssi)
        val wire = mapOf(
            "deviceId" to deviceId,
            "rssi" to sample.rawDb,
            "smoothed" to sample.smoothedDb,
            "timestamp" to sample.timestampMs,
        )
        emitter?.send("rssi", wire)
        link.pendingRssi?.complete(wire)
        link.pendingRssi = null
    }

    // ---- Internal ---------------------------------------------------------------

    private fun maybeReconnect(link: Link, reason: String) {
        if (!link.options.autoReconnect) return
        if (link.options.maxRetries <= 0) return
        if (link.attempts >= link.options.maxRetries) return
        BleLog.d("reconnecting ${link.device.address}: $reason")
        link.machine.transition(BtConnectionState.RECONNECTING)
        emitConnection(link, BtConnectionState.RECONNECTING)
        val backoffMs = (link.options.retryDelayMs *
            link.options.retryBackoff.pow(link.attempts + 1)).toLong()
        link.attempts += 1
        handler.postDelayed({
            val current = links[link.device.address] ?: return@postDelayed
            if (current !== link || link.isInvalidated) return@postDelayed
            BleLog.d("reconnect attempt ${link.attempts} on ${link.device.address}")
            gattClient.connect(link.device, autoReconnect = false, listener = this@ConnectionManager)
        }, backoffMs)
    }

    private fun scheduleConnectTimeout(link: Link) {
        val runnable = Runnable {
            val current = links[link.device.address] ?: return@Runnable
            if (current === link && !link.isSettled) {
                BleLog.w("connect timeout ${link.device.address}")
                links.remove(link.device.address)
                emitConnection(link, BtConnectionState.DISCONNECTED, errorCode = BleErrorCodes.CONNECT_TIMEOUT)
                gattClient.close(link.device.address)
            }
        }
        link.timeoutRunnable = runnable
        handler.postDelayed(runnable, link.options.connectTimeoutMs)
    }

    private fun emitConnection(
        link: Link,
        state: BtConnectionState,
        mtu: Int? = null,
        errorCode: String? = null,
    ) {
        emitter?.send(
            "connectionChanged",
            buildMap {
                put("deviceId", link.device.address)
                put("state", state.wireName)
                mtu?.let { put("mtu", it) }
                errorCode?.let { put("errorCode", it) }
            },
        )
    }

    private fun emitMtu(link: Link, outcome: MtuOutcome) {
        emitter?.send(
            "mtuNegotiated",
            mapOf(
                "deviceId" to link.device.address,
                "requestedMtu" to outcome.requestedMtu,
                "actualMtu" to outcome.actualMtu,
            ),
        )
    }

    private fun buildServiceTree(link: Link): List<Map<String, Any>> {
        val gatt = link.gatt ?: return emptyList()
        return gatt.services.map { service ->
            mapOf(
                "uuid" to service.uuid.toString(),
                "isPrimary" to (service.type == android.bluetooth.BluetoothGattService.SERVICE_TYPE_PRIMARY),
                "characteristics" to service.characteristics.map { char ->
                    mapOf(
                        "uuid" to char.uuid.toString(),
                        "properties" to char.properties,
                        "descriptors" to char.descriptors.map { it.uuid.toString() },
                        "value" to (char.value?.toList() ?: emptyList<Int>()),
                    )
                },
            )
        }
    }

    fun dispose() {
        gattClient.closeAll()
        handler.removeCallbacksAndMessages(null)
        links.values.forEach { it.invalidate() }
        links.clear()
    }

    /** Per-device bookkeeping for one link. */
    inner class Link internal constructor(
        val device: BluetoothDevice,
        val options: ConnectionOptions,
    ) {
        val machine = BluetoothStateMachine()
        val smoother = RssiSmoother()
        val gatt: BluetoothGatt?
            get() = gattClient.linkFor(device.address)?.gatt

        var negotiatedMtu: Int = MtuPolicy.DEFAULT_MTU
        var attempts: Int = 0
        var cachedServices: List<Map<String, Any>>? = null
        var pendingDiscovery: CompletableFuture<List<Map<String, Any>>>? = null
        var pendingMtu: CompletableFuture<MtuOutcome>? = null
        var pendingRssi: CompletableFuture<Map<String, Any>>? = null
        var pendingReads = mutableMapOf<String, CompletableFuture<List<Int>>>()
        val pendingWrites = mutableMapOf<String, CompletableFuture<Boolean>>()
        val notifyKinds = mutableMapOf<String, Boolean>()
        var reliableWrite: ReliableWrite? = null
        var timeoutRunnable: Runnable? = null

        private var invalidated = false
        val isInvalidated: Boolean get() = invalidated

        /** True while the link is on a path that can still settle. */
        val isSettled: Boolean
            get() = machine.state in setOf(
                BtConnectionState.CONNECTING,
                BtConnectionState.CONNECTED,
                BtConnectionState.MTU_NEGOTIATION,
                BtConnectionState.SERVICE_DISCOVERY,
                BtConnectionState.READY,
                BtConnectionState.RECONNECTING,
            )

        fun invalidate() {
            invalidated = true
            timeoutRunnable?.let { handler.removeCallbacks(it) }
            timeoutRunnable = null
            reliableWrite?.future?.completeExceptionally(BleException(BleErrorCodes.CONNECTION_LOST, "disconnected"))
            reliableWrite = null
            pendingMtu?.completeExceptionally(BleException(BleErrorCodes.CONNECTION_LOST, "disconnected"))
            pendingRssi?.completeExceptionally(BleException(BleErrorCodes.CONNECTION_LOST, "disconnected"))
            pendingDiscovery?.complete(emptyList())
            pendingReads.values.forEach {
                it.completeExceptionally(BleException(BleErrorCodes.CONNECTION_LOST, "disconnected"))
            }
            pendingWrites.values.forEach {
                it.completeExceptionally(BleException(BleErrorCodes.CONNECTION_LOST, "disconnected"))
            }
            pendingReads.clear()
            pendingWrites.clear()
            notifyKinds.clear()
        }
    }

    companion object {
        /** Hard cap on simultaneously-settling physical links. */
        const val MAX_CONCURRENT_LINKS = 4

        /** Largest single reliable-write chunk at the negotiated MTU. */
        private const val MAX_PACKET = 509
    }

    /** A reliable write in flight: chunks followed by a commit. */
    data class ReliableWrite(
        val serviceUuid: String,
        val charUuid: String,
        val value: ByteArray,
        var offset: Int,
        val chunkSize: Int,
        val future: CompletableFuture<Boolean>,
        var committing: Boolean = false,
    )
}