import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/features/settings/application/app_update_installer.dart';
import 'package:onebit/features/settings/application/app_update_providers.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/presentation/screens/app_update_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The channel `MainActivity` publishes the staged APK over.
const MethodChannel updateChannel = MethodChannel('dev.onebit.onebit/update');

/// A release that carries an APK, which is what the `releases` endpoint
/// returns for a tag published with an asset attached.
const AppUpdateInfo withApk = AppUpdateInfo(
  version: 'v9.9.9',
  releaseUrl: 'https://example.test/releases/v9.9.9',
  apkUrl: 'https://example.test/OneBit-v9.9.9-release.apk',
);

/// A release published as a bare tag, with nothing attached.
const AppUpdateInfo withoutApk = AppUpdateInfo(
  version: 'v9.9.9',
  releaseUrl: 'https://example.test/releases/v9.9.9',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory staging;

  setUp(() {
    AppVersion.resetForTesting();
    staging = Directory.systemTemp.createTempSync('onebit-update-test');
  });

  tearDown(() {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, null);
  });

  /// A [ApkFetcher] that writes [contents] and reports one progress step.
  ApkFetcher writing(String contents, {void Function(String url)? seen}) {
    return (url, destination, {onProgress}) async {
      seen?.call(url);
      destination.writeAsStringSync(contents);
      onProgress?.call(contents.length, contents.length);
    };
  }

  AppUpdateInstaller installerWith(ApkFetcher fetcher) {
    return AppUpdateInstaller(
      fetcher: fetcher,
      stagingRoot: () async => staging,
    );
  }

  group('AppUpdateInstaller.download', () {
    test('stages the fetched bytes under a name carrying the version',
        () async {
      String? requested;
      final installer = installerWith(
        writing('apk-bytes', seen: (url) => requested = url),
      );

      final file = await installer.download(withApk);

      expect(requested, withApk.apkUrl);
      expect(file, isNotNull);
      expect(file!.path, endsWith('OneBit-v9.9.9.apk'));
      expect(file.readAsStringSync(), 'apk-bytes');
      // The temporary name must not survive the rename, or a later run
      // could hand a half-written file to the installer.
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('reports progress as the bytes arrive', () async {
      final steps = <String>[];
      final installer = installerWith(writing('apk-bytes'));

      final file = await installer.download(
        withApk,
        onProgress: (received, total) => steps.add('$received/$total'),
      );

      expect(file, isNotNull);
      expect(steps, ['9/9']);
    });

    test('skips the download when the release has no APK', () async {
      var called = false;
      final installer = installerWith(
        (url, destination, {onProgress}) async => called = true,
      );

      final file = await installer.download(withoutApk);

      expect(file, isNull);
      expect(called, isFalse);
    });

    test('discards a partial file when the fetch fails', () async {
      final installer = installerWith(
        (url, destination, {onProgress}) async {
          destination.writeAsStringSync('half a file');
          throw const AppUpdateInstallException('the wire went away');
        },
      );

      await expectLater(
        installer.download(withApk),
        throwsA(isA<AppUpdateInstallException>()),
      );

      expect(
        File('${staging.path}/updates/OneBit-v9.9.9.apk.part').existsSync(),
        isFalse,
      );
      expect(
        File('${staging.path}/updates/OneBit-v9.9.9.apk').existsSync(),
        isFalse,
      );
    });

    test('refuses a download that produced nothing', () async {
      final installer = installerWith(
        (url, destination, {onProgress}) async {},
      );

      await expectLater(
        installer.download(withApk),
        throwsA(
          isA<AppUpdateInstallException>().having(
            (e) => e.message,
            'message',
            contains('no data'),
          ),
        ),
      );

      expect(
        File('${staging.path}/updates/OneBit-v9.9.9.apk').existsSync(),
        isFalse,
      );
    });
  });

  group('AppUpdateInstaller and the Android host', () {
    test('hands the staged file to the installer', () async {
      final paths = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, (call) async {
        if (call.method == 'canInstall') return true;
        if (call.method == 'installApk') {
          paths.add((call.arguments as Map)['path'] as String);
          return null;
        }
        return null;
      });

      final installer = installerWith(writing('apk-bytes'));
      final file = await installer.download(withApk);
      await installer.install(file!);

      expect(paths, hasLength(1));
      expect(paths.single, endsWith('OneBit-v9.9.9.apk'));
      expect(File(paths.single).existsSync(), isTrue);
    });

    test('reads the install permission from the host', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, (call) async {
        if (call.method == 'canInstall') return false;
        if (call.method == 'openInstallPermission') return true;
        return null;
      });

      final installer = installerWith(writing(''));

      expect(await installer.canInstall(), isFalse);
      expect(await installer.openInstallPermission(), isTrue);
    });

    test('answers no when the host refuses', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, (call) async {
        throw PlatformException(code: 'unsupported');
      });

      expect(await installerWith(writing('')).canInstall(), isFalse);
    });
  });

  group('AppUpdateScreen install action', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    /// A `JsonGetter` reporting a release that carries an APK.
    JsonGetter releaseWithApk() => (url) async {
          if (url.contains('/releases')) {
            return [
              <String, dynamic>{
                'tag_name': 'v9.9.9',
                'html_url': 'https://example.test/releases/v9.9.9',
                'assets': [
                  <String, dynamic>{
                    'name': 'OneBit-v9.9.9-release.apk',
                    'browser_download_url': withApk.apkUrl,
                  },
                ],
              },
            ];
          }
          return <dynamic>[];
        };

    /// A `JsonGetter` reporting a release published as a bare tag.
    JsonGetter releaseWithoutApk() => (url) async {
          if (url.contains('/releases')) {
            return [
              <String, dynamic>{
                'tag_name': 'v9.9.9',
                'html_url': 'https://example.test/releases/v9.9.9',
                'assets': <dynamic>[],
              },
            ];
          }
          return <dynamic>[];
        };

    Widget wrap(AppUpdateInstaller installer, JsonGetter getJson) {
      return ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          appUpdateServiceProvider.overrideWithValue(
            AppUpdateService(getJson: getJson),
          ),
          appUpdateInstallerProvider.overrideWithValue(installer),
        ],
        child: const MaterialApp(home: AppUpdateScreen()),
      );
    }

    testWidgets('offers an in-app install when the release carries an APK',
        (tester) async {
      await tester.pumpWidget(
        wrap(installerWith(writing('apk-bytes')), releaseWithApk()),
      );
      await tester.pumpAndSettle();

      expect(find.text('INSTALL UPDATE'), findsOneWidget);
      expect(find.text('UPDATE NOW'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('falls back to the browser when there is nothing to install',
        (tester) async {
      await tester.pumpWidget(
        wrap(installerWith(writing('')), releaseWithoutApk()),
      );
      await tester.pumpAndSettle();

      expect(find.text('INSTALL UPDATE'), findsNothing);
      expect(find.text('UPDATE NOW'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('downloads, then hands the file to the installer',
        (tester) async {
      final paths = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, (call) async {
        if (call.method == 'canInstall') return true;
        if (call.method == 'installApk') {
          paths.add((call.arguments as Map)['path'] as String);
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        wrap(installerWith(writing('apk-bytes')), releaseWithApk()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('INSTALL UPDATE'));
      await tester.pump();
      // The download writes to the real file system, and its completions
      // are scheduled in the fake-async zone, so nothing advances until
      // the test hands control back to genuine asynchronous code.
      for (var i = 0; i < 10 && paths.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      expect(paths, hasLength(1));
      expect(paths.single, endsWith('OneBit-v9.9.9.apk'));
      // The download finished, so the progress row must be gone rather
      // than pinned at some percentage.
      expect(find.textContaining('Downloading'), findsNothing);
      // The permission gate was satisfied, so no instruction is owed.
      expect(find.textContaining('Allow OneBit to install'), findsNothing);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });
}
