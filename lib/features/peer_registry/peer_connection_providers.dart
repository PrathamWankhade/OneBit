import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/peer_association.dart';
import 'package:onebit/features/peer_registry/peer_connection_manager.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';

/// Provider for the peer connection manager instance.
///
/// Manages the bridge between BLE connection state (device-keyed)
/// and peer identity (identityId-keyed), including lifecycle state.
final peerConnectionManagerProvider = Provider<PeerConnectionManager>(
  (ref) {
    final bleService = ref.watch(bleServiceProvider);
    final resolver = ref.watch(bleIdentityResolverProvider);
    final registry = ref.watch(peerRegistryProvider);

    final manager = PeerConnectionManager(
      bleService: bleService,
      resolver: resolver,
      registry: registry,
    );

    ref.onDispose(manager.dispose);

    return manager;
  },
);

/// Provider exposing the current list of peer connection records.
///
/// Each record maps a peer identity ID to its BLE device,
/// lifecycle state, and connection state. Updates reactively
/// when the peer connection manager provider is invalidated.
final peerConnectionRecordsProvider = Provider<List<PeerConnectionRecord>>(
  (ref) {
    final manager = ref.watch(peerConnectionManagerProvider);
    return manager.connections;
  },
);

/// Get the lifecycle state of a specific peer.
PeerLifecycleState peerLifecycleStateFor(
  WidgetRef ref,
  String peerIdentityId,
) {
  final manager = ref.read(peerConnectionManagerProvider);
  return manager.lifecycleStateFor(peerIdentityId);
}

/// Get the BLE connection state of a specific peer.
BleConnectionState peerConnectionStateFor(
  WidgetRef ref,
  String peerIdentityId,
) {
  final manager = ref.read(peerConnectionManagerProvider);
  final deviceId = manager.deviceForPeer(peerIdentityId);
  if (deviceId == null) return BleConnectionState.disconnected;
  final bleService = ref.read(bleServiceProvider);
  final info = bleService.current.connectionFor(deviceId);
  return info?.state ?? BleConnectionState.disconnected;
}

/// I7.4: Stream of all current peer associations.
final peerAssociationStreamProvider = StreamProvider<List<PeerAssociation>>(
  (ref) {
    final resolver = ref.watch(bleIdentityResolverProvider);
    return resolver.associationStream;
  },
);

/// I7.4: Get the current associations list.
final peerAssociationsProvider = Provider<List<PeerAssociation>>((ref) {
  final resolver = ref.watch(bleIdentityResolverProvider);
  return resolver.associations;
});

/// I7.4: Resolve the BLE device for a specific peer.
String? peerDeviceFor(
  WidgetRef ref,
  String peerIdentityId,
) {
  final resolver = ref.read(bleIdentityResolverProvider);
  return resolver.resolveDevice(peerIdentityId);
}

/// I7.4: Check if associating a device with an identity would conflict.
AssociationConflict? peerAssociationConflictFor(
  WidgetRef ref,
  String bleDeviceId,
  String identityId,
) {
  final resolver = ref.read(bleIdentityResolverProvider);
  return resolver.checkConflict(bleDeviceId, identityId);
}
