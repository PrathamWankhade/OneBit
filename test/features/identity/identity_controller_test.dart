import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'identity_test_support.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  ProviderContainer buildContainer(FakeKeystoreKeyBridge vault) {
    final container = ProviderContainer(
      overrides: [identityVaultProvider.overrideWithValue(vault)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts with no identity', () async {
    final container = buildContainer(FakeKeystoreKeyBridge());
    final identity = await container.read(identityControllerProvider.future);
    expect(identity, isNull);
  });

  test('create, update and delete drive controller state', () async {
    final container = buildContainer(FakeKeystoreKeyBridge());
    final notifier = container.read(identityControllerProvider.notifier);

    await notifier.create(displayName: 'Alice', avatarColor: 4);
    final created = container.read(identityControllerProvider).value;
    expect(created, isNotNull);
    expect(created!.profile.displayName, 'Alice');
    expect(
      created.nodeId.value,
      matches(RegExp(r'^NODE-[0-9A-F]{4}-[0-9A-F]{4}$')),
    );

    await notifier.updateProfile(
      const UserProfile(displayName: 'Alice Prime', avatarColor: 6),
    );
    expect(
      container.read(identityControllerProvider).value!.profile.displayName,
      'Alice Prime',
    );

    await notifier.delete();
    expect(container.read(identityControllerProvider).value, isNull);
  });

  test('creating twice surfaces the already_exists failure', () async {
    final container = buildContainer(FakeKeystoreKeyBridge());
    final notifier = container.read(identityControllerProvider.notifier);
    await notifier.create(displayName: 'Alice', avatarColor: 0);

    await expectLater(
      notifier.create(displayName: 'Bob', avatarColor: 1),
      throwsA(isA<IdentityFailure>()),
    );
    // The failed attempt must not clobber the existing identity state.
    expect(
      container.read(identityControllerProvider).value!.profile.displayName,
      'Alice',
    );
  });
}
