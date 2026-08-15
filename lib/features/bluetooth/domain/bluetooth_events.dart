import 'package:flutter/foundation.dart';

import 'bluetooth_device.dart';

/// An event fed into [BluetoothStateMachine.handle].
///
/// Each event carries the minimal transport payload needed by the guards
/// (device id, mtu, cause).
@immutable
sealed class BluetoothEvent {
  const BluetoothEvent();
}

/// The adapter reported ON.
final class AdapterOnEvent extends BluetoothEvent {
  const AdapterOnEvent();
}

/// The adapter reported OFF.
final class AdapterOffEvent extends BluetoothEvent {
  const AdapterOffEvent();
}

/// Initialization finished; radio is usable.
final class InitializedEvent extends BluetoothEvent {
  const InitializedEvent();
}

/// Initialization failed (no adapter / vendor block).
final class InitializeFailedEvent extends BluetoothEvent {
  const InitializeFailedEvent({this.cause});
  final Object? cause;
}

/// A scan cycle started.
final class ScanStartedEvent extends BluetoothEvent {
  const ScanStartedEvent();
}

/// A scan cycle stopped.
final class ScanStoppedEvent extends BluetoothEvent {
  const ScanStoppedEvent();
}

/// A connectable peer was observed during a scan.
final class DeviceFoundEvent extends BluetoothEvent {
  const DeviceFoundEvent(this.device);
  final BluetoothDevice device;
}

/// Advertising started.
final class AdvertisingStartedEvent extends BluetoothEvent {
  const AdvertisingStartedEvent();
}

/// Advertising stopped.
final class AdvertisingStoppedEvent extends BluetoothEvent {
  const AdvertisingStoppedEvent();
}

/// A connect attempt was requested by the caller.
final class ConnectRequestedEvent extends BluetoothEvent {
  const ConnectRequestedEvent(this.deviceId, {this.options});
  final String deviceId;
  final Object? options;
}

/// GATT connection established.
final class ConnectedEvent extends BluetoothEvent {
  const ConnectedEvent(this.deviceId);
  final String deviceId;
}

/// MTU exchange started.
final class MtuStartedEvent extends BluetoothEvent {
  const MtuStartedEvent(this.deviceId);
  final String deviceId;
}

/// MTU negotiated successfully.
final class MtuNegotiatedEvent extends BluetoothEvent {
  const MtuNegotiatedEvent(this.deviceId, this.mtu);
  final String deviceId;
  final int mtu;
}

/// MTU negotiation failed; the link continues at the default MTU unless
/// the peer is unusable.
final class MtuFailedEvent extends BluetoothEvent {
  const MtuFailedEvent(this.deviceId, {this.cause});
  final String deviceId;
  final Object? cause;
}

/// GATT services discovered on the link.
final class ServicesDiscoveredEvent extends BluetoothEvent {
  const ServicesDiscoveredEvent(this.deviceId, {this.serviceCount = 1});
  final String deviceId;
  final int serviceCount;
}

/// Explicit disconnect requested by the caller.
final class DisconnectRequestedEvent extends BluetoothEvent {
  const DisconnectRequestedEvent(this.deviceId);
  final String deviceId;
}

/// The link closed cleanly.
final class DisconnectedEvent extends BluetoothEvent {
  const DisconnectedEvent(this.deviceId);
  final String deviceId;
}

/// An automatic reconnect was scheduled.
final class ReconnectRequestedEvent extends BluetoothEvent {
  const ReconnectRequestedEvent(this.deviceId);
  final String deviceId;
}

/// The link dropped unexpectedly.
final class LinkLostEvent extends BluetoothEvent {
  const LinkLostEvent(this.deviceId, {this.cause});
  final String deviceId;
  final Object? cause;
}

/// A fatal adapter failure (vendor crash, permanent disable).
final class FatalAdapterErrorEvent extends BluetoothEvent {
  const FatalAdapterErrorEvent({this.cause});
  final Object? cause;
}

/// An unknown event string arrived over the channel.
final class UnknownEvent extends BluetoothEvent {
  const UnknownEvent(this.raw);
  final String raw;
}
