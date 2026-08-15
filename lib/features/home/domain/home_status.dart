import 'package:onebit/core/config/app_config.dart';
import 'package:onebit/core/platform/platform_capabilities.dart';

/// Aggregated state shown by the home console.
///
/// Domain-owned value: the use case builds it from [AppConfig] plus
/// [PlatformCapabilities]; the presentation layer renders it and nothing
/// more.
class HomeStatus {
  const HomeStatus({required this.config, required this.capabilities});

  /// Build-time configuration surfaced to the operator.
  final AppConfig config;

  /// Which native capabilities this build actually offers.
  final PlatformCapabilities capabilities;

  /// Short one-line summary describing the running node.
  String get summary =>
      '${config.appName} ${config.version} '
      '(${config.flavor.rawName}/${config.environment.rawName})';
}
