import 'dart:io';

import 'package:flutter/services.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';
import 'package:path_provider/path_provider.dart';

/// Fetches [url] into [destination], reporting bytes as they arrive.
typedef ApkFetcher = Future<void> Function(
  String url,
  File destination, {
  void Function(int received, int total)? onProgress,
});

/// A failure worth showing the user rather than logging.
class AppUpdateInstallException implements Exception {
  const AppUpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a release's APK and hands it to the system installer.
///
/// The download is kept on the Dart side so progress is a normal callback
/// rather than a second channel to mirror; the native side only ever sees a
/// finished file. The file is staged inside `<cacheDir>/updates/`, which is
/// the directory `file_paths.xml` exposes through the FileProvider — move
/// one and the installer stops finding the other.
class AppUpdateInstaller {
  AppUpdateInstaller({
    ApkFetcher? fetcher,
    Future<Directory> Function()? stagingRoot,
    MethodChannel? channel,
  })  : _fetch = fetcher ?? _fetchOverHttp,
        _stagingRoot = stagingRoot ?? getTemporaryDirectory,
        _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'dev.onebit.onebit/update';

  final ApkFetcher _fetch;
  final Future<Directory> Function() _stagingRoot;
  final MethodChannel _channel;

  /// Downloads a release's APK into the app's update staging directory.
  ///
  /// Returns `null` when the release carries no APK, which is the state of
  /// a tag that was published without attaching anything — the caller falls
  /// back to opening the release page for those.
  Future<File?> download(
    AppUpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = update.apkUrl;
    if (url == null) return null;

    final directory = await _stagingDirectory();
    final file = File('${directory.path}/${_fileName(update.version)}');

    // Written under a temporary name and renamed only once complete, so a
    // connection that drops mid-flight can never leave something the
    // installer would happily treat as the whole update.
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();

    try {
      await _fetch(url, partial, onProgress: onProgress);
      // Length alone is not enough: a fetcher that never created the file
      // would make `length()` throw a FileSystemException instead of the
      // message this screen is built to show.
      if (!await partial.exists() || await partial.length() == 0) {
        throw const AppUpdateInstallException(
          'The download finished with no data.',
        );
      }
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
    } on AppUpdateInstallException {
      await _deleteIfPresent(partial);
      rethrow;
    } on Exception catch (e) {
      await _deleteIfPresent(partial);
      throw AppUpdateInstallException('Download failed: $e');
    }
    return file;
  }

  /// Whether Android currently permits this app to start an install.
  ///
  /// `false` both when the user has not granted it and when there is no
  /// channel to ask — the screen treats both as "open the release page".
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: install support could not be read: $e');
      return false;
    }
  }

  /// Opens the per-app "install unknown apps" switch.
  ///
  /// Returns `false` when that screen does not exist on this device, which
  /// the caller has to surface rather than leaving the user waiting.
  Future<bool> openInstallPermission() async {
    try {
      return await _channel.invokeMethod<bool>('openInstallPermission') ??
          false;
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: install permission screen failed: $e');
      return false;
    }
  }

  /// Hands [file] to the package installer.
  ///
  /// Throws rather than swallowing: the platform's own message ("conflicts
  /// with an existing package", "not allowed") is the only useful thing to
  /// show, and it arrives as a [PlatformException].
  Future<void> install(File file) async {
    await _channel.invokeMethod<void>('installApk', {'path': file.path});
  }

  Future<Directory> _stagingDirectory() async {
    final root = await _stagingRoot();
    final updates = Directory('${root.path}/updates');
    if (!await updates.exists()) {
      await updates.create(recursive: true);
    }
    return updates;
  }

  static String _fileName(String version) {
    // Tags look like `v1.1.0+2`; `+` is legal in a file name but invites
    // confusion when the path is read back out of a log.
    final safe = version.replaceAll(RegExp(r'[^\w.\-]'), '');
    return 'OneBit-$safe.apk';
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: could not clean up ${file.path}: $e');
    }
  }

  /// GETs [url] into [destination].
  static Future<void> _fetchOverHttp(
    String url,
    File destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw AppUpdateInstallException(
          'The download was refused (HTTP ${response.statusCode}).',
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : 0;
      var received = 0;
      final sink = destination.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }
}
