import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/config/app_config.dart';

/// Resolves the single [AppConfig] for the process.
///
/// This provider is the composition root of all build-time knowledge:
/// features read flavor/environment from it instead of hardcoding checks.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.resolve(),
);
