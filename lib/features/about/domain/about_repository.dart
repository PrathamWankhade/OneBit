import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/about/domain/about_info.dart';

/// Repository contract for about/version data.
abstract interface class AboutRepository {
  /// Loads the current build's metadata.
  Future<Result<AboutInfo>> loadInfo();
}
