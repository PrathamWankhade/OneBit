/// Discriminates the lifecycle of a packet frame.
///
/// The wire code (1 byte) is the authoritative value: readers map a byte to
/// this enum and reject frames whose code names nothing known (rule
/// `typeKnown`). Reserved codes stay mapable so future types do not rename
/// the enum.
enum PacketType {
  /// Application payload: what the UI produces and consumes.
  message(0),

  /// Delivery acknowledgement of an earlier [message].
  acknowledgement(1),

  /// Reserved single-hop fast path (future).
  single(2),

  /// Store-and-forward relay frame (later phase); defined for layout
  /// stability now.
  relay(3),

  /// Protocol control. Never trimmed, never deferred.
  control(4),

  /// Every node is a target (`destination` must be empty).
  broadcast(5),

  /// Route/server discovery, mirrors mesh discovery control.
  discovery(6),

  /// Error callback for an earlier packet.
  error(7);

  const PacketType(this.code);

  /// The on-wire byte value.
  final int code;

  /// Resolves [code], or `null` when no type maps to it.
  static PacketType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
