/// The connection lifecycle of one peer link.
///
/// The wire names are stable: they travel over the event channel and are
/// consumed by the state machine and the developer UI.
enum BluetoothConnectionState {
  /// No connection activity for this device.
  idle('idle'),

  /// Connect requested; GATT connect in progress.
  connecting('connecting'),

  /// GATT link established; MTU negotiation is next.
  connected('connected'),

  /// MTU exchange in flight.
  mtuNegotiation('mtuNegotiation'),

  /// MTU settled; GATT services being discovered.
  serviceDiscovery('serviceDiscovery'),

  /// MTU negotiated and services discovered; bytes can flow.
  ready('ready'),

  /// Explicit disconnect in flight.
  disconnecting('disconnecting'),

  /// Link closed cleanly; a reconnect may be scheduled.
  disconnected('disconnected'),

  /// Automatic reconnect with backoff in progress.
  reconnecting('reconnecting'),

  /// Unrecoverable transport failure for this link.
  error('error');

  const BluetoothConnectionState(this.rawName);

  /// Stable wire name used by the method/event channel.
  final String rawName;

  /// Parses a wire name, falling back to [idle].
  static BluetoothConnectionState fromWire(String? raw) {
    for (final state in values) {
      if (state.rawName == raw) return state;
    }
    return BluetoothConnectionState.idle;
  }
}
