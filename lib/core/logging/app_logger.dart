import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static void debug(String message) => developer.log(message, name: 'OneBit');
  static void info(String message) => developer.log(message, name: 'OneBit');
  static void warning(String message) => developer.log(message, name: 'OneBit');
  static void error(String message, [Object? error, StackTrace? stack]) =>
      developer.log(
        message,
        name: 'OneBit',
        error: error,
        stackTrace: stack,
      );
}
