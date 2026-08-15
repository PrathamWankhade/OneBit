import 'package:onebit/core/database/cache/settings_cache.dart';
import 'package:onebit/core/database/dao/settings_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for settings and application metadata.
///
/// Settings values are cached until invalidated (writes invalidate the key).
final class SettingsRepository {
  SettingsRepository({
    required this._dao,
    required this._cache,
    required this._logger,
  });

  final SettingsDao _dao;
  final SettingsCache _cache;
  final AppLogger _logger;

  static const _tag = 'settings.dao';

  Future<Result<SettingRow?>> getSetting(String key) => ResultGuards.guard(
    _logger,
    '$_tag.getSetting',
    () => _dao.getSetting(key),
  );

  /// Raw setting value, cached until invalidated.
  Future<Result<String?>> getSettingValue(String key) => ResultGuards.guard(
    _logger,
    '$_tag.getSettingValue',
    () => _cache.getOrLoad(key, () => _dao.getSettingValue(key)),
  );

  Future<Result<List<SettingRow>>> getAllSettings() =>
      ResultGuards.guard(_logger, '$_tag.getAllSettings', _dao.getAllSettings);

  Stream<Result<List<SettingRow>>> watchAllSettings() =>
      ResultGuards.guardWatch(
        _logger,
        '$_tag.watchAllSettings',
        _dao.watchAllSettings(),
      );

  Future<Result<int>> setSetting(String key, String value) =>
      ResultGuards.guard(_logger, '$_tag.setSetting', () async {
        final written = await _dao.setSetting(key, value);
        _cache.put(key, value);
        return written;
      });

  Future<Result<int>> deleteSetting(String key) =>
      ResultGuards.guard(_logger, '$_tag.deleteSetting', () async {
        final written = await _dao.deleteSetting(key);
        _cache.invalidate(key);
        return written;
      });

  // ---- Application metadata ----------------------------------------------------------

  Future<Result<MetadataRow?>> getMetadata(String key) => ResultGuards.guard(
    _logger,
    '$_tag.getMetadata',
    () => _dao.getMetadata(key),
  );

  Future<Result<String?>> getMetadataValue(String key) => ResultGuards.guard(
    _logger,
    '$_tag.getMetadataValue',
    () => _dao.getMetadataValue(key),
  );

  Future<Result<int>> setMetadata(String key, String value) =>
      ResultGuards.guard(
        _logger,
        '$_tag.setMetadata',
        () => _dao.setMetadata(key, value),
      );

  Future<Result<int>> deleteMetadata(String key) => ResultGuards.guard(
    _logger,
    '$_tag.deleteMetadata',
    () => _dao.deleteMetadata(key),
  );
}
