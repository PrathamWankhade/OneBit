import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/platform/method_channel_native_bridge.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/bluetooth/bluetooth_service.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_methods.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_platform.dart';
import 'package:onebit/features/bluetooth/data/bluetooth_repository_impl.dart';
import 'package:onebit/features/bluetooth/data/method_channel_bluetooth_platform.dart';
import 'package:onebit/features/bluetooth/data/nearby_peer_repository_impl.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state_machine.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_controllers.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/features/nearby/domain/nearby_peer_repository.dart';

/// The real native Bluetooth facade.
///
/// Commands travel a dedicated `MethodChannel` on [BluetoothChannels.methods]
/// (the transport is registered there natively), not the shared root bridge.
/// Override in tests with a fake [BluetoothPlatform].
final Provider<BluetoothPlatform> bluetoothPlatformProvider =
    Provider<BluetoothPlatform>((ref) {
      return MethodChannelBluetoothPlatform(
        bridge: MethodChannelNativeBridge(
          const MethodChannel(BluetoothChannels.methods),
        ),
      );
    });

/// The transport repository.
///
/// Wiring the repository in Riverpod means the event subscription and its
/// stream controllers are disposed with the container — nothing leaks.
final Provider<BluetoothRepository> bluetoothRepositoryProvider =
    Provider<BluetoothRepository>((ref) {
      final repository = BluetoothRepositoryImpl(
        platform: ref.watch(bluetoothPlatformProvider),
        logger: ref.watch(appLoggerProvider),
      );
      repository.startListening();
      ref.onDispose(repository.dispose);
      return repository;
    });

/// The application-scoped transport service.
///
/// Started eagerly at boot (see `bootstrap.dart`); owns the repository's
/// lifecycle subscription so radio state is tracked from the first frame.
final Provider<BluetoothService> bluetoothServiceProvider =
    Provider<BluetoothService>((ref) {
      final service = BluetoothService(
        repository: ref.watch(bluetoothRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      );
      ref.onDispose(service.stop);
      return service;
    });

/// The Feed for higher layers (node registry) — projects Bluetooth scan
/// results into [NearbyPeer]s behind the existing domain contract.
final Provider<NearbyPeerRepository> nearbyPeerRepositoryProvider =
    Provider<NearbyPeerRepository>((ref) {
      final repository = NearbyPeerRepositoryImpl(
        transport: ref.watch(bluetoothRepositoryProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// The authoritative application state machine.
final Provider<BluetoothStateMachine> bluetoothStateMachineProvider =
    Provider<BluetoothStateMachine>((ref) {
      final machine = BluetoothStateMachine();
      ref.onDispose(machine.dispose);
      return machine;
    });

/// Raw transport event stream (for listeners that want unfiltered events).
final Provider<Stream<BluetoothTransportEvent>> bluetoothEventStreamProvider =
    Provider<Stream<BluetoothTransportEvent>>(
      (ref) => ref.watch(bluetoothRepositoryProvider).events,
    );

/// Radio + permission + battery snapshot.
final AsyncNotifierProvider<BluetoothRadioController, BluetoothRadioSnapshot>
bluetoothRadioControllerProvider =
    AsyncNotifierProvider<BluetoothRadioController, BluetoothRadioSnapshot>(
      BluetoothRadioController.new,
    );

/// State machine view: application state, active device, negotiated MTU.
final NotifierProvider<BluetoothMachineController, BluetoothMachineView>
bluetoothMachineControllerProvider =
    NotifierProvider<BluetoothMachineController, BluetoothMachineView>(
      BluetoothMachineController.new,
    );

/// Discovered devices + scan lifecycle.
final NotifierProvider<BluetoothScanController, BluetoothScanView>
bluetoothScanControllerProvider =
    NotifierProvider<BluetoothScanController, BluetoothScanView>(
      BluetoothScanController.new,
    );

/// Per-device connection lifecycle plus latest RSSI readings.
final NotifierProvider<BluetoothLinkController, BluetoothLinksView>
bluetoothLinkControllerProvider =
    NotifierProvider<BluetoothLinkController, BluetoothLinksView>(
      BluetoothLinkController.new,
    );

/// Advertising + GATT server lifecycle (developer panels).
final NotifierProvider<BluetoothAdvertisingController, BluetoothAdvertisingView>
bluetoothAdvertisingControllerProvider =
    NotifierProvider<BluetoothAdvertisingController, BluetoothAdvertisingView>(
      BluetoothAdvertisingController.new,
    );

/// Latest permission state.
final AsyncNotifierProvider<
  BluetoothPermissionController,
  BluetoothPermissionState
>
bluetoothPermissionControllerProvider =
    AsyncNotifierProvider<
      BluetoothPermissionController,
      BluetoothPermissionState
    >(BluetoothPermissionController.new);

/// Nearby peers projection for higher layers (node registry).
final StreamProvider<Result<List<NearbyPeer>>> nearbyPeersProvider =
    StreamProvider<Result<List<NearbyPeer>>>(
      (ref) => ref.watch(nearbyPeerRepositoryProvider).observeNearbyPeers(),
    );
