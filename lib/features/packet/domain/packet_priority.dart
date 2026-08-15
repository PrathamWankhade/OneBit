/// Delivery priority hint used for queue ordering and fragment scheduling.
///
/// Priorities never change the byte layout beyond the 2 wire bits; they only
/// move a packet earlier in a send queue and later in a drain.
enum PacketPriority {
  /// System/control, route repair, emergency.
  critical(0),

  /// Interactive messages (chat, presence).
  high(1),

  /// Routine content (text, status).
  normal(2),

  /// Background sync, analytics, media blobs.
  low(3);

  const PacketPriority(this.code);

  /// The on-wire byte value (0..3).
  final int code;

  /// Resolves [code], or `null` when no priority maps to it.
  static PacketPriority? fromCode(int code) {
    for (final priority in values) {
      if (priority.code == code) return priority;
    }
    return null;
  }
}
