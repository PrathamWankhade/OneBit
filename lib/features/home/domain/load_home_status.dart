import 'package:onebit/core/config/app_config.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/platform/native_ffi_bridge.dart';
import 'package:onebit/core/platform/platform_capabilities.dart';
import 'package:onebit/features/home/domain/home_status.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Produces the [HomeStatus] for the console screen.
///
/// This is a real domain use case: it assembles build config and platform
/// bridge state into the display model, keeping the widget layer free of
/// configuration logic.
final class LoadHomeStatus extends UseCase<NoParams, HomeStatus> {
  const LoadHomeStatus({
    required this.config,
    required this.ffiBridge,
    required this.logger,
  });

  final AppConfig config;
  final FfiBridge ffiBridge;
  final AppLogger logger;

  @override
  Future<HomeStatus> call(NoParams params) async {
    logger.debug('Loading home status', tag: LogTags.app);
    return HomeStatus(
      config: config,
      capabilities: PlatformCapabilities(
        nativeCoreAvailable: ffiBridge.isAvailable,
        channelBridgeAvailable: true,
      ),
    );
  }
}
