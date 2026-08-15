import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/mesh/domain/mesh_engine_state.dart';
import 'package:onebit/features/mesh/presentation/mesh_providers.dart';

/// Mirrors the authoritative engine state and exposes start/stop.
final class MeshLifecycleController extends Notifier<MeshEngineState> {
  @override
  MeshEngineState build() {
    ref.listen(meshStateProvider, (previous, next) {
      final value = next.value;
      if (value != null && value.isOk) {
        if (value.value != null) state = value.value!;
      }
    });
    return MeshEngineState.stopped;
  }

  Future<void> start() async {
    await ref.read(meshRepositoryProvider).start();
  }

  Future<void> stop() async {
    await ref.read(meshRepositoryProvider).stop();
  }
}
