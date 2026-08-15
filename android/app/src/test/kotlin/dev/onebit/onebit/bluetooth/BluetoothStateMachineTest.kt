package dev.onebit.onebit.bluetooth

import dev.onebit.onebit.bluetooth.state.BluetoothStateMachine
import dev.onebit.onebit.bluetooth.state.BtConnectionState
import org.junit.Assert.assertEquals
import org.junit.Test

class BluetoothStateMachineTest {

    @Test
    fun `starts idle`() {
        assertEquals(BtConnectionState.IDLE, BluetoothStateMachine().state)
    }

    @Test
    fun `full link path reaches ready`() {
        val machine = BluetoothStateMachine()
        assertEquals(BtConnectionState.CONNECTING, machine.transition(BtConnectionState.CONNECTING))
        assertEquals(BtConnectionState.CONNECTED, machine.transition(BtConnectionState.CONNECTED))
        assertEquals(BtConnectionState.MTU_NEGOTIATION, machine.transition(BtConnectionState.MTU_NEGOTIATION))
        assertEquals(BtConnectionState.SERVICE_DISCOVERY, machine.transition(BtConnectionState.SERVICE_DISCOVERY))
        assertEquals(BtConnectionState.READY, machine.transition(BtConnectionState.READY))
    }

    @Test
    fun `illegal transition leaves the machine unchanged`() {
        val machine = BluetoothStateMachine()
        assertEquals(BtConnectionState.IDLE, machine.transition(BtConnectionState.READY))
        assertEquals(BtConnectionState.IDLE, machine.state)
    }

    @Test
    fun `reconnect consumes the budget then gives up`() {
        val machine = BluetoothStateMachine()
        machine.transition(BtConnectionState.CONNECTING)
        machine.transition(BtConnectionState.CONNECTED)
        machine.transition(BtConnectionState.MTU_NEGOTIATION)
        machine.transition(BtConnectionState.SERVICE_DISCOVERY)
        machine.transition(BtConnectionState.READY)

        assertEquals(BtConnectionState.RECONNECTING, machine.transition(BtConnectionState.RECONNECTING))
        assertEquals(1, machine.reconnectAttempts)
        assertEquals(BtConnectionState.RECONNECTING, machine.transition(BtConnectionState.RECONNECTING))
        assertEquals(2, machine.reconnectAttempts)
    }

    @Test
    fun `fresh connect resets the budget`() {
        val machine = BluetoothStateMachine()
        machine.transition(BtConnectionState.CONNECTING)
        machine.transition(BtConnectionState.CONNECTED)
        machine.transition(BtConnectionState.RECONNECTING)
        assertEquals(1, machine.reconnectAttempts)
        machine.transition(BtConnectionState.CONNECTING)
        assertEquals(0, machine.reconnectAttempts)
    }

    @Test
    fun `disconnecting closes cleanly`() {
        val machine = BluetoothStateMachine()
        machine.transition(BtConnectionState.CONNECTING)
        machine.transition(BtConnectionState.CONNECTED)
        assertEquals(BtConnectionState.DISCONNECTING, machine.transition(BtConnectionState.DISCONNECTING))
        assertEquals(BtConnectionState.DISCONNECTED, machine.transition(BtConnectionState.DISCONNECTED))
    }

    @Test
    fun `wire names match the dart contract`() {
        assertEquals("idle", BtConnectionState.IDLE.wireName)
        assertEquals("mtuNegotiation", BtConnectionState.MTU_NEGOTIATION.wireName)
        assertEquals("reconnecting", BtConnectionState.RECONNECTING.wireName)
        assertEquals(BtConnectionState.CONNECTING, BtConnectionState.fromWire("connecting"))
        assertEquals(BtConnectionState.IDLE, BtConnectionState.fromWire("bogus"))
    }
}