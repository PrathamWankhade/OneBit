import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/application/app_update_providers.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/presentation/screens/app_update_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppVersion', () {
    test('orders versions numerically', () {
      expect(AppVersion.compare('1.0.1', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(AppVersion.compare('1.0.0', '1.0.0'), 0);
      expect(AppVersion.compare('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('ignores a leading v', () {
      expect(AppVersion.compare('v1.0.1', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('V1.0.1', '1.0.0'), greaterThan(0));
      expect(AppVersion.compare('v1.0.0', '1.0.0'), 0);
    });

    test('ignores build metadata after +', () {
      expect(AppVersion.compare('1.0.0+1', '1.0.0'), 0);
      expect(AppVersion.compare('1.0.1+7', '1.0.1'), 0);
    });

    test('treats missing components as zero', () {
      expect(AppVersion.compare('1.0', '1.0.0'), 0);
      expect(AppVersion.compare('1', '1.0.0'), 0);
      expect(AppVersion.compare('1.1', '1.0.9'), greaterThan(0));
    });

    test('isNewerThanCurrent matches the running build', () {
      expect(AppVersion.isNewerThanCurrent('v${AppVersion.current}'), isFalse);
      expect(AppVersion.isNewerThanCurrent('0.9.9'), isFalse);
      expect(AppVersion.isNewerThanCurrent('1.0.1'), isTrue);
      expect(AppVersion.isNewerThanCurrent('v99.0.0'), isTrue);
    });
  });

  group('AppUpdateService', () {
    AppUpdateService serviceWith({
      List<dynamic>? releases,
      List<dynamic>? tags,
    }) {
      return AppUpdateService(
        getJson: (url) async {
          if (url.contains('/releases')) return releases;
          if (url.contains('/tags')) return tags;
          return null;
        },
      );
    }

    test('reports nothing reachable when both sources are down', () async {
      expect(await serviceWith().checkForUpdates(), isNull);
    });

    test('reports nothing reachable when a source throws', () async {
      final service = AppUpdateService(
        getJson: (url) async => throw Exception('offline'),
      );
      expect(await service.checkForUpdates(), isNull);
      expect(await service.checkForUpdate(), isNull);
    });

    test('reports up to date when upstream matches this build', () async {
      final service = serviceWith(tags: [
        {'name': 'v${AppVersion.current}'},
      ]);

      expect(await service.checkForUpdates(), isEmpty);
      expect(await service.checkForUpdate(), isNull);
    });

    test('ignores upstream versions older than this build', () async {
      final service = serviceWith(tags: [
        {'name': 'v0.9.0'},
      ]);

      expect(await service.checkForUpdates(), isEmpty);
    });

    test('reports a newer upstream tag', () async {
      final service = serviceWith(tags: [
        {'name': 'v1.0.2'},
      ]);

      final updates = await service.checkForUpdates();
      expect(updates, hasLength(1));
      expect(updates!.first.version, 'v1.0.2');
      expect((await service.checkForUpdate())!.version, 'v1.0.2');
    });

    test('picks the newest version across releases and tags', () async {
      final service = serviceWith(
        releases: [
          {
            'tag_name': 'v1.0.1',
            'html_url': 'https://example.com/onebit/v1.0.1',
          },
        ],
        tags: [
          {'name': 'v1.0.4'},
          {'name': 'v1.0.3'},
        ],
      );

      final updates = await service.checkForUpdates();
      expect(updates, hasLength(3));
      expect(updates!.first.version, 'v1.0.4');
      expect(updates.last.version, 'v1.0.1');
    });

    test('links straight to a published release when one exists', () async {
      final service = serviceWith(releases: [
        {
          'tag_name': 'v1.0.1',
          'html_url': 'https://example.com/onebit/v1.0.1',
        },
      ]);

      final update = await service.checkForUpdate();
      expect(update!.releaseUrl, 'https://example.com/onebit/v1.0.1');
    });

    test('falls back to the repository when only a tag exists', () async {
      final service = serviceWith(tags: [
        {'name': 'v1.0.1'},
      ]);

      final update = await service.checkForUpdate();
      expect(
        update!.releaseUrl,
        'https://github.com/${AppUpdateService.defaultRepoSlug}',
      );
    });
  });

  group('AppUpdateScreen', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    Widget wrap(Widget child, {JsonGetter? getJson}) {
      return ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          appUpdateServiceProvider.overrideWithValue(
            AppUpdateService(getJson: getJson),
          ),
        ],
        child: MaterialApp(home: child),
      );
    }

    JsonGetter upToDate() => (url) async {
          if (url.contains('/tags')) {
            return [
              {'name': 'v${AppVersion.current}'},
            ];
          }
          return <dynamic>[];
        };

    JsonGetter newerVersion() => (url) async {
          if (url.contains('/tags')) {
            return [
              {'name': 'v9.9.9'},
            ];
          }
          return <dynamic>[];
        };

    testWidgets('shows the current version and the auto-update toggle',
        (tester) async {
      await tester.pumpWidget(wrap(const AppUpdateScreen(), getJson: upToDate()));
      await tester.pumpAndSettle();

      expect(find.text('Auto-update'), findsOneWidget);
      expect(find.text('Current version'), findsOneWidget);
      expect(find.text('v${AppVersion.current}'), findsOneWidget);
      expect(find.text('Check for updates'), findsOneWidget);
    });

    testWidgets('reports when this build is already the newest',
        (tester) async {
      await tester.pumpWidget(wrap(const AppUpdateScreen(), getJson: upToDate()));
      await tester.pumpAndSettle();

      expect(find.text('You are running the latest version.'), findsOneWidget);
      expect(find.text('UPDATE NOW'), findsNothing);
    });

    testWidgets('reports a newer build and offers to open it', (tester) async {
      await tester.pumpWidget(
        wrap(const AppUpdateScreen(), getJson: newerVersion()),
      );
      await tester.pumpAndSettle();

      // Auto-update is on by default, so the finding is both shown inline
      // and raised as a notification.
      expect(
        find.text('OneBit v9.9.9 is available.'),
        findsWidgets,
      );
      expect(find.text('UPDATE NOW'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);

      // Let the notification expire rather than leaving its timer pending.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error when no source can be reached',
        (tester) async {
      await tester.pumpWidget(
        wrap(const AppUpdateScreen(), getJson: (url) async => null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not check for updates.'), findsOneWidget);
    });

    testWidgets('toggling auto-update persists to the repository',
        (tester) async {
      await tester.pumpWidget(wrap(const AppUpdateScreen(), getJson: upToDate()));
      await tester.pumpAndSettle();

      expect(repo.autoUpdateEnabled, isTrue);

      await tester.tap(find.text('Auto-update'));
      await tester.pumpAndSettle();

      expect(repo.autoUpdateEnabled, isFalse);

      await tester.tap(find.text('Auto-update'));
      await tester.pumpAndSettle();

      expect(repo.autoUpdateEnabled, isTrue);
    });
  });
}
