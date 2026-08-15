import 'package:onebit/l10n/app_localizations.dart';

/// A relative-time bucket resolved against a reference instant.
///
/// Presentation-only: the bucket is locale-independent; the localized text
/// is produced by [RelativeTimeL10nX.label].
sealed class RelativeTime {
  const RelativeTime();

  /// Buckets [time] against [now] (defaults to the wall clock).
  static RelativeTime of(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);
    if (diff.isNegative || diff.inSeconds < 60) {
      return const RelativeTimeJustNow();
    }
    if (diff.inMinutes < 60) return RelativeTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return RelativeTimeHours(diff.inHours);
    if (diff.inDays < 7) return RelativeTimeDays(diff.inDays);
    return RelativeTimeDate(time);
  }
}

/// Seen within the last minute.
final class RelativeTimeJustNow extends RelativeTime {
  const RelativeTimeJustNow();
}

/// Seen minutes ago (1–59).
final class RelativeTimeMinutes extends RelativeTime {
  const RelativeTimeMinutes(this.minutes);

  final int minutes;
}

/// Seen hours ago (1–23).
final class RelativeTimeHours extends RelativeTime {
  const RelativeTimeHours(this.hours);

  final int hours;
}

/// Seen days ago (1–6).
final class RelativeTimeDays extends RelativeTime {
  const RelativeTimeDays(this.days);

  final int days;
}

/// Older than a week; carries the raw date for a compact calendar label.
final class RelativeTimeDate extends RelativeTime {
  const RelativeTimeDate(this.date);

  final DateTime date;
}

/// Localized text of a [RelativeTime] bucket.
extension RelativeTimeL10nX on RelativeTime {
  String label(AppLocalizations l10n) => switch (this) {
    RelativeTimeJustNow() => l10n.timeJustNow,
    RelativeTimeMinutes(:final minutes) => l10n.timeMinutesAgo(minutes),
    RelativeTimeHours(:final hours) => l10n.timeHoursAgo(hours),
    RelativeTimeDays(:final days) => l10n.timeDaysAgo(days),
    RelativeTimeDate(:final date) => l10n.timeDateLabel(_dateLabel(date)),
  };

  static String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

/// Clock label ("14:32") — digits only, locale-independent.
String clockLabel(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
