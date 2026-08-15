import 'package:flutter/foundation.dart';
import 'package:onebit/core/theme/theme_preference.dart';

/// User preferences of the device.
///
/// Immutable snapshot; persistence (via the settings repository) arrives
/// with the storage phase.
@immutable
final class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.system,
    this.verboseLogging = false,
    this.localeTag,
  });

  /// Selected theme preference.
  final ThemePreference themePreference;

  /// Whether debug/trace records are emitted in the logger.
  final bool verboseLogging;

  /// ISO-639 language tag override (`en`, `hi`), `null` = follow device.
  final String? localeTag;

  AppSettings copyWith({
    ThemePreference? themePreference,
    bool? verboseLogging,
    String? localeTag,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      verboseLogging: verboseLogging ?? this.verboseLogging,
      localeTag: localeTag ?? this.localeTag,
    );
  }
}
