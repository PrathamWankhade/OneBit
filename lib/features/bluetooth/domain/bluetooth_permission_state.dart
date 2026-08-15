/// Status of the Bluetooth runtime permissions.
enum BluetoothPermissionState {
  /// Not requested yet; nothing crashed, we just have not asked.
  notDetermined('notDetermined'),

  /// The runtime permissions required by the current target are granted.
  granted('granted'),

  /// Only a subset is granted (e.g. scan but not connect).
  partial('partial'),

  /// The user permanently denied; recovery requires the system settings.
  denied('denied'),

  /// The user denied a cohort; a rationale should be shown and retried.
  deniedForever('deniedForever'),

  /// Bluetooth is off, so permission checks defer to the adapter state.
  adapterOff('adapterOff');

  const BluetoothPermissionState(this.rawName);

  /// Stable wire name used by the method/event channel.
  final String rawName;

  bool get isGranted => this == BluetoothPermissionState.granted;

  /// Parses a wire name, falling back to [notDetermined].
  static BluetoothPermissionState fromWire(String? raw) {
    for (final state in values) {
      if (state.rawName == raw) return state;
    }
    return BluetoothPermissionState.notDetermined;
  }
}
