import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';

/// Process entry point: initializes infrastructure, then mounts the app.
///
/// Responsibilities, in order:
/// 1. Bind the Flutter widgets engine.
/// 2. Create the provider container and eagerly build the logger so boot
///    diagnostics are captured from the first frame onward.
/// 3. Install global error handlers (frame errors + isolate errors) that
///    funnel into the failure-aware logger.
/// 4. Start the Bluetooth transport service (idempotent, never throws —
///    it degrades gracefully when Bluetooth is off or unsupported).
/// 5. Run the app inside an [UncontrolledProviderScope].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Eagerly initialize the logger pipeline to capture boot logs.
  // ignore: unused_local_variable
  final logger = container.read(appLoggerProvider);

  FlutterError.onError = (details) {
    container
        .read(appLoggerProvider)
        .fatal(
          'Flutter frame error',
          error: details.exception,
          stackTrace: details.stack,
        );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    container
        .read(appLoggerProvider)
        .fatal('Uncaught isolate error', error: error, stackTrace: stack);
    return true;
  };

  // Start the Bluetooth transport with the app. The service owns the radio
  // lifecycle subscription; transport-level failures surface as error
  // events and log lines, never as boot crashes.
  unawaited(container.read(bluetoothServiceProvider).start());

  runApp(
    UncontrolledProviderScope(container: container, child: const OneBitApp()),
  );
}
