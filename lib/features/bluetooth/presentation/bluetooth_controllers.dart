import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/bluetooth/domain/advertisement_config.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_connection_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_events.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state_machine.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/domain/connection_options.dart';
import 'package:onebit/features/bluetooth/domain/scan_config.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';

/// Radio + permission + battery snapshot controller.
final class BluetoothRadioController
    extends AsyncNotifier<BluetoothRadioSnapshot> {
  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  StreamSubscription<BluetoothRadioState>? _subscription;

  @override
  Future<BluetoothRadioSnapshot> build() async {
    final result = await _repository.getRadioSnapshot();
    if (result.isErr) {
      return const BluetoothRadioSnapshot(
        radio: BluetoothRadioState.unknown,
        permission: BluetoothPermissionState.notDetermined,
        batterySaver: false,
        maxConcurrentConnections: 1,
      );
    }
    final snapshot = result.value!;
    _subscription ??= _repository.radioStateStream.listen((radio) {
      if (radio == snapshot.radio) return;
      state = AsyncData(
        BluetoothRadioSnapshot(
          radio: radio,
          permission: snapshot.permission,
          batterySaver: snapshot.batterySaver,
          maxConcurrentConnections: snapshot.maxConcurrentConnections,
        ),
      );
    });
    ref.onDispose(() => _subscription?.cancel());
    return snapshot;
  }

  /// Re-queries the native snapshot (e.g. after toggling the adapter).
  Future<void> refresh() async {
    final result = await _repository.getRadioSnapshot();
    if (result.isOk) state = AsyncData(result.value!);
  }
}

/// Bridges native events into the state machine and exposes its snapshot.
final class BluetoothMachineController extends Notifier<BluetoothMachineView> {
  BluetoothStateMachine get _machine => ref.read(bluetoothStateMachineProvider);

  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  StreamSubscription<BluetoothTransportEvent>? _subscription;

  @override
  BluetoothMachineView build() {
    _subscription ??= _repository.events.listen(
      _onEvent,
      onError: (Object error, StackTrace stackTrace) {
        ref
            .read(appLoggerProvider)
            .error(
              'machine event stream failed: $error',
              tag: LogTags.platform,
              error: error,
              stackTrace: stackTrace,
            );
      },
    );
    ref.onDispose(() => _subscription?.cancel());
    return BluetoothMachineView(state: _machine.state);
  }

  void _onEvent(BluetoothTransportEvent event) {
    final machine = _machine;
    switch (event) {
      case RadioStateChangedEvent(:final radio):
        switch (radio) {
          case BluetoothRadioState.off:
            machine.handle(const AdapterOffEvent());
          case BluetoothRadioState.initializing:
            machine.handle(const AdapterOnEvent());
          case BluetoothRadioState.ready:
            // Native only confirms readiness once; drive the machine through
            // both legs so a fresh host still reaches `ready`.
            machine.handle(const AdapterOnEvent());
            machine.handle(const InitializedEvent());
          case BluetoothRadioState.unknown:
          case BluetoothRadioState.unavailable:
            machine.handle(const InitializeFailedEvent());
        }
      case ConnectionChangedEvent(
        :final deviceId,
        :final state,
        :final mtu,
        :final errorCode,
      ):
        _feedConnection(machine, deviceId, state, mtu, errorCode);
      case MtuResultEvent(:final deviceId, :final actualMtu):
        machine.handle(MtuNegotiatedEvent(deviceId, actualMtu));
      case ScanResultEvent(:final result):
        if (result.connectable && machine.state == BluetoothState.scanning) {
          machine.handle(DeviceFoundEvent(result.device));
        }
      case AdvertisingStateChangedEvent(:final active):
        machine.handle(
          active
              ? const AdvertisingStartedEvent()
              : const AdvertisingStoppedEvent(),
        );
      case ScanStateChangedEvent(:final scanning):
        machine.handle(
          scanning ? const ScanStartedEvent() : const ScanStoppedEvent(),
        );
      case TransportErrorEvent(:final code):
        ref
            .read(appLoggerProvider)
            .warning('transport error event: $code', tag: LogTags.platform);
      case RssiEvent():
      case CharacteristicChangedEvent():
      case PermissionChangedEvent():
        break;
    }
    state = BluetoothMachineView(
      state: machine.state,
      deviceId: machine.deviceId,
      negotiatedMtu: machine.negotiatedMtu,
    );
  }

  void _feedConnection(
    BluetoothStateMachine machine,
    String deviceId,
    String rawState,
    int? mtu,
    String? errorCode,
  ) {
    switch (rawState) {
      case 'connecting':
        machine.handle(ConnectRequestedEvent(deviceId));
      case 'connected':
        machine.handle(ConnectedEvent(deviceId));
      case 'mtuNegotiation':
        machine.handle(MtuStartedEvent(deviceId));
      case 'mtuNegotiated':
        machine.handle(MtuNegotiatedEvent(deviceId, mtu ?? 23));
      case 'serviceDiscovery':
        machine.handle(ServicesDiscoveredEvent(deviceId));
      case 'ready':
        machine.handle(ServicesDiscoveredEvent(deviceId));
      case 'disconnecting':
        machine.handle(DisconnectRequestedEvent(deviceId));
      case 'disconnected':
        machine.handle(DisconnectedEvent(deviceId));
      case 'reconnecting':
        machine.handle(ReconnectRequestedEvent(deviceId));
      case 'error':
        machine.handle(LinkLostEvent(deviceId, cause: errorCode));
      default:
        break;
    }
  }

