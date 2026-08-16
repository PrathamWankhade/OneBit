import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/identity/domain/identity_repository.dart';
import 'package:onebit/features/identity/domain/identity_seeds.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Unmounts the app tree and flushes drift's deferred stream-closing
/// timers, so widget tests end without pending timers.
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// A fresh in-memory prefs store.
InMemorySharedPreferencesAsync sharedPrefsStore() =>
    InMemorySharedPreferencesAsync.empty();

/// A minimal [NodeIdentity] with a stable fingerprint (no crypto needed).
NodeIdentity testIdentity({String displayName = 'Test Node'}) {
  final fingerprintHex = List.filled(32, '00').join();
  final fingerprint = Fingerprint.fromHex(fingerprintHex);
  return NodeIdentity(
    uuid: 'test-identity-uuid',
    nodeId: NodeId.fromFingerprintHex(fingerprintHex),
    fingerprint: fingerprint,
    ed25519PublicKey: Uint8List(32),
    x25519PublicKey: Uint8List(32),
    profile: UserProfile(displayName: displayName, avatarColor: 0),
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

/// In-memory [IdentityRepository]: starts with [identity] (null = fresh
/// install) and creates identities on demand.
final class FakeIdentityRepository implements IdentityRepository {
  FakeIdentityRepository({this.identity});

  NodeIdentity? identity;

  @override
  Future<Result<NodeIdentity?>> loadIdentity() async => Ok(identity);

  @override
  Future<Result<NodeIdentity>> createIdentity({
    required String displayName,
    required int avatarColor,
  }) async {
    final created = testIdentity(displayName: displayName);
    identity = created;
    return Ok(created);
  }

  @override
  Future<Result<NodeIdentity>> updateProfile(UserProfile profile) async {
    final current = identity;
    if (current == null) {
      return const Err(UnsupportedOperationFailure());
    }
    final updated = NodeIdentity(
      uuid: current.uuid,
      nodeId: current.nodeId,
      fingerprint: current.fingerprint,
      ed25519PublicKey: current.ed25519PublicKey,
      x25519PublicKey: current.x25519PublicKey,
      profile: profile,
      createdAt: current.createdAt,
    );
    identity = updated;
    return Ok(updated);
  }

  @override
  Future<Result<void>> deleteIdentity() async {
    identity = null;
    return const Ok(null);
  }

  @override
  Future<Result<Uint8List>> sign(List<int> message) async => Ok(Uint8List(64));

  @override
  Future<Result<bool>> verify({
    required List<int> publicKey,
    required List<int> message,
    required List<int> signature,
  }) async => const Ok(true);

  @override
  Future<Result<Uint8List>> sharedSecret(List<int> remotePublicKey) async =>
      Ok(Uint8List(32));

  @override
  Future<Result<IdentitySeeds>> loadSeeds() async =>
      const Err(UnsupportedOperationFailure());

  @override
  Future<Result<String>> exportBackup({required String passphrase}) async =>
      const Err(UnsupportedOperationFailure());

  @override
  Future<Result<NodeIdentity>> importBackup({
    required String passphrase,
    required String document,
  }) async => const Err(UnsupportedOperationFailure());
}

/// Mounts the whole app under a fresh provider scope.
///
/// [prefs] is installed as `SharedPreferencesAsyncPlatform.instance` (pass
/// the same instance across "restarts" to exercise tab restoration) and
/// [identity] seeds the identity repository (null = fresh install).
Widget oneBitApp({
  NodeIdentity? identity,
  InMemorySharedPreferencesAsync? prefs,
  List<Override> overrides = const [],
}) {
  final store = prefs ?? sharedPrefsStore();
  SharedPreferencesAsyncPlatform.instance = store;
  return ProviderScope(
    overrides: [
      ...overrides,
      identityRepositoryProvider.overrideWithValue(
        FakeIdentityRepository(identity: identity),
      ),
      databaseConnectionFactoryProvider.overrideWithValue(
        const InMemoryConnectionFactory(),
      ),
    ],
    child: const OneBitApp(),
  );
}
