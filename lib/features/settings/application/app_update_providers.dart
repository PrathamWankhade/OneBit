import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/settings/application/app_update_service.dart';

/// The shared [AppUpdateService].
///
/// The underlying `HttpClient` is released when this provider is disposed.
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.dispose);
  return service;
});
