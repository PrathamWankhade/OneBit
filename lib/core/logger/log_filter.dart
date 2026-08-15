import 'package:onebit/core/logger/log_level.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';

/// Filters which records reach a [LogOutput].
///
/// The default [AllowAll] keeps everything the logger produces; the
/// [LevelAndTagFilter] implements the standard production profile: verbose
/// levels dropped, and only records whose tag matches a regexp (or no tag
/// restriction) pass.
abstract interface class LogFilter {
  /// True when [record] should be passed to the output.
  bool accepts(LogRecord record);
}

/// Accepts every record.
final class AllowAllLogFilter implements LogFilter {
  const AllowAllLogFilter();

  @override
  bool accepts(LogRecord record) => true;
}

/// Accepts records at or above [minimumLevel], optionally restricted to
/// [allowedTags] (an empty set means "all tags").
final class LevelAndTagFilter implements LogFilter {
  const LevelAndTagFilter({
    this.minimumLevel = LogLevel.info,
    this.allowedTags = const {},
  });

  final LogLevel minimumLevel;
  final Set<String> allowedTags;

  @override
  bool accepts(LogRecord record) {
    if (!record.level.atLeast(minimumLevel)) return false;
    if (allowedTags.isEmpty) return true;
    final tag = record.tag;
    return tag != null && allowedTags.contains(tag);
  }
}
