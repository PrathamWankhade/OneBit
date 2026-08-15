import 'package:onebit/core/result/result.dart';
import 'mesh_engine_state.dart';
import 'mesh_packet.dart';

/// Advertised payload of a neighbor, when the radio exposes it.
final class MeshAdvertisement {
  const MeshAdvertisement({
    this.localName,
    this.serviceUuids = const [],
    this.txPowerLevel,
    this.capabilities,
  });

  final String? localName;
  final List<String> serviceUuids;
  final int? txPowerLevel;

  /// Capabilities the advertiser declares in its payload, when exposed.
  ///
  /// `null` means the radio did not surface them; the neighbor table then
  /// falls back to its default set.
  final Set<MeshCapability>? capabilities;
}

/// Events the [MeshTransport] produces for the engine.
sealed class MeshTransportEvent {
  const MeshTransportEvent();
}

/// A neighbor advertisement (scan result) was observed.
final class NeighborAdvertisementSeen extends MeshTransportEvent {
  const NeighborAdvertisementSeen({
    required this.nodeId,
    required this.rssiDb,
    required this.timestamp,
    this.advertisement,
  });

  final String nodeId;
  final int rssiDb;
  final DateTime timestamp;
  final MeshAdvertisement? advertisement;
}

/// A connection to the node entered [state].
final class LinkStateChanged extends MeshTransportEvent {
  const LinkStateChanged({required this.nodeId, required this.state});

  final String nodeId;
  final MeshLinkState state;
}

/// A connected link reported RSSI (characteristic read/notification cadence).
final class RssiObserved extends MeshTransportEvent {
  const RssiObserved({
    required this.nodeId,
    required this.rssiDb,
    required this.timestamp,
  });

  final String nodeId;
  final int rssiDb;
  final DateTime timestamp;
}

/// A packet arrived over the radio (the codec phase parses payloads; the
/// engine receives the header + opaque payload through this event).
final class PacketReceived extends MeshTransportEvent {
  const PacketReceived({required this.packet, required this.rssiDb});

  final MeshPacket packet;
  final int rssiDb;
}

/// The radio reached [state].
final class RadioChanged extends MeshTransportEvent {
  const RadioChanged(this.state);

  final MeshRadioState state;
}

/// Scan duty cycle changed.
final class ScanStateChanged extends MeshTransportEvent {
  const ScanStateChanged(this.scanning);

  final bool scanning;
}

/// Battery-saver mode changed (informational; the engine keeps working).
final class BatterySaverChanged extends MeshTransportEvent {
  const BatterySaverChanged(this.enabled);

  final bool enabled;
}

/// The mesh-side transport contract.
///
/// The Bluetooth phase provides failure-tolerated primitives; this interface
/// exposes exactly what the engine needs: an event feed plus start/stop and
/// unicast send. Every method returns a [Result] and never throws.
abstract interface class MeshTransport {
  /// Transport events (advertisements, links, RSSI, packets, radio).
  Stream<MeshTransportEvent> get events;

  /// Starts the discovery duty cycle.
  Future<Result<String>> startScan();

  /// Stops the discovery duty cycle [scanId].
  Future<Result<void>> stopScan(String scanId);

  /// Starts advertising the node's presence.
  Future<Result<String>> startAdvertising();

  /// Stops advertising [advertisingId].
  Future<Result<void>> stopAdvertising(String advertisingId);

  /// Opens a link to [nodeId].
  Future<Result<void>> connect(String nodeId);

  /// Closes [nodeId].
  Future<Result<void>> disconnect(String nodeId);

  /// Transmits [packet] to [nodeId]. The transport decides framing.
  Future<Result<void>> send(String nodeId, MeshPacket packet);

  /// Negotiates an MTU with [nodeId].
  Future<Result<void>> requestMtu(String nodeId, int mtu);
}
