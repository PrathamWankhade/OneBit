import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/settings/domain/app_settings.dart';

/// Repository contract for persisted user settings.
abstract interface class AppSettingsRepository {
  /// Loads the stored settings; returns defaults when nothing is stored.
  Future<Result<AppSettings>> load();

  /// Persists [settings] atomically.
  Future<Result<void>> save(AppSettings settings);

  /// Streams settings updates (writes from other screens, restoration).
  Stream<Result<AppSettings>> watch();
}
