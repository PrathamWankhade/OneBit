package dev.onebit.onebit.bluetooth.state

/**
 * Per-link connection state machine (native mirror).
 *
 * The Dart state machine models the app's *focus*; every physical link the
 * transport keeps open still needs its own lifecycle tracking, and the
 * wire names here must match `BluetoothConnectionState` on the Dart side.
 * Guards reject illegal transitions and leave the machine unchanged, the
 * same contract as the Dart machine.
 */
enum class BtConnectionState(val wireName: String) {
    IDLE("idle"),
    CONNECTING("connecting"),
    CONNECTED("connected"),
    MTU_NEGOTIATION("mtuNegotiation"),
    SERVICE_DISCOVERY("serviceDiscovery"),
    READY("ready"),
    DISCONNECTING("disconnecting"),
    DISCONNECTED("disconnected"),
    RECONNECTING("reconnecting"),
    ERROR("error");

    companion object {
        fun fromWire(raw: String?): BtConnectionState =
            entries.firstOrNull { it.wireName == raw } ?: IDLE
    }
}

/**
 * Guards for one monitored link. Side-effect free and pure Kotlin so JVM
 * tests can drive it without the Android framework.
 */
class BluetoothStateMachine {

    var state: BtConnectionState = BtConnectionState.IDLE
        private set
    var reconnectAttempts: Int = 0
        private set

    /**
     * Feeds [target] into the machine, returning the resulting state (the
     * previous state when the transition was illegal).
     */
    fun transition(
        target: BtConnectionState,
        previous: BtConnectionState = state,
    ): BtConnectionState {
        val allowed = allowedFrom(previous)
        if (target !in allowed) return previous
        state = target
        when (target) {
            BtConnectionState.CONNECTING -> reconnectAttempts = 0
            BtConnectionState.RECONNECTING -> reconnectAttempts += 1
            else -> Unit
        }
        return state
    }

    private fun allowedFrom(from: BtConnectionState): Set<BtConnectionState> =
        when (from) {
            BtConnectionState.IDLE -> setOf(
                BtConnectionState.CONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.CONNECTING -> setOf(
                BtConnectionState.CONNECTED, BtConnectionState.DISCONNECTED,
                BtConnectionState.RECONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.CONNECTED -> setOf(
                BtConnectionState.MTU_NEGOTIATION, BtConnectionState.DISCONNECTING,
                BtConnectionState.RECONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.MTU_NEGOTIATION -> setOf(
                BtConnectionState.SERVICE_DISCOVERY, BtConnectionState.DISCONNECTING,
                BtConnectionState.RECONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.SERVICE_DISCOVERY -> setOf(
                BtConnectionState.READY, BtConnectionState.DISCONNECTING,
                BtConnectionState.RECONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.READY -> setOf(
                BtConnectionState.DISCONNECTING, BtConnectionState.RECONNECTING,
                BtConnectionState.DISCONNECTED, BtConnectionState.ERROR,
            )
            BtConnectionState.DISCONNECTING -> setOf(
                BtConnectionState.DISCONNECTED, BtConnectionState.ERROR,
            )
            BtConnectionState.DISCONNECTED -> setOf(
                BtConnectionState.CONNECTING, BtConnectionState.RECONNECTING,
                BtConnectionState.ERROR,
            )
            BtConnectionState.RECONNECTING -> setOf(
                BtConnectionState.CONNECTING, BtConnectionState.DISCONNECTED,
                BtConnectionState.RECONNECTING, BtConnectionState.ERROR,
            )
            BtConnectionState.ERROR -> setOf(
                BtConnectionState.CONNECTING, BtConnectionState.RECONNECTING,
            )
        }
}