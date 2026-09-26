import 'dart:convert';
import 'dart:io';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/core/version/app_version.dart';

/// A OneBit build published upstream that is newer than the running one.
class AppUpdateInfo {
  const AppUpdateInfo({required this.version, required this.releaseUrl});

  /// The upstream git tag, e.g. `v1.0.1`.
  final String version;

  /// Where the build can be picked up.
  ///
  /// Points straight at a GitHub Release when one exists, otherwise at the
  /// repository itself, which always resolves.
  final String releaseUrl;

  @override
  String toString() => 'AppUpdateInfo($version)';
}

/// Fetches and decodes a JSON document from [url].
typedef JsonGetter = Future<dynamic> Function(String url);

/// Checks [AppUpdateService.repoSlug] for a build newer than
/// [AppVersion.current].
///
/// Two sources are consulted and the newest match wins:
///
///  * published Releases, which can carry an APK and release notes, and
///  * plain git tags, so the check keeps working before any Release
///    has been created.
///
/// Either source failing (offline, rate limited, malformed) degrades to the
/// other, and both failing reports "no update" rather than throwing at the
/// caller.
class AppUpdateService {
  AppUpdateService({
    JsonGetter? getJson,
    this.repoSlug = defaultRepoSlug,
  }) : _getJsonOverride = getJson;

  /// The repository the app is published from.
  static const String defaultRepoSlug = 'PrathamWankhade/OneBit';

  /// The `owner/name` of the repository updates are read from.
  final String repoSlug;

  /// Allocated on first real request, so an injected [JsonGetter] never
  /// pays for a client it does not use.
  HttpClient? _client;
  final JsonGetter? _getJsonOverride;

  String get _repoUrl => 'https://github.com/$repoSlug';
  /// Returns every upstream build newer than this one, sorted newest first.
  ///
  /// `null` means neither source could be reached; an empty list means the
  /// check ran and this build is already the newest.
  Future<List<AppUpdateInfo>?> checkForUpdates() async {
    final releases = await _releases();
    final tags = await _tags();
    if (releases == null && tags == null) return null;

    return <AppUpdateInfo>[...?releases, ...?tags]
        .where((u) => AppVersion.isNewerThanCurrent(u.version))
        .toList()
      ..sort((a, b) => AppVersion.compare(b.version, a.version));
  }

  /// The newest build newer than this one, or `null` when this build is
  /// already the newest or the check could not run.
  Future<AppUpdateInfo?> checkForUpdate() async {
    final updates = await checkForUpdates();
    if (updates == null || updates.isEmpty) return null;
    return updates.first;
  }

  Future<List<AppUpdateInfo>?> _releases() async {
    final data = await _fetch(
      'https://api.github.com/repos/$repoSlug/releases?per_page=20',
    );
    if (data is! List) return null;

    final updates = <AppUpdateInfo>[];
    for (final item in data.whereType<Map>()) {
      final tag = item['tag_name'];
      if (tag is! String || tag.isEmpty) continue;
      final url = item['html_url'];
      updates.add(
        AppUpdateInfo(
          version: tag,
          releaseUrl: url is String && url.isNotEmpty ? url : _repoUrl,
        ),
      );
    }
    return updates;
  }

  Future<List<AppUpdateInfo>?> _tags() async {
    final data = await _fetch(
      'https://api.github.com/repos/$repoSlug/tags?per_page=30',
    );
    if (data is! List) return null;

    final updates = <AppUpdateInfo>[];
    for (final item in data.whereType<Map>()) {
      final tag = item['name'];
      if (tag is! String || tag.isEmpty) continue;
      updates.add(AppUpdateInfo(version: tag, releaseUrl: _repoUrl));
    }
    return updates;
  }

  /// Reads [url], honouring an injected getter when one was provided.
  ///
  /// A throwing getter is treated the same as an unreachable source so the
  /// check degrades to "could not verify" instead of crashing the screen.
  Future<dynamic> _fetch(String url) async {
    final override = _getJsonOverride;
    if (override == null) return _getJson(url);
    try {
      return await override(url);
    } catch (e) {
      AppLogger.warning('AppUpdate: update source failed for $url: $e');
      return null;
    }
  }

  /// GETs [url] over the wire and decodes the JSON body.
  ///
  /// Returns `null` for any non-200 status or undecodable body so callers
  /// can treat "no data" as "nothing to report".
  Future<dynamic> _getJson(String url) async {
    final client = _client ??= HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'OneBit/${AppVersion.current}');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        AppLogger.warning('AppUpdate: $url returned ${response.statusCode}');
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } on FormatException catch (e) {
      AppLogger.warning('AppUpdate: malformed response from $url: $e');
      return null;
    } on Exception catch (e) {
      AppLogger.warning('AppUpdate: request to $url failed: $e');
      return null;
    }
  }

  /// Releases the underlying HTTP client, if one was ever created.
  void dispose() {
    _client?.close(force: true);
    _client = null;
  }
}
