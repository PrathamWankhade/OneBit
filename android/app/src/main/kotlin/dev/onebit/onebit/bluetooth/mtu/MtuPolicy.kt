package dev.onebit.onebit.bluetooth.mtu

/**
 * MTU negotiation policy (pure logic, JVM-testable).
 *
 * Android reports the ATT MTU in octets; the *payload* a caller may send
 * is always 3 bytes smaller (ATT header). The policy clamps to the BLE
 * minimum of 23 and records a fallback when the peer settled lower than
 * requested — the Dart side uses [fellBack] to keep its expectations
 * honest instead of failing hard.
 */
object MtuPolicy {

    const val DEFAULT_MTU = 23
    const val ATT_HEADER = 3

    /** Largest single payload the caller may send at [mtu] octets. */
    fun payloadLimit(mtu: Int): Int = (mtu - ATT_HEADER).coerceAtLeast(DEFAULT_MTU - ATT_HEADER)

    /**
     * Evaluates the outcome of a negotiation attempt.
     *
     * @param requested what the client asked for (0 = platform default).
     * @param actual what the remote agreed to (0 = negotiation failed).
     */
    fun outcome(requested: Int, actual: Int): MtuOutcome {
        val requestedMtu = if (requested >= DEFAULT_MTU) requested else DEFAULT_MTU
        val actualMtu = if (actual >= DEFAULT_MTU) actual else DEFAULT_MTU
        return MtuOutcome(
            requestedMtu = requestedMtu,
            actualMtu = actualMtu,
            fellBack = actualMtu < requestedMtu,
        )
    }
}

/** Result of an MTU negotiation attempt, mirroring the Dart model. */
data class MtuOutcome(
    val requestedMtu: Int,
    val actualMtu: Int,
    val fellBack: Boolean,
) {
    fun toWire(): Map<String, Any> = mapOf(
        "requestedMtu" to requestedMtu,
        "actualMtu" to actualMtu,
    )
}