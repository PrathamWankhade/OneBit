import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/identity/identity_service.dart';
import 'package:onebit/features/identity/private_key_store.dart';
import 'package:onebit/features/trust/identity_change_service.dart';

/// Provides the private key store (platform-backed secure storage).
final privateKeyStoreProvider = Provider<PrivateKeyStore>((ref) {
  return PrivateKeyStore();
});

/// Provides the identity repository.
final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return IdentityRepository(db);
});

/// Provides the identity service.
final identityServiceProvider = Provider<IdentityService>((ref) {
  final repo = ref.watch(identityRepositoryProvider);
  final keyStore = ref.watch(privateKeyStoreProvider);
  return IdentityService(repo, keyStore);
});

/// Provides the identity change detection service.
///
/// Tracks BLE address → identity mappings and detects when a known
/// BLE device presents a different cryptographic identity.
final identityChangeServiceProvider = Provider<IdentityChangeService>((ref) {
  final repo = ref.watch(identityRepositoryProvider);
  final service = IdentityChangeService(repo);

  // Load persisted mappings on creation.
  service.loadPersistedMappings();

  ref.onDispose(() => service.dispose());
  return service;
});

/// Async provider that loads the local identity.
///
/// On first access, initializes from stored metadata and private key.
/// Returns null if no identity exists yet.
/// Throws if public identity exists but private key is missing/corrupted.
final localIdentityProvider = FutureProvider<IdentityInfo?>((ref) async {
  final service = ref.watch(identityServiceProvider);
  final exists = await service.initialize();
  if (!exists) return null;
  return service.localIdentity;
});

/// Stream provider for peer identities.
final peerIdentitiesProvider = StreamProvider<List<PeerInfo>>((ref) {
  final repo = ref.watch(identityRepositoryProvider);
  return repo.watchPeerIdentities();
});

/// Provider for the BLE identity association resolver.
///
/// Watches the BLE discovery stream and peer identity stream, resolving
/// discovered BLE devices against known peers in memory.
final bleIdentityResolverProvider = Provider<IdentityAssociationResolver>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final localIdentityAsync = ref.watch(localIdentityProvider);
  final identityChangeService = ref.watch(identityChangeServiceProvider);

  String? localKeyHex;
  final identity = localIdentityAsync.valueOrNull;
  if (identity != null) {
    localKeyHex = identity.identityId;
  }

  // Create a stream controller to forward peer updates
  final peerController = StreamController<List<PeerInfo>>.broadcast();

  // Listen to peer identity changes and forward to the controller
  ref.listen<AsyncValue<List<PeerInfo>>>(
    peerIdentitiesProvider,
    (previous, next) {
      next.whenData((peers) {
        peerController.add(peers);
      });
    },
    fireImmediately: true,
  );

  final resolver = IdentityAssociationResolver(
    discoveryStream: bleService.discoveryStream,
    peerStream: peerController.stream,
    localPublicKeyHex: localKeyHex,
    identityChangeService: identityChangeService,
  );

  ref.onDispose(() {
    resolver.dispose();
    peerController.close();
  });
  return resolver;
});
