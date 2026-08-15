/// Application-scoped transport state (the flattened machine state).
///
/// Scanning and advertising are modelled as mutually exclusive focus
/// cycles at the Flutter layer — the native side still runs both truly
/// concurrently. The app chooses the visible focus; the machine has one.
enum BluetoothState {
  /// Adapter off or uninitialized.
  bluetoothOff('off'),

  /// Adapter on; permissions/managers being prepared.
  initializing('initializing'),

  /// Adapter missing or unusable on this device.
  bluetoothUnavailable('unavailable'),

  /// Radio idle; a scan, advertise, or connect cycle may start.
  ready('ready'),

  /// Scan in progress; peers stream in.
  scanning('scanning'),

  /// A connectable peer was seen; awaiting the caller's choice.
  deviceFound('deviceFound'),

  /// Advertising flow active.
  advertising('advertising'),

  /// Connecting to a peer.
  connecting('connecting'),

  /// GATT link up; MTU negotiation next.
  connected('connected'),

  /// MTU exchange in flight.
  mtuNegotiation('mtuNegotiation'),

  /// MTU settled; discovering GATT services.
  serviceDiscovery('serviceDiscovery'),

  /// Link usable: MTU + services ready. Bytes may flow.
  linkReady('linkReady'),

  /// Explicit disconnect in flight.
  disconnecting('disconnecting'),

  /// Link closed cleanly.
  disconnected('disconnected'),

  /// Automatic reconnect scheduled.
  reconnecting('reconnecting'),

  /// Fatal adapter failure that the transport cannot recover from alone.
  error('error');

  const BluetoothState(this.rawName);

  /// Stable wire name.
  final String rawName;

  static BluetoothState fromWire(String? raw) {
    for (final state in values) {
      if (state.rawName == raw) return state;
    }
    return BluetoothState.bluetoothOff;
  }

  /// Whether the adapter is fully usable in this state.
  bool get isRadioOperational =>
      this == BluetoothState.ready ||
      this == BluetoothState.scanning ||
      this == BluetoothState.deviceFound ||
      this == BluetoothState.advertising;

  /// Whether a link is established (any stage after connecting).
  bool get isInLinkPath =>
      this == BluetoothState.connected ||
      this == BluetoothState.mtuNegotiation ||
      this == BluetoothState.serviceDiscovery ||
      this == BluetoothState.linkReady;
}
