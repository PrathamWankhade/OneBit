import 'dart:async';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';
import 'package:onebit/features/bluetooth/domain/scan_result.dart';
import 'package:onebit/features/mesh/data/mesh_gatt_constants.dart';
import 'package:onebit/features/mesh/data/mesh_packet_codec.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/domain/mesh_packet.dart';
import 'package:onebit/features/mesh/domain/mesh_transport.dart';

/// Adapters the Bluetooth repository to the [MeshTransport] contract.
///
/// BLE device addresses are projected onto mesh node ids 1:1 (the identity
/// phase later swaps this mapping for derived ids). The adapter decodes
/// characteristic notifications with [MeshPacketCodec]; malformed frames
/// are dropped, never surfaced.
final class BluetoothMeshTransportAdapter implements MeshTransport {
  BluetoothMeshTransportAdapter({
    required this._bluetooth,
    this.localNodeId,
    this.advertisedName = 'OneBit',
    this._logger,
  }) {
    _subscription = _bluetooth.events.listen(
      _onBluetoothEvent,
      onError: (Object error) {
        _logger?.error(
          'Mesh adapter: Bluetooth event stream error',
          tag: LogTags.mesh,
          error: error,
        );
      },
      onDone: () {
        _logger?.warning(
          'Mesh adapter: Bluetooth event stream ended',
          tag: LogTags.mesh,
        );
      },
    );
  }

  final BluetoothRepository _bluetooth;
  final AppLogger? _logger;

  /// When set, advertisements from this address are ignored (self-loop).
  String? localNodeId;
  final String advertisedName;

  final MeshPacketCodec _codec = const MeshPacketCodec();

  final StreamController<MeshTransportEvent> _events =
      StreamController<MeshTransportEvent>.broadcast();
  StreamSubscription<BluetoothTransportEvent>? _subscription;

  /// Last scan result per node id (used to resolve connect targets).
  final Map<String, ScanResult> _scanResults = {};
  final Map<String, int> _lastRssi = {};

  @override
  Stream<MeshTransportEvent> get events => _events.stream;

  @override
  Future<Result<String>> startScan() async {
    final result = await _bluetooth.startScan(
      const ScanConfig(
        mode: ScanMode.passive,
        serviceUuids: [MeshGattConstants.meshServiceUuid],
        adaptive: true,
        duplicateFilter: true,
      ),
    );
    return result.map((scanId) {
      _events.add(const ScanStateChanged(true));
      return scanId;
    });
  }

  @override
  Future<Result<void>> stopScan(String scanId) async {
    final result = await _bluetooth.stopScan(scanId);
    if (result.isOk) {
      _events.add(const ScanStateChanged(false));
    }
    return result;
  }

