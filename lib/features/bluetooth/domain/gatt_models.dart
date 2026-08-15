import 'package:flutter/foundation.dart';

/// A GATT service discovered on a connected peer.
@immutable
final class GattService {
  const GattService({
    required this.uuid,
    required this.isPrimary,
    this.characteristics = const [],
  });

  /// Service UUID (canonical lowercase string).
  final String uuid;

  /// True when the service is primary.
  final bool isPrimary;

  /// Characteristics belonging to this service.
  final List<GattCharacteristic> characteristics;
}

/// A GATT characteristic on a connected peer.
@immutable
final class GattCharacteristic {
  const GattCharacteristic({
    required this.uuid,
    required this.properties,
    this.descriptors = const [],
    this.value = const [],
  });

  /// Characteristic UUID (canonical lowercase string).
  final String uuid;

  /// Bit field of [GattProperty] values.
  final int properties;

  /// Descriptor UUIDs attached to this characteristic.
  final List<String> descriptors;

  /// Last read/notification payload (transport bytes).
  final List<int> value;

  bool supports(GattProperty property) => (properties & property.mask) != 0;
}

/// GATT characteristic property flags (Android `BluetoothGattCharacteristic`).
enum GattProperty {
  read(0x02),
  writeWithoutResponse(0x04),
  write(0x08),
  notify(0x10),
  indicate(0x20);

  const GattProperty(this.mask);

  final int mask;
}
