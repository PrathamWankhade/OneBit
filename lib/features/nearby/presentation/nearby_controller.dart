import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_connection_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/nearby/domain/nearby_peer.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';

/// Presentation mapping of a Bluetooth link stage to a status chip preset.
OneBitStatusPreset connectionPresetFor(BluetoothConnectionState state) =>
    switch (state) {
      BluetoothConnectionState.idle ||
      BluetoothConnectionState.disconnected => OneBitStatusPreset.offline,
      BluetoothConnectionState.connecting ||
      BluetoothConnectionState.mtuNegotiation ||
      BluetoothConnectionState.serviceDiscovery ||
      BluetoothConnectionState.disconnecting ||
      BluetoothConnectionState.reconnecting => OneBitStatusPreset.connecting,
      BluetoothConnectionState.ready ||
      BluetoothConnectionState.connected => OneBitStatusPreset.online,
      BluetoothConnectionState.error => OneBitStatusPreset.failed,
    };

/// Renders the nearby discovery surface.
///
/// Aggregates the transport's radio snapshot, permission state, scan
/// lifecycle and peer feed; actions (scan start/stop, permission request)
/// delegate to the existing Bluetooth controllers.
final AsyncNotifierProvider<NearbyController, NearbyView> nearbyViewProvider =
    AsyncNotifierProvider<NearbyController, NearbyView>(NearbyController.new);

final class NearbyView {
  const NearbyView({
    required this.radio,
    required this.permission,
    required this.scanning,
    required this.peers,
    required this.loaded,
    this.error,
  });

  /// Radio lifecycle as reported by the adapter.
  final BluetoothRadioState radio;

  /// Bluetooth runtime permission status.
  final BluetoothPermissionState permission;

  /// Whether an active scan cycle is running.
  final bool scanning;

  /// Currently observed peers, strongest signal first.
  final List<NearbyPeer> peers;

  /// Whether the peer feed has emitted at least once.
  final bool loaded;

  /// Stream failure, when discovery could not load.
  final Object? error;

  bool get isEmpty => peers.isEmpty;

  /// Whether scanning is possible at all right now.
  bool get canScan =>
      radio == BluetoothRadioState.ready &&
      permission == BluetoothPermissionState.granted;
}

final class NearbyController extends AsyncNotifier<NearbyView> {
  @override
  Future<NearbyView> build() async {
    final radioAsync = ref.watch(bluetoothRadioControllerProvider);
    final permissionAsync = ref.watch(bluetoothPermissionControllerProvider);
    final scanView = ref.watch(bluetoothScanControllerProvider);
    final peersAsync = ref.watch(nearbyPeersProvider);

    final radio = radioAsync.value?.radio ?? BluetoothRadioState.unknown;
    final permission =
        permissionAsync.value ?? BluetoothPermissionState.notDetermined;

    final peers = <NearbyPeer>[];
    if (peersAsync.hasError) {
      return NearbyView(
        radio: radio,
        permission: permission,
        scanning: scanView.scanning,
        peers: const [],
        loaded: true,
        error: peersAsync.error,
      );
    }
    final peersResult = peersAsync.value;
    if (peersResult != null && peersResult.isErr) {
      return NearbyView(
        radio: radio,
        permission: permission,
        scanning: scanView.scanning,
        peers: const [],
        loaded: true,
        error: peersResult.failure,
      );
    }
    if (peersResult != null) peers.addAll(peersResult.value!);
    peers.sort((a, b) => b.rssiDb.compareTo(a.rssiDb));

    return NearbyView(
      radio: radio,
      permission: permission,
      scanning: scanView.scanning,
      peers: peers,
      loaded: radioAsync.hasValue && peersAsync.hasValue,
    );
  }

  /// Re-runs the discovery streams (error recovery).
  void retry() => ref.invalidate(nearbyPeersProvider);

  /// Starts an active scan cycle through the scan controller.
  Future<void> startScan() =>
      ref.read(bluetoothScanControllerProvider.notifier).startScan();

  /// Stops the running scan cycle.
  Future<void> stopScan() =>
      ref.read(bluetoothScanControllerProvider.notifier).stopScan();

  /// Toggles the scan lifecycle.
  Future<void> toggleScan() {
    final scanning = ref.read(bluetoothScanControllerProvider).scanning;
    return scanning ? stopScan() : startScan();
  }

  /// Requests the Bluetooth runtime permissions.
  Future<void> requestPermission() =>
      ref.read(bluetoothPermissionControllerProvider.notifier).request();

  /// Recovery path after a denial.
  Future<void> recoverPermission() =>
      ref.read(bluetoothPermissionControllerProvider.notifier).recover();
}
