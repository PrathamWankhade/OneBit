import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/platform/platform_bridge_providers.dart';
import 'package:onebit/features/home/domain/home_status.dart';
import 'package:onebit/features/home/domain/load_home_status.dart';
import 'package:onebit/shared/base/use_case.dart';

/// The use case backing the home screen.
final Provider<LoadHomeStatus> loadHomeStatusProvider =
    Provider<LoadHomeStatus>((ref) {
      return LoadHomeStatus(
        config: ref.watch(appConfigProvider),
        ffiBridge: ref.watch(ffiBridgeProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

/// Controller for the home console.
final AsyncNotifierProvider<HomeController, HomeStatus> homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeStatus>(HomeController.new);

final class HomeController extends AsyncNotifier<HomeStatus> {
  @override
  Future<HomeStatus> build() async {
    return ref.watch(loadHomeStatusProvider).call(NoParams.instance);
  }
}
