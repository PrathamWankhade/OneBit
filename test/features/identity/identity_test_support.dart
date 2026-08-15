import 'dart:typed_data';

import 'package:onebit/core/crypto/keystore/keystore_key_bridge.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/result/result.dart';

/// No-op logger whose pipeline drops every record (filtered out, empty sink).
AppLogger silentLogger() => AppLogger(
  filter: const LevelAndTagFilter(),
  output: LogOutputGroup(const <LogOutput>[]),
);

/// In-memory [KeystoreKeyBridge] for tests.
///
/// Mirrors the Kotlin contract: seeds are stored per alias, `loadSeed` on a
/// missing alias resolves to an `IdentityFailure` with code `key_not_found`,
/// and `deleteIdentity` is idempotent.
class FakeKeystoreKeyBridge implements KeystoreKeyBridge {
  FakeKeystoreKeyBridge({Map<String, Uint8List>? store})
    : store = store ?? <String, Uint8List>{};

  final Map<String, Uint8List> store;

  @override
  String get channelName => 'fake.keystore';

  @override
  Future<Result<void>> storeSeed({
    required String alias,
    required Uint8List seed,
  }) async {
    store[alias] = Uint8List.fromList(seed);
    return const Ok(null);
  }

  @override
  Future<Result<Uint8List>> loadSeed({required String alias}) async {
    final seed = store[alias];
    if (seed == null) {
      return Err(
        IdentityFailure(
          code: 'key_not_found',
          message: 'No wrapped seed under $alias',
        ),
      );
    }
    return Ok(Uint8List.fromList(seed));
  }

  @override
  Future<Result<bool>> hasIdentity({required String alias}) async =>
      Ok(store.containsKey(alias));

  @override
  Future<Result<void>> deleteIdentity({required String alias}) async {
    store.remove(alias);
    return const Ok(null);
  }
}
