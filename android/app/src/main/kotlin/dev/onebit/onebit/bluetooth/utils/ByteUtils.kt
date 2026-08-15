package dev.onebit.onebit.bluetooth.utils

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Byte helpers shared by scanners, advertisers and payload builders. */
object ByteUtils {

    /** Little-endian unsigned 16-bit value (company id etc.). */
    fun u16le(value: Int): ByteArray =
        ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN)
            .putShort(value.toShort()).array()

    /** Little-endian unsigned 32-bit value. */
    fun u32le(value: Long): ByteArray =
        ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
            .putInt(value.toInt()).array()

    fun concat(vararg chunks: ByteArray): ByteArray {
        var size = 0
        for (chunk in chunks) size += chunk.size
        val out = ByteArray(size)
        var offset = 0
        for (chunk in chunks) {
            chunk.copyInto(out, offset)
            offset += chunk.size
        }
        return out
    }

    fun hex(bytes: ByteArray): String =
        bytes.joinToString("") { "%02X".format(it) }
}
