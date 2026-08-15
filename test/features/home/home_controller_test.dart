import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/features/home/presentation/home_controller.dart';

void main() {
  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('home controller resolves config and reports capabilities', () async {
    final container = buildContainer();

    final status = await container.read(homeControllerProvider.future);

    expect(status, isNotNull);
    expect(status.config.appName, 'OneBit');
    expect(status.config.flavor.rawName, 'debug');
    // Phase 1: the FFI core is not linked, so the native core is reported
    // as unavailable while the channel bridge is always present.
    expect(status.capabilities.nativeCoreAvailable, isFalse);
    expect(status.capabilities.channelBridgeAvailable, isTrue);
  });

  test('config provider resolves without throwing', () {
    final container = buildContainer();
    final config = container.read(appConfigProvider);
    expect(config.environment.rawName, isNotEmpty);
    expect(config.displayVersion, contains('+'));
  });
}
