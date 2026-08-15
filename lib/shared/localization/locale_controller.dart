import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/shared/localization/app_locales.dart';

/// Owns the active application locale.
///
/// Phase 1 resolves the device locale once at startup; the settings feature
/// will surface a manual picker later through this same controller.
final NotifierProvider<LocaleController, Locale> appLocaleProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

final class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => AppLocales.forDevice(PlatformDispatcher.instance.locale);

  /// Switches the active locale to [locale].
  void setLocale(Locale locale) {
    state = AppLocales.forDevice(locale);
  }

  /// Cycles to the next supported locale (useful for tests/preview).
  void cycleLocale() {
    final index = AppLocales.supported.indexOf(state);
    state = AppLocales.supported[(index + 1) % AppLocales.supported.length];
  }
}