  /// Connects to [deviceId] (resolving the device from the scan view).
  Future<void> connect(String deviceId) {
    final device = _findDevice(deviceId);
    return _repository.connect(device, const ConnectionOptions());
  }

  /// Disconnects [deviceId].
  Future<void> disconnect(String deviceId) => _repository.disconnect(deviceId);

  BluetoothDevice _findDevice(String deviceId) {
    final scanView = ref.read(bluetoothScanControllerProvider);
    for (final device in scanView.devices) {
      if (device.id == deviceId) return device;
    }
    return BluetoothDevice(id: deviceId);
  }
}

/// Per-link lifecycle and latest RSSI readings.
final class BluetoothLinkController extends Notifier<BluetoothLinksView> {
  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  StreamSubscription<BluetoothTransportEvent>? _subscription;

  @override
  BluetoothLinksView build() {
    _subscription ??= _repository.events.listen((event) {
      var view = state;
      switch (event) {
        case ConnectionChangedEvent(:final deviceId, :final state):
          view = view.copyWith(
            connections: {
              ...view.connections,
              deviceId: BluetoothConnectionState.fromWire(state),
            },
          );
        case RssiEvent(:final reading):
          view = view.copyWith(rssi: {...view.rssi, reading.deviceId: reading});
        default:
          return;
      }
      state = view;
    });
    ref.onDispose(() => _subscription?.cancel());
    return const BluetoothLinksView();
  }
}

/// Scan lifecycle and discovered devices.
final class BluetoothScanController extends Notifier<BluetoothScanView> {
  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  StreamSubscription<BluetoothTransportEvent>? _subscription;

  @override
  BluetoothScanView build() {
    _subscription ??= _repository.events.listen((event) {
      switch (event) {
        case ScanResultEvent(:final result):
          final knownIds = state.devices.map((device) => device.id).toSet();
          if (knownIds.add(result.device.id)) {
            state = state.copyWith(devices: [...state.devices, result.device]);
          }
        case ScanStateChangedEvent(:final scanning):
          state = state.copyWith(scanning: scanning);
        default:
          break;
      }
    });
    ref.onDispose(() => _subscription?.cancel());
    return const BluetoothScanView();
  }

  /// Starts an active scan cycle (foreground dev-tool default).
  Future<void> startScan() async {
    final result = await _repository.startScan(
      const ScanConfig(mode: ScanMode.active),
    );
    if (result.isOk) {
      state = state.copyWith(scanning: true, scanId: result.value);
    }
  }

  /// Stops the running scan cycle.
  Future<void> stopScan() async {
    final scanId = state.scanId;
    if (scanId != null) {
      await _repository.stopScan(scanId);
    }
    state = state.copyWith(scanning: false, scanId: null);
  }
}

/// Permission state plus request and recovery actions.
final class BluetoothPermissionController
    extends AsyncNotifier<BluetoothPermissionState> {
  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  @override
  Future<BluetoothPermissionState> build() async {
    final snapshot = await _repository.getRadioSnapshot();
    return snapshot.isOk
        ? snapshot.value!.permission
        : BluetoothPermissionState.notDetermined;
  }

  /// Requests the runtime permissions through the native host.
  Future<void> request() async {
    final result = await _repository.requestPermissions();
    if (result.isOk) state = AsyncData(result.value!);
  }

  /// Recovery path after a denial: re-requests the missing grants.
  ///
  /// Safe to call repeatedly; the native host never crashes when the user
  /// keeps denying — the radio just stays degraded with clear error codes.
  Future<void> recover() async {
    final result = await _repository.recoverPermissions();
    if (result.isOk) state = AsyncData(result.value!);
  }
}

/// Advertising + GATT server lifecycle for the developer panels.
final class BluetoothAdvertisingController
    extends Notifier<BluetoothAdvertisingView> {
  BluetoothRepository get _repository => ref.read(bluetoothRepositoryProvider);

  StreamSubscription<BluetoothTransportEvent>? _subscription;

  @override
  BluetoothAdvertisingView build() {
    _subscription ??= _repository.events.listen((event) {
      if (event is AdvertisingStateChangedEvent) {
        state = state.copyWith(
          advertising: event.active,
          advertisingId: event.advertisingId,
        );
      }
    });
    ref.onDispose(() => _subscription?.cancel());
    return const BluetoothAdvertisingView();
  }

  /// Starts advertising in the balanced profile (dev-tool default).
  Future<void> startAdvertising() async {
    final result = await _repository.startAdvertising(
      const AdvertisementConfig(
        mode: AdvertisingPowerMode.balanced,
        localName: 'onebit-dev',
        rotationCount: 3,
      ),
    );
    if (result.isOk) {
      state = state.copyWith(advertising: true, advertisingId: result.value);
    }
  }

  /// Stops advertising and the peripheral GATT server.
  Future<void> stopAdvertising() async {
    final advertisingId = state.advertisingId;
    if (advertisingId != null) {
      await _repository.stopAdvertising(advertisingId);
    }
    state = const BluetoothAdvertisingView();
  }

  /// Starts the peripheral GATT server standalone.
  Future<void> startGattServer() async {
    final result = await _repository.startGattServer(deviceId: 'onebit-device');
    if (result.isOk) state = state.copyWith(gattServer: true);
  }

  /// Stops the peripheral GATT server.
  Future<void> stopGattServer() async {
    await _repository.stopGattServer();
    state = state.copyWith(gattServer: false);
  }
}
