import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/database/database_providers.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/launch/domain/local_initializer.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';
import 'package:onebit/features/messaging/presentation/messaging_providers.dart';
import 'package:onebit/shared/base/use_case.dart';

/// [LocalInitializer] backed by the real provider graph.
///
/// Every check performs an actual initialization event: the identity is
/// reloaded from the vault, the database answers a real query, and each
/// engine is started for real. Nothing here is simulated.
final class RiverpodLocalInitializer implements LocalInitializer {
  const RiverpodLocalInitializer(this._ref);

  final Ref _ref;

  @override
  Stream<LocalInitOutcome> initialize() async* {
    yield await _identity();
    yield await _storage();
    yield await _messaging();
    yield await _media();
    yield await _mesh();
  }

  Future<LocalInitOutcome> _identity() async {
    try {
      final result = await _ref
          .read(loadIdentityProvider)
          .call(NoParams.instance);
      if (result.isOk && result.value != null) {
        return const LocalInitOutcome(check: LocalInitCheck.identity, ok: true);
      }
      return LocalInitOutcome(
        check: LocalInitCheck.identity,
        ok: false,
        error: result.isErr ? result.failure : StateError('no identity'),
      );
    } on Object catch (error) {
      return LocalInitOutcome(
        check: LocalInitCheck.identity,
        ok: false,
        error: error,
      );
    }
  }

  Future<LocalInitOutcome> _storage() async {
    try {
      final database = _ref.read(databaseProvider);
      final row = await database.customSelect('SELECT 1 AS one').getSingle();
      final ok = row.data['one'] == 1;
      return LocalInitOutcome(
        check: LocalInitCheck.storage,
        ok: ok,
        error: ok ? null : StateError('storage did not answer'),
      );
    } on Object catch (error) {
      return LocalInitOutcome(
        check: LocalInitCheck.storage,
        ok: false,
        error: error,
      );
    }
  }

  Future<LocalInitOutcome> _messaging() async {
    try {
      // Materializing the engine performs its real startup (inbound pump,
      // queued-message reconciliation).
      _ref.read(messagingEngineProvider);
      return const LocalInitOutcome(check: LocalInitCheck.messaging, ok: true);
    } on Object catch (error) {
      return LocalInitOutcome(
        check: LocalInitCheck.messaging,
        ok: false,
        error: error,
      );
    }
  }

  Future<LocalInitOutcome> _media() async {
    try {
      await _ref.read(mediaEngineProvider).start();
      return const LocalInitOutcome(check: LocalInitCheck.media, ok: true);
    } on Object catch (error) {
      return LocalInitOutcome(
        check: LocalInitCheck.media,
        ok: false,
        error: error,
      );
    }
  }

  Future<LocalInitOutcome> _mesh() async {
    try {
      // Materialize the mesh layer (neighbor discovery wiring)…
      _ref.read(meshEngineProvider);
      // …and start the Bluetooth transport for real. The service degrades
      // gracefully, so an unavailable radio reports a failure here only
      // when the transport itself could not initialize.
      final result = await _ref.read(bluetoothServiceProvider).start();
      return LocalInitOutcome(
        check: LocalInitCheck.mesh,
        ok: result.isOk,
        error: result.isErr ? result.failure : null,
      );
    } on Object catch (error) {
      return LocalInitOutcome(
        check: LocalInitCheck.mesh,
        ok: false,
        error: error,
      );
    }
  }
}
