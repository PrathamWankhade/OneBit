import 'package:flutter/foundation.dart';

/// A remote Bluetooth device observed or connected by the transport.
@immutable
final class BluetoothDevice {
  const BluetoothDevice({
    required this.id,
    this.name,
    this.addressType = BluetoothAddressType.anonymous,
  });

  /// Stable device identifier.
  ///
  /// This is the MAC address on `Normal` devices; Android randomizes the
  /// address for service advertisements, so peers that only advertise are
  /// identified by their advertisement identity instead.
  final String id;

  /// User-visible name, when the peer advertises one.
  final String? name;

  /// Whether the address is public or random.
  final BluetoothAddressType addressType;

  @override
  bool operator ==(Object other) => other is BluetoothDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BluetoothDevice(${name ?? id})';
}

/// Address kind of a discovered peer.
enum BluetoothAddressType {
  public('public'),
  random('random'),
  remote('remote'),
  anonymous('anonymous');

  const BluetoothAddressType(this.rawName);

  final String rawName;

  static BluetoothAddressType fromWire(String? raw) {
    for (final type in values) {
      if (type.rawName == raw) return type;
    }
    return BluetoothAddressType.anonymous;
  }
}
