package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.errors.BleErrorCodes
import dev.onebit.onebit.bluetooth.logging.BleLog
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

/**
 * The Flutter-facing half of the transport: method channel for commands,
 * event channel for callbacks. The [BluetoothManager] stays engine-free —
 * this class is the only Flutter dependency in the transport.
 *
 * Channel names mirror `BluetoothChannels` on the Dart side. Errors are
 * reported as `result.error(code, message, null)` with the stable `ble.*`
 * codes from [BleErrorCodes]; events are maps with an `event` discriminator
 * matching `BluetoothEventTypes`.
 */
class BluetoothChannel(
    private val messenger: BinaryMessenger,
    private val manager: BluetoothManager,
) {

    companion object {
        const val METHODS_CHANNEL = "dev.onebit.onebit/ble"
        const val EVENTS_CHANNEL = "dev.onebit.onebit/ble_events"

        const val GET_STATE = "getState"
        const val REQUEST_PERMISSIONS = "requestPermissions"
        const val RECOVER_PERMISSIONS = "recoverPermissions"
        const val START_SCAN = "startScan"
        const val STOP_SCAN = "stopScan"
        const val START_ADVERTISING = "startAdvertising"
        const val STOP_ADVERTISING = "stopAdvertising"
        const val START_GATT_SERVER = "startGattServer"
        const val STOP_GATT_SERVER = "stopGattServer"
        const val CONNECT = "connect"
        const val DISCONNECT = "disconnect"
        const val READ_RSSI = "readRssi"
        const val REQUEST_MTU = "requestMtu"
        const val DISCOVER_SERVICES = "discoverServices"
        const val READ_CHARACTERISTIC = "readCharacteristic"
        const val WRITE_CHARACTERISTIC = "writeCharacteristic"
        const val SET_NOTIFY = "setNotify"
        const val START_FOREGROUND_SERVICE = "startForegroundService"
        const val STOP_FOREGROUND_SERVICE = "stopForegroundService"
        const val OPEN_BLUETOOTH_SETTINGS = "openBluetoothSettings"
    }

    private val methodChannel = MethodChannel(messenger, METHODS_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENTS_CHANNEL)

    private val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
            BleLog.d("event stream listening")
            manager.attach(deviceIdOf(arguments))
            manager.emitter = BleEmitter { event, payload ->
                runCatching {
                    sink.success(mapOf<String, Any?>("event" to event) + payload)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            BleLog.d("event stream cancelled")
            manager.emitter = null
            manager.detach()
        }
    }

    init {
        methodChannel.setMethodCallHandler { call, result -> handle(call, result) }
        eventChannel.setStreamHandler(streamHandler)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        BleLog.d("method: ${call.method}")
        try {
            when (call.method) {
                GET_STATE -> result.success(manager.getState())
                REQUEST_PERMISSIONS -> replyAsync(result) { manager.requestPermissions() }
                RECOVER_PERMISSIONS -> replyAsync(result) { manager.recoverPermissions() }
                START_SCAN -> result.success(manager.startScan(args(call)))
                STOP_SCAN -> result.success(manager.stopScan(args(call)))
                START_ADVERTISING -> result.success(manager.startAdvertising(args(call)))
                STOP_ADVERTISING -> result.success(manager.stopAdvertising(args(call)))
                START_GATT_SERVER -> result.success(manager.startGattServer(args(call)))
                STOP_GATT_SERVER -> result.success(manager.stopGattServer())
                CONNECT -> result.success(manager.connect(args(call)))
                DISCONNECT -> result.success(manager.disconnect(args(call)))
                READ_RSSI -> replyAsync(result) { manager.readRssi(args(call)) }
                REQUEST_MTU -> replyAsync(result) { manager.requestMtu(args(call)) }
                DISCOVER_SERVICES -> replyAsync(result) { manager.discoverServices(args(call)) }
                READ_CHARACTERISTIC -> replyAsync(result) { manager.readCharacteristic(args(call)) }
                WRITE_CHARACTERISTIC -> replyAsync(result) { manager.writeCharacteristic(args(call)) }
                SET_NOTIFY -> result.success(manager.setNotify(args(call)))
                START_FOREGROUND_SERVICE -> result.success(manager.startForegroundService(args(call)))
                STOP_FOREGROUND_SERVICE -> result.success(manager.stopForegroundService())
                OPEN_BLUETOOTH_SETTINGS -> {
                    manager.openBluetoothSettings()
                    result.success(emptyMap<String, Any>())
                }
                else -> result.notImplemented()
            }
        } catch (e: BleException) {
            result.error(e.code, e.message, null)
        } catch (e: Exception) {
            BleLog.e("unhandled method error", throwable = e)
            result.error(BleErrorCodes.BUSY, e.message, null)
        }
    }

    private fun args(call: MethodCall): Map<*, *> =
        call.arguments as? Map<*, *> ?: emptyMap<String, Any>()

    /** Completes [result] when the manager's future settles (bounded wait). */
    private fun replyAsync(result: MethodChannel.Result, build: () -> CompletableFuture<Map<String, Any>>) {
        AsyncExecutor.execute {
            try {
                val payload = build().awaitOrFail()
                result.success(payload)
            } catch (e: BleException) {
                result.error(e.code, e.message, null)
            } catch (e: Exception) {
                result.error(BleErrorCodes.BUSY, e.message, null)
            }
        }
    }

    private fun deviceIdOf(arguments: Any?): String {
        if (arguments is Map<*, *>) {
            return arguments["deviceId"] as? String ?: "onebit-device"
        }
        return "onebit-device"
    }
}

private object AsyncExecutor {
    private val executor = Executors.newFixedThreadPool(3) { runnable ->
        Thread(runnable, "onebit-ble-async").apply { isDaemon = true }
    }

    fun execute(block: () -> Unit) = executor.execute(block)
}