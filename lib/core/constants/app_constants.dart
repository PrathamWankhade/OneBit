/// Core application constants that are build-independent.
///
/// These values never change between flavors. Anything that differs per
/// build belongs in `package:onebit/core/config/app_config.dart`.
abstract final class AppConstants {
  /// Product name shown across the UI.
  static const String appName = 'OneBit';

  /// Stable application identifier for platform services (channels, stores).
  static const String applicationId = 'dev.onebit.onebit';

  /// Dart-only name of the package (pubspec `name:`).
  static const String packageName = 'onebit';

  /// Default application version injected by the build system.
  static const String defaultVersion = '1.0.0';

  /// Default build number injected by the build system.
  static const int defaultBuildNumber = 1;

  /// Locale resolved when no explicit device preference exists.
  static const String defaultLocale = 'en';

  const AppConstants._();
}
