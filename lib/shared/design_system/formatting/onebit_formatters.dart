/// Human-readable formatting for byte counts, throughput and durations.
///
/// Presentation-only helpers; every screen that shows transfer numbers uses
/// these so labels stay consistent and localizable-free (numbers are locale
/// neutral in this phase).
abstract final class OneBitFormatters {
  const OneBitFormatters._();

  /// Formats [bytes] as `12.4 MB` / `850 KB` / `420 B` (0 → `0 B`).
  static String bytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  /// Formats a throughput as `1.2 MB/s` (0 → `0 B/s`).
  static String speed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${bytes(bytesPerSecond.round())}/s';
  }

  /// Formats [duration] as `0:12` / `1:05:33` (null → `—`).
  static String duration(Duration? duration) {
    if (duration == null) return '—';
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
