import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/application/app_update_providers.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/application/app_update_watcher.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/presentation/screens/settings_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The host channel `AppVersion.load` reads the stamped version from.
const MethodChannel updateChannel = MethodChannel('dev.onebit.onebit/update');

/// Answers `getVersion` with [version]/[buildNumber].
///
/// A platform message with no handler is buffered rather than rejected, so
/// it never resolves — any test that lets a launch check run has to answer
/// this one or hang forever waiting on `AppVersion.load`.
void seedVersion({String version = '1.0.0', String buildNumber = '1'}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(updateChannel, (call) async {
    if (call.method == 'getVersion') {
      return <String, dynamic>{
        'version': version,
        'buildNumber': buildNumber,
      };
    }
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repo;
  late GlobalKey<ScaffoldMessengerState> messengerKey;
  int releaseChecks = 0;
  int opened = 0;

  setUp(() async {
    AppVersion.resetForTesting();
    seedVersion();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = SettingsRepository(prefs);
    messengerKey = GlobalKey<ScaffoldMessengerState>();
    releaseChecks = 0;
    opened = 0;
  });

  tearDown(() {
    AppVersion.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, null);
  });

  /// A `JsonGetter` that reports upstream as [tags], and nothing else.
  JsonGetter upstream(List<String> tags) => (url) async {
        if (url.contains('/releases')) {
          releaseChecks++;
          return <dynamic>[];
        }
        if (url.contains('/tags')) {
          return [for (final tag in tags) <String, dynamic>{'name': tag}];
        }
        return <dynamic>[];
      };

  Widget wrap(JsonGetter getJson) {
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        appUpdateServiceProvider.overrideWithValue(
          AppUpdateService(getJson: getJson),
        ),
      ],
      child: AppUpdateWatcher(
        scaffoldMessengerKey: messengerKey,
        onOpenUpdate: () => opened++,
        child: MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
  }

  /// Runs the launch check and lets it settle, stopping short of the
  /// SnackBar's own timer so a test can still see the announcement.
  ///
  /// The check crosses several async hops — the version read, the request,
  /// then the announcement — and each can hand control back after
  /// pumpAndSettle has already seen a quiet tree, so settle a few more
  /// times rather than racing it.
  Future<void> afterLaunchCheck(WidgetTester tester) async {
    await tester.pump(AppUpdateWatcher.startupDelay);
    for (var i = 0; i < 5; i++) {
      await tester.pumpAndSettle();
      await tester.pump();
    }
  }

  /// Lets any announcement expire rather than leaving its timer pending at
  /// the end of the test.
  Future<void> expireSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  AppUpdateInfo? pendingFromContainer(WidgetTester tester) {
    final element = tester.element(find.byType(AppUpdateWatcher));
    return ProviderScope.containerOf(element).read(pendingAppUpdateProvider);
  }

  group('AppVersion', () {
    test('reads the version stamped into the binary', () async {
      seedVersion(version: '7.7.7', buildNumber: '7');

      await AppVersion.load();

      expect(AppVersion.current, '7.7.7+7');
      expect(AppVersion.build, '7');
      expect(AppVersion.isLoaded, isTrue);
    });

    test('keeps the pubspec fallback until something has been read', () {
      expect(AppVersion.isLoaded, isFalse);
      expect(AppVersion.current, AppVersion.fallback);
      expect(AppVersion.isNewerThanCurrent('v9.9.9'), isTrue);
    });

    test('matches the version line in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1);

      // Divergence here is what puts a released build into an endless
      // "update available" loop: the tag is cut from pubspec while the
      // comparison runs against this constant.
      expect(AppVersion.fallback, version);
    });

    test('refuses platform data that carries no version', () async {
      seedVersion(version: '', buildNumber: '');

      await AppVersion.load();

      // An empty name would make every comparison treat this build as
      // older than anything, which is the endless-update-loop failure.
      expect(AppVersion.isLoaded, isFalse);
      expect(AppVersion.current, AppVersion.fallback);
    });
  });

  group('AppUpdateWatcher', () {
    testWidgets('checks once shortly after launch and announces the result',
        (tester) async {
      await tester.pumpWidget(wrap(upstream(const ['v9.9.9'])));
      await afterLaunchCheck(tester);

      expect(releaseChecks, 1);
      expect(find.text('OneBit v9.9.9 is available.'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);

      // Stored, so the settings tile can offer it again on the next run
      // without waiting for a request.
      expect(repo.pendingUpdateVersion, 'v9.9.9');
      expect(pendingFromContainer(tester), isNotNull);

      await tester.tap(find.text('UPDATE'));
      expect(opened, 1);

      await expireSnackBars(tester);
    });

    testWidgets('does not check again inside the rate-limit window',
        (tester) async {
      await tester.pumpWidget(wrap(upstream(const ['v9.9.9'])));
      await afterLaunchCheck(tester);
      expect(releaseChecks, 1);

      // A user switching back after a phone call must not pay for another
      // round trip — or another SnackBar.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(releaseChecks, 1);
      expect(find.text('OneBit v9.9.9 is available.'), findsOneWidget);

      await expireSnackBars(tester);
    });

    testWidgets('checks on resume once the window has passed', (tester) async {
      await tester.pumpWidget(wrap(upstream(const ['v9.9.9'])));
      await afterLaunchCheck(tester);
      expect(releaseChecks, 1);

      await repo.setLastUpdateCheckAt(
        DateTime.now()
            .subtract(AppUpdateWatcher.interval * 2)
            .millisecondsSinceEpoch,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(releaseChecks, 2);

      await expireSnackBars(tester);
    });

    testWidgets('never checks when auto-update is off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings_auto_update_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);

      await tester.pumpWidget(wrap(upstream(const ['v9.9.9'])));
      await afterLaunchCheck(tester);

      expect(releaseChecks, 0);
      expect(find.text('OneBit v9.9.9 is available.'), findsNothing);
    });

    testWidgets('retires a stored update once this build is current',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings_pending_update_version': 'v9.9.9',
        'settings_pending_update_url': 'https://example.test/release',
      });
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);

      await tester.pumpWidget(wrap(upstream(const ['v1.0.0'])));
      await afterLaunchCheck(tester);

      expect(repo.pendingUpdateVersion, isNull);
      expect(repo.pendingUpdateUrl, isNull);
      expect(pendingFromContainer(tester), isNull);
      expect(find.text('OneBit v9.9.9 is available.'), findsNothing);
    });

    testWidgets('leaves the badge alone when no source answers',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings_pending_update_version': 'v9.9.9',
        'settings_pending_update_url': 'https://example.test/release',
      });
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);

      await tester.pumpWidget(wrap((url) async => null));
      await afterLaunchCheck(tester);

      // An unreachable repository is not evidence that the update went
      // away, and neither is it worth consuming the rate-limit window for.
      expect(repo.pendingUpdateVersion, 'v9.9.9');
      expect(repo.lastUpdateCheckAt, 0);
    });
  });

  group('settings tile', () {
    testWidgets('offers a stored update instead of the Auto/Manual state',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings_pending_update_version': 'v9.9.9',
      });
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: SettingsMainScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The tile sits under ADVANCED, well below the fold on the default
      // 800x600 surface, and an off-screen list child is never built.
      await tester.scrollUntilVisible(
        find.text('App update'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('v9.9.9 is ready to install'), findsOneWidget);
      expect(find.text('Auto'), findsNothing);
    });
  });
}
