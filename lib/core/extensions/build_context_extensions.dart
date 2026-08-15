import 'package:flutter/material.dart';
import 'package:onebit/l10n/app_localizations.dart';

/// Typed, concise access to localized strings and framework lookups.
extension BuildContextX on BuildContext {
  /// The generated localization bundle for the active locale.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The ambient [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// The ambient [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// The ambient [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The top-most navigator bound to this context.
  NavigatorState get navigator => Navigator.of(this);

  /// Whether the ambient surface is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// MediaQuery of the nearest enclosing screen.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Safe-area insets of the nearest enclosing screen.
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;
}
