/// The local checks performed during first-run initialization.
///
/// These map 1:1 to the status lines rendered by the initialization screen.
/// Order is significant: identity → storage → messaging → media → mesh.
enum LocalInitCheck {
  /// The node identity is present and loadable.
  identity,

  /// The local database answers a real query.
  storage,

  /// The messaging engine started.
  messaging,

  /// The media engine started.
  media,

  /// The mesh transport layer started.
  mesh,
}

/// Result of a single initialization check.
final class LocalInitOutcome {
  const LocalInitOutcome({required this.check, required this.ok, this.error});

  /// The check this outcome belongs to.
  final LocalInitCheck check;

  /// Whether the check passed.
  final bool ok;

  /// The failure when [ok] is false (null on success).
  final Object? error;
}

/// Runs the real local initialization checks.
///
/// This is the contract behind the initialization screen: each check emits
/// exactly one outcome, in declaration order, backed by an actual
/// initialization event — never fabricated progress. Implementations are
/// pure composition (real engines, real storage); tests substitute fakes.
abstract interface class LocalInitializer {
  /// Runs all checks sequentially, emitting one outcome per check.
  ///
  /// The stream completes when every check has been emitted.
  Stream<LocalInitOutcome> initialize();
}
