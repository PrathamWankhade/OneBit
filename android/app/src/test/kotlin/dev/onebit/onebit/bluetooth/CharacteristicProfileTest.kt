package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.characteristics.CharacteristicProfile
import dev.onebit.onebit.bluetooth.uuids.Uuids
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CharacteristicProfileTest {

    @Test
    fun `echo pipe is classified as a notification`() {
        assertEquals(
            CharacteristicProfile.NotifyKind.NOTIFICATION,
            CharacteristicProfile.notifyKind(Uuids.ECHO_CHARACTERISTIC),
        )
    }

    @Test
    fun `identity read characteristic has no subscription path`() {
        assertEquals(
            CharacteristicProfile.NotifyKind.NONE,
            CharacteristicProfile.notifyKind(Uuids.ID_CHARACTERISTIC),
        )
    }

    @Test
    fun `unknown characteristics default to none`() {
        assertEquals(
            CharacteristicProfile.NotifyKind.NONE,
            CharacteristicProfile.notifyKind("00002a00-0000-1000-8000-00805f9b34fb"),
        )
        assertEquals(CharacteristicProfile.NotifyKind.NONE, CharacteristicProfile.notifyKind(null))
    }

    @Test
    fun `uuid matching is case-insensitive`() {
        assertEquals(
            CharacteristicProfile.NotifyKind.NOTIFICATION,
            CharacteristicProfile.notifyKind(Uuids.ECHO_CHARACTERISTIC.uppercase()),
        )
    }

    @Test
    fun `property helpers reject null characteristics`() {
        assertFalse(CharacteristicProfile.supportsRead(null))
        assertFalse(CharacteristicProfile.supportsWrite(null))
        assertFalse(CharacteristicProfile.supportsSubscribe(null))
    }

    @Test
    fun `cccd uuid is the standard 2902 descriptor`() {
        assertEquals(
            "00002902-0000-1000-8000-00805f9b34fb",
            CharacteristicProfile.CCCD_UUID.toString(),
        )
        assertTrue(CharacteristicProfile.CCCD_UUID.version() == 1)
    }
}
