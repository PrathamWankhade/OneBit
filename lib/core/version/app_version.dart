/// Single source of truth for the version of this build.
///
/// The version is duplicated in `pubspec.yaml` (`version: 1.0.0+1`) and
/// surfaced in the UI in several places. Rather than pulling in a native
/// package-info plugin, every screen reads it from here.
///
/// Keep [current] in sync with the `version:` field in `pubspec.yaml`.
class AppVersion {
  const AppVersion._();

  /// The running build's version in `name+build` form, e.g. `1.0.0+1`.
  static const String current = '1.0.0+1';

  /// The numeric build number from [current] (the part after `+`).
  static const String build = '1';

  /// [current] written the way git tags are written, e.g. `v1.0.0+1`.
  static const String tagged = 'v$current';

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
