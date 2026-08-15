package dev.onebit.onebit.bluetooth

/**
 * The transport's outgoing event pipe.
 *
 * Implemented by [BluetoothChannel] and forwarded to the Dart event channel.
 * Managers never talk to the Flutter engine directly; they emit structured
 * maps and the channel owns serialization.
 */
fun interface BleEmitter {
    fun send(event: String, payload: Map<String, Any?>)
}