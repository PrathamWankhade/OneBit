/// Runtime environments the application can operate in.
///
/// Kept deliberately separate from [AppFlavor]: a beta build could in
/// theory target a production-grade dataset, and vice-versa. OneBit has no
/// runtime network, so "environment" today drives defensive feature flags,
/// logging posture and the developer panel.
enum AppEnvironment {
  /// Local development, most instrumentation enabled.
  development('development'),

  /// Field-trial builds; semi-verbose diagnostics.
  staging('staging'),

  /// End-user builds; minimal diagnostics.
  production('production');

  const AppEnvironment(this.rawName);

  /// Machine-readable name used in `--dart-define=ENVIRONMENT=...`.
  final String rawName;

  /// True when this is the user-facing build.
  bool get isProduction => this == AppEnvironment.production;

  /// Human-friendly label for the UI.
  String get label => rawName;

  /// Resolves an environment from a raw string; unknown names fall back to
  /// [AppEnvironment.development].
  static AppEnvironment fromName(String? name) => values.firstWhere(
    (e) => e.rawName == name,
    orElse: () => AppEnvironment.development,
  );
}
