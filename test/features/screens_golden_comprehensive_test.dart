import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/config/app_config.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/config/app_environment.dart';
import 'package:onebit/core/config/app_flavor.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/features/about/presentation/about_screen.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/developer/presentation/developer_screen.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/media/presentation/media_gallery_screen.dart';
import 'package:onebit/features/mesh/presentation/mesh_screen.dart';
import 'package:onebit/features/messaging/presentation/search_screen.dart';
import 'package:onebit/features/settings/presentation/settings_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../app/support/app_navigation_support.dart';
import '../app/support/screen_test_support.dart';
import 'bluetooth/support/fake_bluetooth_platform.dart';

const _phoneSize = Size(390, 844);

/// Wraps a standalone screen in MaterialApp + Theme for golden capture.
Widget _standaloneApp(Widget child, {required ThemeData theme}) =>
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            flavor: AppFlavor.debug,
            environment: AppEnvironment.development,
            version: '1.0.0',
            buildNumber: 1,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('Golden · SettingsScreen', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const SettingsScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/settings_screen.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const SettingsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/settings_screen.png'),
      );
    });
  });

  group('Golden · ChannelsScreen', () {
    testWidgets('dark theme, empty state', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.channels);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/channels_empty.png'),
      );
      await disposeApp(tester);
    });

    testWidgets('light theme, empty state', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
          ],
          child: MaterialApp(theme: OneBitTheme.light, home: const OneBitApp()),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.channels);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/channels_empty.png'),
      );
      await disposeApp(tester);
    });

    testWidgets('dark theme, seeded list', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await seedOutbound(container, channelId, 'Meet for coffee tomorrow');
      await seedInbound(container, channelId, sender: 'peer-1', body: 'Sure!');
      await seedUnread(container, channelId, count: 2);
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.channels);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/channels_list.png'),
      );
      await disposeApp(tester);
    });
  });

  group('Golden · NodesScreen', () {
    testWidgets('dark theme, offline state', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nodes);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/nodes_empty.png'),
      );
      await disposeApp(tester);
    });

    testWidgets('light theme, offline state', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferencesAsyncPlatform.instance = sharedPrefsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
          ],
          child: MaterialApp(theme: OneBitTheme.light, home: const OneBitApp()),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nodes);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/nodes_empty.png'),
      );
      await disposeApp(tester);
    });
  });

  group('Golden · NearbyScreen', () {
    testWidgets('dark theme, empty air', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final platform = FakeBluetoothPlatform();
      platform.enqueue('getState', Ok(readySnapshot()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
            bluetoothPlatformProvider.overrideWithValue(platform),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nearby);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/nearby_empty.png'),
      );
      await disposeApp(tester);
      platform.dispose();
    });

    testWidgets('light theme, empty air', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final platform = FakeBluetoothPlatform();
      platform.enqueue('getState', Ok(readySnapshot()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
            bluetoothPlatformProvider.overrideWithValue(platform),
          ],
          child: MaterialApp(theme: OneBitTheme.light, home: const OneBitApp()),
        ),
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.nearby);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/nearby_empty.png'),
      );
      await disposeApp(tester);
      platform.dispose();
    });
  });

  group('Golden · MeshScreen', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const MeshScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/mesh_screen.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const MeshScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/mesh_screen.png'),
      );
    });
  });

  group('Golden · MediaGalleryScreen', () {
    testWidgets('dark theme, empty', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const MediaGalleryScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/media_gallery_empty.png'),
      );
    });

    testWidgets('light theme, empty', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const MediaGalleryScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/media_gallery_empty.png'),
      );
    });
  });

  group('Golden · SearchScreen', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const SearchScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/search_screen.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const SearchScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/search_screen.png'),
      );
    });
  });

  group('Golden · AboutScreen', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const AboutScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/about_screen.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const AboutScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/about_screen.png'),
      );
    });
  });

  group('Golden · DeveloperScreen', () {
    testWidgets('dark theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const DeveloperScreen(), theme: OneBitTheme.dark),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/dark/developer_screen.png'),
      );
    });

    testWidgets('light theme', (tester) async {
      await tester.binding.setSurfaceSize(_phoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _standaloneApp(const DeveloperScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/screens/light/developer_screen.png'),
      );
    });
  });
}