  @override
  Future<Result<String>> startAdvertising() async {
    final result = await _bluetooth.startAdvertising(
      AdvertisementConfig(
        serviceUuid: MeshGattConstants.meshServiceUuid,
        localName: advertisedName,
        txPower: 0,
        mode: AdvertisingPowerMode.balanced,
      ),
    );
    return result;
  }

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) async {
    return _bluetooth.stopAdvertising(advertisingId);
  }

  @override
  Future<Result<void>> connect(String nodeId) async {
    final scanResult = _scanResults[nodeId];
    if (scanResult == null) {
      return Err(
        PlatformFailure(
          method: 'MeshTransport.connect',
          message: 'No advertisement observed for $nodeId',
        ),
      );
    }
    return _bluetooth.connect(
      scanResult.device,
      const ConnectionOptions(requestMtu: 512),
    );
  }

  @override
  Future<Result<void>> disconnect(String nodeId) {
    return _bluetooth.disconnect(nodeId);
  }

  @override
  Future<Result<void>> send(String nodeId, MeshPacket packet) async {
    final bytes = _codec.encode(packet);
    return _bluetooth.writeCharacteristic(
      deviceId: nodeId,
      serviceUuid: MeshGattConstants.meshServiceUuid,
      characteristicUuid: MeshGattConstants.meshTxCharacteristic,
      value: bytes,
      withoutResponse: true,
    );
  }

  @override
  Future<Result<void>> requestMtu(String nodeId, int mtu) {
    return _bluetooth
        .requestMtu(nodeId, mtu)
        .then((result) => result.map((_) {}));
  }

  void _onBluetoothEvent(BluetoothTransportEvent event) {
    switch (event) {
      case ScanResultEvent(:final result):
        _onScanResult(result);
      case ConnectionChangedEvent(:final deviceId, :final state):
        _events.add(
          LinkStateChanged(nodeId: deviceId, state: _linkStateFrom(state)),
        );
      case RssiEvent(:final reading):
        _lastRssi[reading.deviceId] = reading.rssiDb;
        _events.add(
          RssiObserved(
            nodeId: reading.deviceId,
            rssiDb: reading.rssiDb,
            timestamp: reading.timestamp,
          ),
        );
      case CharacteristicChangedEvent(
        :final deviceId,
        :final characteristicUuid,
        :final value,
      ):
        if (characteristicUuid == MeshGattConstants.meshRxCharacteristic) {
          _onPacketBytes(deviceId, value);
        }
      case RadioStateChangedEvent(:final radio):
        _events.add(RadioChanged(_meshRadioFrom(radio)));
      case ScanStateChangedEvent(:final scanning):
        _events.add(ScanStateChanged(scanning));
      case AdvertisingStateChangedEvent():
      case MtuResultEvent():
      case PermissionChangedEvent():
      case TransportErrorEvent():
    }
  }

  void _onScanResult(ScanResult result) {
    final nodeId = result.device.id;
    if (nodeId == localNodeId) return;
    _scanResults[nodeId] = result;
    _events.add(
      NeighborAdvertisementSeen(
        nodeId: nodeId,
        rssiDb: result.rssiDb,
        timestamp: result.timestamp,
        advertisement: MeshAdvertisement(
          localName: result.advertisement.localName,
          serviceUuids: result.advertisement.serviceUuids,
          txPowerLevel: result.advertisement.txPowerLevel,
          capabilities: _capabilitiesOf(result.advertisement.serviceUuids),
        ),
      ),
    );
  }

  /// Maps the observed service UUIDs onto mesh capabilities.
  ///
  /// A node running the mesh service is by definition a relay and a router;
  /// the store-and-forward service additionally marks the node as willing
  /// to hold undelivered traffic (future phase).
  Set<MeshCapability> _capabilitiesOf(List<String> serviceUuids) {
    final capabilities = <MeshCapability>{
      MeshCapability.relay,
      MeshCapability.router,
    };
    if (serviceUuids.contains(MeshGattConstants.storeForwardServiceUuid)) {
      capabilities.add(MeshCapability.storeForward);
    }
    return capabilities;
  }

  void _onPacketBytes(String deviceId, List<int> value) {
    final packet = _codec.decode(value);
    if (packet == null) {
      _logger?.debug(
        'Mesh adapter: dropped malformed frame from $deviceId '
        '(${value.length} B)',
        tag: LogTags.mesh,
      );
      return;
    }
    _events.add(
      PacketReceived(packet: packet, rssiDb: _lastRssi[deviceId] ?? 0),
    );
  }

  MeshLinkState _linkStateFrom(String state) {
    return switch (state) {
      'connecting' => MeshLinkState.connecting,
      'connected' => MeshLinkState.connected,
      'disconnecting' => MeshLinkState.disconnecting,
      'disconnected' => MeshLinkState.disconnected,
      _ => MeshLinkState.disconnected,
    };
  }

  MeshRadioState _meshRadioFrom(BluetoothRadioState radio) {
    return switch (radio) {
      BluetoothRadioState.off => MeshRadioState.off,
      BluetoothRadioState.unknown => MeshRadioState.unknown,
      BluetoothRadioState.initializing ||
      BluetoothRadioState.ready ||
      BluetoothRadioState.unavailable => MeshRadioState.on,
    };
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _events.close();
  }
}
