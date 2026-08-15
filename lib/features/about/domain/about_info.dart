import 'package:flutter/foundation.dart';

/// Version metadata shown by the About section.
@immutable
final class AboutInfo {
  const AboutInfo({
    required this.appName,
    required this.version,
    required this.applicationId,
  });

  /// Product name.
  final String appName;

  /// Semantic version string, e.g. `1.0.0 (+3)`.
  final String version;

  /// Stable application identifier.
  final String applicationId;
}
