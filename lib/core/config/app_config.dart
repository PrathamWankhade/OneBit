import 'package:meta/meta.dart';
import 'package:onebit/core/config/app_environment.dart';
import 'package:onebit/core/config/app_flavor.dart';
import 'package:onebit/core/constants/app_constants.dart';

/// Immutable, build-time application configuration.
///
/// Produced once during bootstrap from compile-time defines and never mutated
/// for the rest of the process lifetime. Reading [flavor], [environment],
/// [version] etc. from this object (or the `appConfigProvider`) keeps the
/// rule "no magic constants scattered in widgets" enforceable.
@immutable
final class AppConfig {
  /// Creates a configuration with explicit values (used by tests).
  const AppConfig({
    required this.flavor,
    required this.environment,
    this.appName = AppConstants.appName,
    this.version = AppConstants.defaultVersion,
    this.buildNumber = AppConstants.defaultBuildNumber,
    this.enableLogging = true,
    this.verboseLogging = false,
  });

  /// Standard configuration resolved from compile-time defines.
  ///
  /// - `FLAVOR`: build flavor (`debug` / `beta` / `release`).
  /// - `ENVIRONMENT`: optional environment override (defaults to the
  ///   flavor's default environment).
  /// - `APP_VERSION` / `APP_BUILD_NUMBER`: optional version overrides.
  ///
  /// Gradle passes `FLAVOR` automatically; other controls come from the
  /// build pipeline (`--dart-define`).
  factory AppConfig.resolve() {
    const flavorName = String.fromEnvironment('FLAVOR');
    const environmentName = String.fromEnvironment('ENVIRONMENT');
    const versionOverride = String.fromEnvironment('APP_VERSION');
    const buildNumberOverride = int.fromEnvironment('APP_BUILD_NUMBER');

    final flavor = AppFlavor.fromName(flavorName.isEmpty ? null : flavorName);

    return AppConfig(
      flavor: flavor,
      environment: environmentName.isEmpty
          ? flavor.defaultEnvironment
          : AppEnvironment.fromName(environmentName),
      version: versionOverride.isEmpty
          ? AppConstants.defaultVersion
          : versionOverride,
      buildNumber: buildNumberOverride == 0
          ? AppConstants.defaultBuildNumber
          : buildNumberOverride,
      verboseLogging: flavor.isDebug,
    );
  }

  /// Product build flavor.
  final AppFlavor flavor;

  /// Runtime environment.
  final AppEnvironment environment;

  /// Public product name.
  final String appName;

  /// Semantic version, e.g. `1.0.0`.
  final String version;

  /// Monotonic build counter, e.g. `1`.
  final int buildNumber;

  /// Master switch for the logging pipeline.
  final bool enableLogging;

  /// Whether verbose (trace/debug) records are emitted.
  final bool verboseLogging;

  /// True when this is a user-facing release build.
  bool get isProductionBuild => environment.isProduction;

  /// Short human string for the developer panel.
  String get displayVersion => '$version (+$buildNumber)';
}
