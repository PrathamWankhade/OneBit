import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/console_log_output.dart';
import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_tags.dart';

/// The root [AppLogger] used across the application.
///
/// Wired to:
/// - a console sink on development/staging builds,
/// - an in-memory [BufferLogOutput] (exposed through [appLogBufferProvider])
///   so the developer log panel can always read the recent history.
final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(appConfigProvider);

  final output = LogOutputGroup([
    if (config.flavor.isDebug)
      ConsoleLogOutput(
        minimumLevel: config.verboseLogging ? LogLevel.trace : LogLevel.debug,
      ),
    ref.watch(appLogBufferProvider),
  ]);

  final logger = AppLogger(
    filter: LevelAndTagFilter(
      minimumLevel: config.verboseLogging ? LogLevel.trace : LogLevel.info,
      allowedTags: const {
        LogTags.storage,
        LogTags.platform,
        LogTags.native,
        LogTags.mesh,
        LogTags.packet,
      },
    ),
    output: output,
  );

  logger.info(
    'Logger initialized (flavor=${config.flavor.rawName}, '
    'env=${config.environment.rawName})',
    tag: LogTags.app,
  );
  return logger;
});

/// In-memory ring buffer backing the developer log panel.
final Provider<BufferLogOutput> appLogBufferProvider =
    Provider<BufferLogOutput>((ref) => BufferLogOutput());
