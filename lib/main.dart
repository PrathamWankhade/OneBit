import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/core/logging/app_logger.dart';

/// Global provider container, set once at app startup.
/// Used by code outside the widget tree (e.g., router callbacks) to
/// access app-scoped providers like [databaseProvider].
late ProviderContainer gContainer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('OneBit starting');
  gContainer = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: gContainer,
      child: const OneBitApp(),
    ),
  );
}
