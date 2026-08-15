import 'package:onebit/core/result/result.dart';

import 'draft.dart';

/// Contract for draft persistence.
///
/// One draft per channel. Implementations: drift-backed and in-memory.
abstract interface class DraftRepository {
  /// Upserts the draft of [draft.channelId].
  Future<Result<void>> save(Draft draft);

  Future<Result<Draft?>> load(String channelId);

  /// Lists every draft across channels (cleanup walks, dev tooling).
  Future<Result<List<Draft>>> listAll();

  Future<Result<void>> delete(String channelId);

  /// Streams the current draft; emits null when the draft is absent.
  Stream<Result<Draft?>> watch(String channelId);
}
