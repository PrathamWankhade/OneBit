import 'package:onebit/core/config/app_environment.dart';

/// Product build flavors, mirroring the Gradle product flavors.
///
/// The flavor is injected at compile time via `--dart-define=FLAVOR=...`
/// (set by CI/`--flavor`). It must never be derived from runtime state.
enum AppFlavor {
  /// Local development builds. Verbose logging and assertions.
  debug(rawName: 'debug'),

  /// Pre-release builds distributed for field testing.
  beta(rawName: 'beta'),

  /// Production builds destined for end users / stores.
  release(rawName: 'release');

  const AppFlavor({required this.rawName});

  /// Value passed via `--dart-define`.

  final String rawName;

  /// True for the store-facing build.
  bool get isRelease => this == AppFlavor.release;

  /// True for builds meant only for local development.
  bool get isDebug => this == AppFlavor.debug;

  /// The environment this flavor maps to by default.
  AppEnvironment get defaultEnvironment => switch (this) {
    AppFlavor.debug => AppEnvironment.development,
    AppFlavor.beta => AppEnvironment.staging,
    AppFlavor.release => AppEnvironment.production,
  };

  /// Resolves a flavor from a raw flavor string.
  ///
  /// Accepts the canonical names (`debug`, `beta`, `release`) and the
  /// Gradle product-flavor IDs (`dev`, `prod`) since AGP cannot use
  /// `debug`/`release` as flavor names. Unknown names fall back to
  /// [AppFlavor.debug] so a mistyped define never breaks the app.
  static AppFlavor fromName(String? name) {
    return switch (name) {
      'debug' || 'dev' => AppFlavor.debug,
      'beta' => AppFlavor.beta,
      'release' || 'prod' => AppFlavor.release,
      _ => AppFlavor.debug,
    };
  }
}
