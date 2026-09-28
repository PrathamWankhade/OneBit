import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onebit/core/logging/app_logger.dart';

/// Single source of truth for the version of this build.
///
/// [load] reads the version back through the update channel, which asks the
/// package manager for the name and code Gradle stamped in — and Gradle
/// takes both from `version:` in `pubspec.yaml`. That leaves one place the
/// number originates, so the About screen, the release tag and the update
/// comparison cannot drift apart the way a duplicated Dart constant
/// eventually does — a mismatch there is what puts the app into an endless
/// "update available" loop.
///
/// Until it resolves, [current] reads [fallback], copied from that same
/// `version:` line, so nothing renders an empty string on the first frame.
class AppVersion {
  const AppVersion._();

  /// The `version:` line in `pubspec.yaml`, used until [load] succeeds and
  /// wherever the host cannot answer.
  ///
  /// Keep in sync with `pubspec.yaml`. [load] replaces it with the value
  /// the package manager reports, which is the same string.
  static const String fallback = '1.1.0+2';

  /// The host channel that knows what was stamped into this build.
  ///
  /// Shared with the installer because both belong to the same feature: one
  /// place on the native side owns "what version is this, and may I install
  /// the next one".
  static const MethodChannel _channel =
      MethodChannel('dev.onebit.onebit/update');

  static const String _getVersion = 'getVersion';

  static String _current = fallback;
  static String _build = fallback.split('+').last;
  static bool _loaded = false;

  /// Whether the platform has answered and [current] now reads the value
  /// stamped into the binary rather than [fallback].
  static bool get isLoaded => _loaded;

  /// The running build's version in `name+build` form, e.g. `1.0.0+1`.
  static String get current => _current;

  /// The numeric build number from [current] (the part after `+`).
  static String get build => _build;

  /// Reads the stamped version from the host.
  ///
  /// Idempotent, and safe to call before the first frame: the channel is
  /// bound while the activity configures the engine, which happens before
  /// any Dart runs. A failure leaves [fallback] in place rather than
  /// throwing, and stays retryable, so one flaky first attempt does not
  /// pin the app to [fallback] forever.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(_getVersion);
      final name = _text(info?['version']);
      if (name.isEmpty) return;
      final number = _text(info?['buildNumber']);
      _current = number.isEmpty ? name : '$name+$number';
      _build = number.isEmpty ? _current.split('+').last : number;
      _loaded = true;
    } catch (e) {
      AppLogger.warning('AppVersion: host version unavailable, using the '
          'pubspec fallback: $e');
    }
  }

  /// A platform value as a trimmed string, whatever type it arrived as.
  static String _text(Object? value) => (value?.toString() ?? '').trim();

  /// Puts [current] back on [fallback].
  ///
  /// Tests that mock the platform channel need this: [load] latches on
  /// success, so without it the first test to answer would leak its version
  /// into every test that ran after it.
  @visibleForTesting
  static void resetForTesting() {
    _current = fallback;
    _build = fallback.split('+').last;
    _loaded = false;
  }

  /// Compares two version strings numerically.
  ///
  /// A leading `v`/`V` and any `+build` suffix are ignored, so `v1.0.1`,
  /// `1.0.1` and `1.0.1+7` all compare as the same version. Missing
  /// components are treated as `0`.
  ///
  /// Returns a negative number when [a] is older than [b], `0` when they
  /// match, and a positive number when [a] is newer.
  static int compare(String a, String b) {
    final left = _components(a);
    final right = _components(b);
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return left[i].compareTo(right[i]);
    }
    return 0;
  }

  /// Whether [version] is a release newer than this build.
  static bool isNewerThanCurrent(String version) =>
      compare(version, current) > 0;

  /// Splits `v1.2.3+4` into `[1, 2, 3]`.
  static List<int> _components(String raw) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final release = trimmed.split('+').first;
    final segments = release.split('.');
    final components = <int>[];
    for (var i = 0; i < 3; i++) {
      final segment = i < segments.length ? segments[i] : '0';
      final digits = segment.replaceAll(RegExp(r'\D'), '');
      components.add(int.tryParse(digits) ?? 0);
    }
    return components;
  }
}
