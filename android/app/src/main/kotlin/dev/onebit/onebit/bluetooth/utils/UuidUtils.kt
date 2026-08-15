package dev.onebit.onebit.bluetooth.utils

import java.util.Locale

/**
 * UUID helpers for the transport.
 *
 * Peers and configs hand us 16-bit, 32-bit or full 128-bit UUID strings
 * (with or without dashes); everything is normalized to the canonical
 * BLE base-UUID form before it crosses the adapter API.
 */
object UuidUtils {

    /** The Bluetooth SIG base UUID used to expand short forms. */
    private const val BASE_UUID = "00000000-0000-1000-8000-00805F9B34FB"

    /** Regexes accepted on input, in order of specificity. */
    private val FULL = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private val COMPACT = Regex("^[0-9a-fA-F]{32}$")
    private val THIRTY_TWO = Regex("^[0-9a-fA-F]{8}$")
    private val SIXTEEN = Regex("^[0-9a-fA-F]{4}$")

    /**
     * Normalizes [raw] into the canonical 128-bit form, or `null` when the
     * input is not a recognizable UUID.
     */
    fun normalize(raw: String?): String? {
        if (raw == null) return null
        if (FULL.matches(raw.trim())) return raw.trim().uppercase(Locale.US)
        val trimmed = raw.replace("-", "").trim().uppercase(Locale.US)
        return when {
            COMPACT.matches(trimmed) -> format(trimmed)
            THIRTY_TWO.matches(trimmed) -> expand(trimmed)
            SIXTEEN.matches(trimmed) -> expand("0000$trimmed")
            else -> null
        }
    }

    /** Folds a 32-bit short form onto the BLE base UUID. */
    private fun expand(hex32: String): String =
        "${hex32.uppercase(Locale.US)}-0000-1000-8000-00805F9B34FB"

    private fun format(hex32: String): String {
        val h = hex32.uppercase(Locale.US)
        return "${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-" +
            "${h.substring(16, 20)}-${h.substring(20, 32)}"
    }

    /** Short 16-bit form of a normalized UUID, when it expands the base. */
    fun shortId(uuid: String?): String? {
        val normalized = normalize(uuid) ?: return null
        if (!normalized.endsWith(BASE_UUID.substring(9))) return null
        return normalized.substring(4, 8)
    }
}
