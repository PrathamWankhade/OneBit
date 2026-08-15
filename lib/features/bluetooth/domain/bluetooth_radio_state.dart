/// The coarse radio lifecycle as observed from the adapter.
///
/// This is the application-scoped radio state; per-device connection state
/// lives in [BluetoothConnectionState].
enum BluetoothRadioState {
  /// The radio state has not been queried yet.
  unknown('unknown'),

  /// Adapter is off or being reset; no radio work can start.
  off('off'),

  /// Adapter on; permissions and managers are being prepared.
  initializing('initializing'),

  /// Radio initialized and idle. Scanning and advertising may start.
  ready('ready'),

  /// The device has no usable BLE adapter (hardware missing or
  /// permanently disabled by the vendor).
  unavailable('unavailable');

  const BluetoothRadioState(this.rawName);

  /// Stable wire name used by the method/event channel.
  final String rawName;

  /// Parses a wire name, falling back to [unknown].
  static BluetoothRadioState fromWire(String? raw) {
    for (final state in values) {
      if (state.rawName == raw) return state;
    }
    return BluetoothRadioState.unknown;
  }
}
