/// The single-byte wire flags of a packet header.
///
/// Each flag owns a bit in the flags byte (offset 6 of the fixed header).
/// Unknown bits are preserved in the header's [PacketHeader.reservedFlags]
/// so a reader can forward a frame it does not fully understand instead of
/// dropping it (the "forward-compatible unknown" behaviour).
enum PacketFlag {
  /// Payload is ciphertext: parsed for framing only, never interpreted.
  encrypted(0x01),

  /// Payload is compressed.
  compressed(0x02),

  /// Fragment fields of this header carry meaning.
  fragmented(0x04),

  /// Sender wants a `PacketType.acknowledgement`.
  ackRequested(0x08),

  /// Relays may forward this frame beyond a known route.
  relayAllowed(0x10),

  /// Broadcast marker, paired with [PacketType.broadcast].
  broadcastFlag(0x20),

  /// Retransmission of an earlier packet.
  retry(0x40),

  /// A relay observed a repeat of `(source, sequence)`.
  duplicateFlag(0x80);

  const PacketFlag(this.bit);

  /// The bit value in the flags byte.
  final int bit;

  /// Encodes [flags] into a single byte.
  static int toByte(Set<PacketFlag> flags) {
    var value = 0;
    for (final flag in flags) {
      value |= flag.bit;
    }
    return value;
  }

  /// Decodes [byte] into the set of known flags.
  static Set<PacketFlag> fromByte(int byte) {
    final result = <PacketFlag>{};
    for (final flag in values) {
      if ((byte & flag.bit) != 0) result.add(flag);
    }
    return result;
  }
}
