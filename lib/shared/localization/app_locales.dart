import 'dart:ui';

/// The set of locales OneBit ships.
///
/// ARB templates live in `lib/l10n/`; `flutter gen-l10n` derives the
/// actual bundles. New locales require: an `.arb` file + an entry below.
abstract final class AppLocales {
  const AppLocales._();

  /// All supported locales, first being the fallback.
  static const List<Locale> supported = [Locale('en'), Locale('hi')];

  /// Resolves the closest supported locale to [deviceLocale].
  ///
  /// Falls back to the first entry when nothing matches. Matching is
  /// language-only (no region negotiation yet).
  static Locale forDevice(Locale deviceLocale) {
    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == deviceLocale.languageCode) {
        return supportedLocale;
      }
    }
    return supported.first;
  }
}
