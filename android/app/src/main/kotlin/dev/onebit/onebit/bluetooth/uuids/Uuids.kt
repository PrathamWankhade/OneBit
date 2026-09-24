package dev.onebit.onebit.bluetooth.uuids

/**
 * Transport-level GATT identifiers.
 *
 * These identify the *transport* plumbing only — the probe/echo service
 * exercises GATT round trips in the developer UI and tests. Mesh-level
 * services (session, routing, transport headers) register in the mesh
 * phase and supersede this service.
 */
object Uuids {

    /** 16-bit short form advertised as our probe service. */
    const val PROBE_SERVICE_SHORT = "0xA1A0"

    /** Full probe service UUID (expanded base UUID form). */
    const val PROBE_SERVICE = "A1A00000-0000-1000-8000-00805F9B34FB"

    /** Echo characteristic: writes come back byte-for-byte via notify. */
    const val ECHO_CHARACTERISTIC = "A1A00001-0000-1000-8000-00805F9B34FB"

    /** Device identity characteristic (read-only). */
    const val ID_CHARACTERISTIC = "A1A00002-0000-1000-8000-00805F9B34FB"

    /** OneBit application service UUID (advertised by all OneBit devices). */
    const val ONEBIT_SERVICE = "D1A00000-0000-1000-8000-00805F9B34FB"

    /** Communication characteristic: bidirectional write+notify for raw payloads. */
    const val COMMUNICATION_CHARACTERISTIC = "D1A00001-0000-1000-8000-00805F9B34FB"
}
